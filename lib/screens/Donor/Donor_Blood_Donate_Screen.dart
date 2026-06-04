// lib/screens/blood_donate_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class BloodDonateScreen extends StatefulWidget {
  static const String routeName = '/blood_donate';

  const BloodDonateScreen({super.key});

  @override
  State<BloodDonateScreen> createState() => _BloodDonateScreenState();
}

class _BloodDonateScreenState extends State<BloodDonateScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianPhoneController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedCity;
  DateTime? _lastDonatedDate;
  bool _isAvailableNow = true;

  double? _latitude;
  double? _longitude;

  bool _isGettingLocation = false;
  bool _isSubmitting = false;
  bool _isSearchingLocation = false;

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

  Future<void> _selectLastDonatedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _lastDonatedDate ?? DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _lastDonatedDate = picked);
    }
  }

  String? _formatDateForApi(DateTime? date) {
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

      final http.Response response = await http
          .get(url)
          .timeout(const Duration(seconds: 12));

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

      final http.Response response = await http
          .get(url)
          .timeout(const Duration(seconds: 12));

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to select location: $e")));
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
        _locationController.text =
            locationData["address"] ??
            "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to get location: $e")));
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

      final http.Response response = await http
          .get(url)
          .timeout(const Duration(seconds: 12));

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

  Future<void> _submitDonateBloodRequest() async {
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

    setState(() => _isSubmitting = true);

    try {
      final http.Response response =
          await AuthTokenService.authorizedPost('/donor-requests', {
        "name": _nameController.text.trim(),
        "cnic": _cnicController.text.trim(),
        "phone": _phoneController.text.trim(),
        "guardian_name": _guardianNameController.text.trim(),
        "guardian_phone": _guardianPhoneController.text.trim(),
        "blood_group": _selectedBloodGroup,
        "last_donated_date": _formatDateForApi(_lastDonatedDate),
        "current_location": _locationController.text.trim(),
        "city": _selectedCity,
        "latitude": _latitude,
        "longitude": _longitude,
        "is_available_now": _isAvailableNow,
        "message": _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      });

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 201 && responseBody["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Donation request submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        _formKey.currentState!.reset();

        setState(() {
          _selectedBloodGroup = null;
          _selectedCity = null;
          _lastDonatedDate = null;
          _isAvailableNow = true;
          _latitude = null;
          _longitude = null;
          _placeSuggestions = [];
        });

        _nameController.clear();
        _cnicController.clear();
        _phoneController.clear();
        _guardianNameController.clear();
        _guardianPhoneController.clear();
        _locationController.clear();
        _messageController.clear();
      } else {
        final String errorMessage =
            responseBody["message"] ?? "Failed to submit donate blood request.";

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
            onTap: () => _selectPlaceSuggestion(place),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donate Blood"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                    value!.isEmpty ? "Name is required" : null,
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
                    value!.isEmpty ? "CNIC is required" : null,
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
                    value!.isEmpty ? "Phone number is required" : null,
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
                    value!.isEmpty ? "Guardian name is required" : null,
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
                    value!.isEmpty ? "Guardian phone is required" : null,
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
                      (group) =>
                          DropdownMenuItem(value: group, child: Text(group)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedBloodGroup = value),
                validator: (value) =>
                    value == null ? "Please select blood group" : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectLastDonatedDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Last Donated Date",
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _lastDonatedDate == null
                        ? "Select Last Donation Date"
                        : "${_lastDonatedDate!.day}/${_lastDonatedDate!.month}/${_lastDonatedDate!.year}",
                    style: TextStyle(
                      color: _lastDonatedDate == null
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: _searchPlaces,
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

              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text("Available to Donate Now"),
                subtitle: const Text("I can donate today or tomorrow"),
                value: _isAvailableNow,
                activeColor: primaryMaroon,
                onChanged: (value) => setState(() => _isAvailableNow = value),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Additional Message (Optional)",
                  hintText: "E.g., I can donate in Lahore only",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDonateBloodRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Submit",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _locationController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}