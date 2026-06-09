// lib/screens/blood_request_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import '../../../services/auth_token_service.dart';
import 'patient_find_nearby_donors.dart';

class PatientBloodRequestScreen extends StatefulWidget {
  static const String routeName = '/blood_request';

  const PatientBloodRequestScreen({super.key});

  @override
  State<PatientBloodRequestScreen> createState() =>
      _PatientBloodRequestScreenState();
}

class _PatientBloodRequestScreenState extends State<PatientBloodRequestScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String? selectedBloodGroup;
  String? selectedCity;

  final String googleMapsApiKey = "AIzaSyCIm0pDpMsEePYylMAZBuZfj8q3cUn3eHc";

  double? latitude;
  double? longitude;

  bool isGettingLocation = false;
  bool isSubmitting = false;
  bool isSearchingLocation = false;
  bool showSuccessCard = false;

  late final AnimationController successAnimationController;
  late final Animation<double> successScaleAnimation;
  late final Animation<double> successFadeAnimation;

  List<Map<String, dynamic>> placeSuggestions = [];

  final List<String> bloodGroups = [
    'A+',
    'B+',
    'AB+',
    'O+',
    'A-',
    'B-',
    'AB-',
    'O-',
  ];

  final patientNameController = TextEditingController();
  final locationController = TextEditingController();
  final hospitalController = TextEditingController();
  final caseController = TextEditingController();

  final Map<String, bool> bloodConstituents = {
    "Whole Blood": false,
    "FFP": false,
    "PCV": false,
    "PRP": false,
  };

  @override
  void initState() {
    super.initState();

    successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    successScaleAnimation = CurvedAnimation(
      parent: successAnimationController,
      curve: Curves.elasticOut,
    );

    successFadeAnimation = CurvedAnimation(
      parent: successAnimationController,
      curve: Curves.easeIn,
    );
  }

  Future<void> searchPlaces(String input) async {
    final String query = input.trim();

    setState(() {
      latitude = null;
      longitude = null;
      selectedCity = null;
    });

    if (query.length < 3) {
      setState(() {
        placeSuggestions = [];
        isSearchingLocation = false;
      });
      return;
    }

    setState(() => isSearchingLocation = true);

    try {
      final Uri url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json"
        "?input=${Uri.encodeComponent(query)}"
        "&components=country:pk"
        "&key=$googleMapsApiKey",
      );

      final http.Response response = await http.get(url).timeout(
            const Duration(seconds: 12),
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["predictions"] != null) {
          final List predictions = data["predictions"];

          setState(() {
            placeSuggestions = predictions.map<Map<String, dynamic>>((place) {
              return {
                "description": place["description"],
                "place_id": place["place_id"],
              };
            }).toList();
          });
        } else {
          setState(() => placeSuggestions = []);
        }
      } else {
        setState(() => placeSuggestions = []);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => placeSuggestions = []);
    } finally {
      if (mounted) {
        setState(() => isSearchingLocation = false);
      }
    }
  }

  Future<void> selectPlaceSuggestion(Map<String, dynamic> place) async {
    final String? placeId = place["place_id"];
    final String description = place["description"] ?? "";

    if (placeId == null || placeId.isEmpty) {
      return;
    }

    setState(() {
      locationController.text = description;
      placeSuggestions = [];
      isGettingLocation = true;
    });

    try {
      final Uri url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/details/json"
        "?place_id=$placeId"
        "&fields=formatted_address,geometry,name,address_components"
        "&key=$googleMapsApiKey",
      );

      final http.Response response = await http.get(url).timeout(
            const Duration(seconds: 12),
          );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["result"] != null) {
          final result = data["result"];
          final geometry = result["geometry"];
          final selectedLocation = geometry?["location"];

          if (selectedLocation != null) {
            final List addressComponents = result["address_components"] ?? [];
            final String? cityFromComponents =
                extractCityFromAddressComponents(addressComponents);

            setState(() {
              latitude = (selectedLocation["lat"] as num).toDouble();
              longitude = (selectedLocation["lng"] as num).toDouble();
              locationController.text =
                  result["formatted_address"] ?? description;
              selectedCity = cityFromComponents ??
                  extractCityFromLocationText(locationController.text);
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to select location: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => isGettingLocation = false);
      }
    }
  }

  Future<void> getCurrentLocation() async {
    setState(() {
      isGettingLocation = true;
      placeSuggestions = [];
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")),
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      latitude = position.latitude;
      longitude = position.longitude;

      final String? address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        locationController.text = address ??
            "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get location: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => isGettingLocation = false);
      }
    }
  }

  String? extractCityFromAddressComponents(List components) {
    final List<String> priorityTypes = [
      "locality",
      "administrative_area_level_3",
      "administrative_area_level_2",
      "sublocality",
      "sublocality_level_1",
      "postal_town",
      "administrative_area_level_1",
    ];

    for (final priorityType in priorityTypes) {
      for (final component in components) {
        final List types = component["types"] ?? [];
        final String name = component["long_name"]?.toString().trim() ?? "";

        if (name.isEmpty) continue;

        if (types.contains(priorityType)) {
          return name;
        }
      }
    }

    return null;
  }

  String? extractCityFromLocationText(String? location) {
    if (location == null || location.trim().isEmpty) return null;

    final parts = location.split(',');

    if (parts.length >= 2) {
      for (int i = 0; i < parts.length; i++) {
        final city = parts[i].trim();

        if (city.isEmpty) continue;

        final lowerCity = city.toLowerCase();

        if (lowerCity == "pakistan" || lowerCity == "punjab") {
          continue;
        }

        if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(city)) {
          continue;
        }

        if (i > 0) {
          return city;
        }
      }
    }

    for (final part in parts) {
      final city = part.trim();

      if (city.isNotEmpty && !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(city)) {
        return city;
      }
    }

    return null;
  }

  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final Uri url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json"
        "?latlng=$latitude,$longitude"
        "&key=$googleMapsApiKey",
      );

      final http.Response response = await http.get(url).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" &&
            data["results"] != null &&
            data["results"].isNotEmpty) {
          final result = data["results"][0];
          final String? formattedAddress =
              result["formatted_address"]?.toString();

          final List addressComponents = result["address_components"] ?? [];
          final String? cityFromComponents =
              extractCityFromAddressComponents(addressComponents);

          selectedCity =
              cityFromComponents ?? extractCityFromLocationText(formattedAddress);

          return formattedAddress;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  void clearFormFields() {
    patientNameController.clear();
    locationController.clear();
    hospitalController.clear();
    caseController.clear();

    selectedBloodGroup = null;
    selectedCity = null;
    latitude = null;
    longitude = null;
    placeSuggestions = [];

    for (final key in bloodConstituents.keys) {
      bloodConstituents[key] = false;
    }

    _formKey.currentState?.reset();
  }

  Future<void> showSuccessAndRedirect(String bloodRequestId) async {
    if (!mounted) return;

    debugPrint("Blood Request ID before redirect: $bloodRequestId");

    setState(() {
      showSuccessCard = true;
    });

    successAnimationController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    setState(() {
      showSuccessCard = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FindNearbyDonorsScreen(
          bloodRequestId: bloodRequestId,
        ),
      ),
    );
  }

  Future<void> submitBloodRequest() async {
    if (isSubmitting || showSuccessCard) return;

    if (!_formKey.currentState!.validate()) return;

    if (selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select blood group.")),
      );
      return;
    }

    final selectedConstituents = bloodConstituents.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();

    if (selectedConstituents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select blood constituents.")),
      );
      return;
    }

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select location from suggestions or use current location.",
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => isSubmitting = true);

    try {
      final response = await AuthTokenService.authorizedPost(
        '/blood-requests',
        {
          "patient_name": patientNameController.text.trim(),
          "location": locationController.text.trim(),
          "city": selectedCity ??
              extractCityFromLocationText(locationController.text.trim()),
          "hospital_name": hospitalController.text.trim(),
          "blood_group": selectedBloodGroup,
          "blood_constituents": selectedConstituents,
          "case_description": caseController.text.trim(),
          "latitude": latitude,
          "longitude": longitude,
        },
      );

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 201 && responseBody["success"] == true) {
        ScaffoldMessenger.of(context).clearSnackBars();

        final dynamic responseData = responseBody["data"];
        final String? bloodRequestId = responseData is Map
            ? responseData["id"]?.toString()
            : null;

        debugPrint("Blood Request Submit Response: ${response.body}");
        debugPrint("Extracted Blood Request ID: $bloodRequestId");

        if (bloodRequestId == null || bloodRequestId.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Blood request ID not found in response."),
            ),
          );

          setState(() => isSubmitting = false);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'latest_active_blood_request_id',
          bloodRequestId,
        );

        setState(() {
          isSubmitting = false;
        });

        clearFormFields();

        await showSuccessAndRedirect(bloodRequestId);
      } else {
        final String errorMessage =
            responseBody["message"] ?? "Failed to submit blood request.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );

        setState(() => isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );

      setState(() => isSubmitting = false);
    }
  }

  Widget buildLocationSuggestions() {
    if (placeSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: placeSuggestions.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          final place = placeSuggestions[index];

          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on, color: primaryMaroon),
            title: Text(
              place["description"] ?? "",
              style: const TextStyle(fontSize: 13),
            ),
            onTap: isSubmitting || showSuccessCard
                ? null
                : () => selectPlaceSuggestion(place),
          );
        },
      ),
    );
  }

  Widget buildSuccessCard() {
    return FadeTransition(
      opacity: successFadeAnimation,
      child: ScaleTransition(
        scale: successScaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 380),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  "Blood request submitted successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    successAnimationController.dispose();
    patientNameController.dispose();
    locationController.dispose();
    hospitalController.dispose();
    caseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableForm = isSubmitting || showSuccessCard;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: whiteColor),
        title: const Text(
          "Request Form",
          style: TextStyle(color: whiteColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: disableForm ? null : () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: AbsorbPointer(
                absorbing: disableForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Patient Name"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: patientNameController,
                      decoration: _inputDecoration(hint: "Enter patient name"),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? "Required"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Location"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: locationController,
                      decoration: _inputDecoration(
                        hint: "Type location or tap pin icon",
                        suffixIcon: IconButton(
                          icon: isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                ),
                          onPressed:
                              isGettingLocation ? null : getCurrentLocation,
                        ),
                      ),
                      onChanged: searchPlaces,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Required";
                        }

                        if (latitude == null || longitude == null) {
                          return "Please select location from suggestions or use current location";
                        }

                        return null;
                      },
                    ),
                    if (isSearchingLocation)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    buildLocationSuggestions(),
                    const SizedBox(height: 20),
                    _buildLabel("Hospital Name"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: hospitalController,
                      decoration: _inputDecoration(hint: "Enter hospital name"),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? "Required"
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildLabel("Blood Group"),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: bloodGroups.map((group) {
                        final isSelected = selectedBloodGroup == group;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedBloodGroup = group),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryMaroon : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? primaryMaroon
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              group,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel("Blood Constituents"),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: bloodConstituents.keys.map((key) {
                          return CheckboxListTile(
                            title: Text(key),
                            value: bloodConstituents[key],
                            activeColor: primaryMaroon,
                            onChanged: (value) => setState(
                              () => bloodConstituents[key] = value ?? false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel("Case"),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: caseController,
                      decoration:
                          _inputDecoration(hint: "eg: Accident, Pregnancy"),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? "Required"
                          : null,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: disableForm ? null : submitBloodRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryMaroon,
                          disabledBackgroundColor:
                              primaryMaroon.withOpacity(0.65),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "SEND REQUEST",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showSuccessCard)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.18),
                alignment: Alignment.center,
                child: buildSuccessCard(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: primaryMaroon,
          width: 2.0,
        ),
      ),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}