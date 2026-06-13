// lib/screens/blood_donate_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/donor/donor_request_sdk.dart';

class BloodDonateScreen extends StatefulWidget {
  static const String routeName = '/blood_donate';

  const BloodDonateScreen({super.key});

  @override
  State<BloodDonateScreen> createState() => _BloodDonateScreenState();
}

class _BloodDonateScreenState extends State<BloodDonateScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _guardianNameController =
      TextEditingController();
  final TextEditingController _guardianPhoneController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedCity;
  DateTime? _lastDonatedDate;

  double? _latitude;
  double? _longitude;

  bool _isGettingLocation = false;
  bool _isSubmitting = false;
  bool _isSearchingLocation = false;
  bool _showSuccessCard = false;

  late final AnimationController _successAnimationController;
  late final Animation<double> _successScaleAnimation;
  late final Animation<double> _successFadeAnimation;

  List<Map<String, dynamic>> _placeSuggestions = [];

  final String googleMapsApiKey = "AIzaSyCIm0pDpMsEePYylMAZBuZfj8q3cUn3eHc";

  final List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();

    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _successScaleAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );

    _successFadeAnimation = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.easeIn,
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _minimumAllowedDonationDate() {
    return _dateOnly(DateTime.now().subtract(const Duration(days: 90)));
  }

  bool _hasDonatedWithinLastThreeMonths() {
    if (_lastDonatedDate == null) {
      return false;
    }

    final DateTime lastDonation = _dateOnly(_lastDonatedDate!);
    final DateTime minimumAllowedDate = _minimumAllowedDonationDate();

    return lastDonation.isAfter(minimumAllowedDate);
  }

  int _remainingDaysUntilEligible() {
    if (_lastDonatedDate == null) {
      return 0;
    }

    final DateTime today = _dateOnly(DateTime.now());
    final DateTime eligibleDate =
        _dateOnly(_lastDonatedDate!.add(const Duration(days: 90)));

    final int remainingDays = eligibleDate.difference(today).inDays;

    return remainingDays < 0 ? 0 : remainingDays;
  }

  String _formatDisplayDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();

    return "$day/$month/$year";
  }

  Future<void> _selectLastDonatedDate() async {
    final DateTime today = DateTime.now();
    final DateTime minimumAllowedDate = _minimumAllowedDonationDate();

    final DateTime initialDate = _lastDonatedDate != null &&
            !_dateOnly(_lastDonatedDate!).isAfter(minimumAllowedDate)
        ? _lastDonatedDate!
        : minimumAllowedDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: "Select last donation date",
      selectableDayPredicate: (DateTime date) {
        return !_dateOnly(date).isAfter(minimumAllowedDate);
      },
    );

    if (picked != null) {
      setState(() => _lastDonatedDate = picked);
    }
  }

  String? _formatDateForSdk(DateTime? date) {
    if (date == null) {
      return null;
    }

    final String year = date.year.toString();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return "$year-$month-$day";
  }

  String? _extractCityFromAddressComponents(List components) {
    String? locality;
    String? adminLevel2;
    String? adminLevel1;

    for (final component in components) {
      final List types = component["types"] ?? [];
      final String name = component["long_name"]?.toString().trim() ?? "";

      if (name.isEmpty) continue;

      if (types.contains("locality")) {
        locality = name;
      }

      if (types.contains("administrative_area_level_2")) {
        adminLevel2 = name;
      }

      if (types.contains("administrative_area_level_1")) {
        adminLevel1 = name;
      }
    }

    return locality ?? adminLevel2 ?? adminLevel1;
  }

  Future<void> _searchPlaces(String input) async {
    final String query = input.trim();

    setState(() {
      _latitude = null;
      _longitude = null;
      _selectedCity = null;
    });

    if (query.length < 3) {
      setState(() {
        _placeSuggestions = [];
        _isSearchingLocation = false;
      });
      return;
    }

    setState(() => _isSearchingLocation = true);

    try {
      final Uri url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json"
        "?input=${Uri.encodeComponent(query)}"
        "&components=country:pk"
        "&key=$googleMapsApiKey",
      );

      final http.Response response =
          await http.get(url).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["predictions"] != null) {
          final List predictions = data["predictions"];

          setState(() {
            _placeSuggestions = predictions.map<Map<String, dynamic>>((place) {
              return {
                "description": place["description"],
                "place_id": place["place_id"],
              };
            }).toList();
          });
        } else {
          setState(() => _placeSuggestions = []);
        }
      } else {
        setState(() => _placeSuggestions = []);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _placeSuggestions = []);
    } finally {
      if (mounted) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  Future<void> _selectPlaceSuggestion(Map<String, dynamic> place) async {
    final String? placeId = place["place_id"];
    final String description = place["description"] ?? "";

    if (placeId == null || placeId.isEmpty) {
      return;
    }

    setState(() {
      _locationController.text = description;
      _placeSuggestions = [];
      _isGettingLocation = true;
      _selectedCity = null;
    });

    try {
      final Uri url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/details/json"
        "?place_id=$placeId"
        "&fields=formatted_address,geometry,name,address_components"
        "&key=$googleMapsApiKey",
      );

      final http.Response response =
          await http.get(url).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["result"] != null) {
          final result = data["result"];
          final geometry = result["geometry"];
          final location = geometry?["location"];
          final List addressComponents = result["address_components"] ?? [];

          if (location != null) {
            setState(() {
              _latitude = (location["lat"] as num).toDouble();
              _longitude = (location["lng"] as num).toDouble();
              _selectedCity =
                  _extractCityFromAddressComponents(addressComponents);
              _locationController.text =
                  result["formatted_address"] ?? description;
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
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _placeSuggestions = [];
      _selectedCity = null;
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

      _latitude = position.latitude;
      _longitude = position.longitude;

      final Map<String, String?> locationData =
          await _getAddressAndCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _selectedCity = locationData["city"];
        _locationController.text = locationData["address"] ??
            "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get location: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<Map<String, String?>> _getAddressAndCityFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final Uri url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json"
        "?latlng=$latitude,$longitude"
        "&key=$googleMapsApiKey",
      );

      final http.Response response =
          await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" &&
            data["results"] != null &&
            data["results"].isNotEmpty) {
          final result = data["results"][0];
          final List addressComponents = result["address_components"] ?? [];

          return {
            "address": result["formatted_address"]?.toString(),
            "city": _extractCityFromAddressComponents(addressComponents),
          };
        }
      }

      return {
        "address": null,
        "city": null,
      };
    } catch (_) {
      return {
        "address": null,
        "city": null,
      };
    }
  }

  void _clearFormFields() {
    _formKey.currentState?.reset();

    _nameController.clear();
    _cnicController.clear();
    _phoneController.clear();
    _guardianNameController.clear();
    _guardianPhoneController.clear();
    _locationController.clear();

    setState(() {
      _selectedBloodGroup = null;
      _selectedCity = null;
      _lastDonatedDate = null;
      _latitude = null;
      _longitude = null;
      _placeSuggestions = [];
    });
  }

  Future<void> _showSuccessAndRedirect() async {
    if (!mounted) return;

    setState(() {
      _showSuccessCard = true;
    });

    _successAnimationController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    setState(() {
      _showSuccessCard = false;
    });

    Navigator.pushReplacementNamed(
      context,
      '/donor-home',
    );
  }

  Future<void> _submitDonateBloodRequest() async {
    if (_isSubmitting || _showSuccessCard) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select blood group")),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select location from suggestions or use current location",
          ),
        ),
      );
      return;
    }

    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "City could not be detected from this location. Please select a more specific location.",
          ),
        ),
      );
      return;
    }

    if (_hasDonatedWithinLastThreeMonths()) {
      final int remainingDays = _remainingDaysUntilEligible();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remainingDays > 0
                ? "You cannot donate right now. Please wait $remainingDays more days after your last donation."
                : "You can donate only after 3 months from your last donation.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    try {
      final String donorRequestId = await DonorRequestSdk.createDonorRequest(
        name: _nameController.text.trim(),
        cnic: _cnicController.text.trim(),
        phone: _phoneController.text.trim(),
        guardianName: _guardianNameController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
        bloodGroup: _selectedBloodGroup!,
        lastDonatedDate: _formatDateForSdk(_lastDonatedDate),
        currentLocation: _locationController.text.trim(),
        city: _selectedCity!,
        latitude: _latitude!,
        longitude: _longitude!,
        isAvailableNow: true,
        message: null,
      );

      debugPrint("Donor request created through SDK ID: $donorRequestId");

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      setState(() => _isSubmitting = false);

      _clearFormFields();

      await _showSuccessAndRedirect();
    } on SdkException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );

      setState(() => _isSubmitting = false);
    } catch (e) {
      if (mounted) {
        debugPrint("Donate blood request unknown error: $e");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );

        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildSuccessCard() {
    return FadeTransition(
      opacity: _successFadeAnimation,
      child: ScaleTransition(
        scale: _successScaleAnimation,
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
                  "Donation form submitted successfully.",
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

  Widget _buildLocationSuggestions() {
    if (_placeSuggestions.isEmpty) {
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
        itemCount: _placeSuggestions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final place = _placeSuggestions[index];

          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on, color: primaryMaroon),
            title: Text(
              place["description"] ?? "",
              style: const TextStyle(fontSize: 13),
            ),
            onTap: _isSubmitting || _showSuccessCard
                ? null
                : () => _selectPlaceSuggestion(place),
          );
        },
      ),
    );
  }

  Widget _buildDonationEligibilityNote() {
    if (_lastDonatedDate == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          "Note: You can donate only if your last donation was at least 3 months ago.",
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
      );
    }

    final int remainingDays = _remainingDaysUntilEligible();

    if (remainingDays > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          "You are not eligible yet. Please wait $remainingDays more days.",
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Text(
        "Eligible to donate.",
        style: TextStyle(
          color: Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool disableForm = _isSubmitting || _showSuccessCard;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Donate Blood"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: disableForm,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.bloodtype,
                        size: 100,
                        color: Color(0xFF6B0000),
                      ),
                    ),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Your Name",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "Name is required"
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cnicController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "CNIC Number",
                        hintText: "12345-1234567-1",
                        prefixIcon: Icon(Icons.credit_card),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "CNIC is required"
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Phone Number",
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "Phone number is required"
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _guardianNameController,
                      decoration: const InputDecoration(
                        labelText: "Guardian Name",
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "Guardian name is required"
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _guardianPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Guardian Phone Number",
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? "Guardian phone is required"
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedBloodGroup,
                      decoration: const InputDecoration(
                        labelText: "Blood Group",
                        prefixIcon: Icon(Icons.bloodtype),
                        border: OutlineInputBorder(),
                      ),
                      items: bloodGroups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group,
                              child: Text(group),
                            ),
                          )
                          .toList(),
                      onChanged: disableForm
                          ? null
                          : (value) =>
                              setState(() => _selectedBloodGroup = value),
                      validator: (value) =>
                          value == null ? "Please select blood group" : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: disableForm ? null : _selectLastDonatedDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Last Donated Date",
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _lastDonatedDate == null
                              ? "Select Last Donation Date"
                              : _formatDisplayDate(_lastDonatedDate!),
                          style: TextStyle(
                            color: _lastDonatedDate == null
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    _buildDonationEligibilityNote(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      readOnly: false,
                      decoration: InputDecoration(
                        labelText: "Your Current Location",
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: IconButton(
                          icon: _isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          onPressed: _isGettingLocation || disableForm
                              ? null
                              : _getCurrentLocation,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: disableForm ? null : _searchPlaces,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Location is required";
                        }

                        if (_latitude == null || _longitude == null) {
                          return "Please select location from suggestions or use current location";
                        }

                        return null;
                      },
                    ),
                    if (_isSearchingLocation)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    _buildLocationSuggestions(),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed:
                            disableForm ? null : _submitDonateBloodRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryMaroon,
                          disabledBackgroundColor:
                              primaryMaroon.withOpacity(0.65),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Submit",
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
          if (_showSuccessCard)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.18),
                alignment: Alignment.center,
                child: _buildSuccessCard(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _successAnimationController.dispose();

    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _locationController.dispose();

    super.dispose();
  }
}