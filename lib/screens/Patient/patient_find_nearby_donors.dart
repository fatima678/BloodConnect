// lib/screens/FindNearbyDonorsScreen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

enum DonorFilterType {
  nearby,
  inCity,
  all,
}

class FindNearbyDonorsScreen extends StatefulWidget {
  static const String routeName = '/find-nearby-donors';

  const FindNearbyDonorsScreen({super.key});

  @override
  State<FindNearbyDonorsScreen> createState() => _FindNearbyDonorsScreenState();
}

class _FindNearbyDonorsScreenState extends State<FindNearbyDonorsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isHistoryLoading = false;
  bool _isSendingRequest = false;
  bool _hasLoadedOnce = false;
  bool _showSuccessCard = false;

  double? _latitude;
  double? _longitude;
  double _radius = 5.0;

  String? _patientBloodGroup;
  String? _patientCity;

  final String googleMapsApiKey = "AIzaSyCIm0pDpMsEePYylMAZBuZfj8q3cUn3eHc";

  DonorFilterType _selectedFilter = DonorFilterType.nearby;

  late final AnimationController _successAnimationController;
  late final Animation<double> _successScaleAnimation;
  late final Animation<double> _successFadeAnimation;

  List<Map<String, dynamic>> nearbyDonors = [];
  List<Map<String, dynamic>> requestHistory = [];

  List<Map<String, dynamic>> get filteredDonors {
    List<Map<String, dynamic>> donors = nearbyDonors;

    if (_patientBloodGroup != null && _patientBloodGroup!.trim().isNotEmpty) {
      donors = donors.where((donor) {
        final donorBloodGroup = _readString(
          donor,
          [
            "blood_group",
            "bloodGroup",
            "donor_blood_group",
            "donorBloodGroup",
          ],
        );

        return _normalizeBloodGroup(donorBloodGroup) ==
            _normalizeBloodGroup(_patientBloodGroup);
      }).toList();
    }

    donors = donors.where((donor) {
      final String donorRequestId = donor["id"]?.toString() ?? '';
      return _historyForDonor(donorRequestId) == null;
    }).toList();

    if (_selectedFilter == DonorFilterType.inCity) {
      donors = donors.where((donor) {
        final donorCity = _getDonorCity(donor);
        return _sameCity(donorCity, _patientCity);
      }).toList();
    }

    return donors;
  }

  @override
  void initState() {
    super.initState();

    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasLoadedOnce) return;
    _hasLoadedOnce = true;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchPatientProfile();

    await Future.wait([
      _getCurrentLocationAndFetchDonors(),
      _fetchRequestHistory(),
    ]);
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return null;
  }

  String _normalizeBloodGroup(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll(" ", "")
            .replaceAll("POSITIVE", "+")
            .replaceAll("NEGATIVE", "-") ??
        "";
  }

  String _normalizeCity(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll("city", "")
            .replaceAll("district", "")
            .replaceAll(RegExp(r'\s+'), " ")
            .trim() ??
        "";
  }

  bool _sameCity(String? first, String? second) {
    final cityOne = _normalizeCity(first);
    final cityTwo = _normalizeCity(second);

    if (cityOne.isEmpty || cityTwo.isEmpty) return false;

    return cityOne == cityTwo ||
        cityOne.contains(cityTwo) ||
        cityTwo.contains(cityOne);
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

  Future<String?> _getCityFromCoordinates(
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

          return _extractCityFromAddressComponents(addressComponents);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String? _extractCityFromLocation(String? location) {
    if (location == null || location.trim().isEmpty) return null;

    final parts = location.split(',');

    if (parts.isNotEmpty) {
      final city = parts.first.trim();

      if (city.isNotEmpty && !_looksLikeCoordinates(city)) {
        return city;
      }
    }

    return null;
  }

  bool _looksLikeCoordinates(String? value) {
    if (value == null) return false;

    final text = value.trim();

    if (text.isEmpty) return false;

    final coordinatePattern = RegExp(
      r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$',
    );

    final numberOnlyPattern = RegExp(r'^-?\d+(\.\d+)?$');

    return coordinatePattern.hasMatch(text) || numberOnlyPattern.hasMatch(text);
  }

  String? _getDonorCity(Map<String, dynamic> donor) {
    final city = _readString(
      donor,
      [
        "city",
        "donor_city",
        "donorCity",
        "current_city",
        "currentCity",
        "location_city",
        "locationCity",
        "district",
      ],
    );

    if (city != null) return city;

    final location = _readString(
      donor,
      [
        "current_location",
        "currentLocation",
        "location_name",
        "locationName",
        "address",
        "location",
      ],
    );

    return _extractCityFromLocation(location);
  }

  String _getReadableLocation(Map<String, dynamic> donor) {
    final location = _readString(
      donor,
      [
        "current_location",
        "currentLocation",
        "location_name",
        "locationName",
        "address",
        "location",
      ],
    );

    if (location != null && !_looksLikeCoordinates(location)) {
      return location;
    }

    final city = _getDonorCity(donor);

    if (city != null && city.trim().isNotEmpty) {
      return city;
    }

    return "Exact location not available";
  }

  Map<String, dynamic>? _historyForDonor(String donorRequestId) {
    if (donorRequestId.trim().isEmpty) {
      return null;
    }

    for (final item in requestHistory) {
      if (item['donor_request_id']?.toString() == donorRequestId) {
        return item;
      }
    }

    return null;
  }

  Future<void> _fetchPatientProfile() async {
    try {
      final response = await AuthTokenService.authorizedGet('/profile');

      debugPrint("Patient Profile Status: ${response.statusCode}");
      debugPrint("Patient Profile Body: ${response.body}");

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic data = responseBody["data"] ??
            responseBody["user"] ??
            responseBody["profile"] ??
            responseBody;

        if (data is Map) {
          final profile = Map<String, dynamic>.from(data);

          final bloodGroup = _readString(
            profile,
            [
              "blood_group",
              "bloodGroup",
              "patient_blood_group",
              "patientBloodGroup",
            ],
          );

          final city = _readString(
            profile,
            [
              "city",
              "current_city",
              "currentCity",
              "location_city",
              "locationCity",
            ],
          );

          final location = _readString(
            profile,
            [
              "location",
              "address",
              "current_location",
              "currentLocation",
            ],
          );

          setState(() {
            _patientBloodGroup = bloodGroup;
            _patientCity = city ?? _extractCityFromLocation(location);
          });
        }
      }
    } catch (e) {
      debugPrint("Patient profile fetch error: $e");
    }
  }

  String _selectedFilterApiValue() {
    switch (_selectedFilter) {
      case DonorFilterType.nearby:
        return "nearby";
      case DonorFilterType.inCity:
        return "in_city";
      case DonorFilterType.all:
        return "all";
    }
  }

  String _serverRadiusValue() {
    return _radius.round().toString();
  }

  Future<void> _getCurrentLocationAndFetchDonors() async {
    setState(() => _isLoading = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() => _isLoading = false);

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

        setState(() => _isLoading = false);

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

      final String? detectedCity = await _getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _patientCity = detectedCity ?? _patientCity;
      });

      await _fetchNearbyDonors();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get location: $e")),
      );
    }
  }

  Future<void> _fetchNearbyDonors() async {
    if (_latitude == null || _longitude == null) {
      await _getCurrentLocationAndFetchDonors();
      return;
    }

    if (_patientCity == null || _patientCity!.trim().isEmpty) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "City could not be detected from your current location.",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final queryParameters = <String, String>{
        'lat': _latitude.toString(),
        'lng': _longitude.toString(),
        'radius': _serverRadiusValue(),
        'filter': _selectedFilterApiValue(),
      };

      if (_patientBloodGroup != null && _patientBloodGroup!.trim().isNotEmpty) {
        queryParameters['blood_group'] = _patientBloodGroup!.trim();
      }

      if (_patientCity != null && _patientCity!.trim().isNotEmpty) {
        queryParameters['city'] = _patientCity!.trim();
      }

      final uri = Uri.parse('${AuthTokenService.baseUrl}/nearby-options')
          .replace(queryParameters: queryParameters);

      debugPrint("Nearby Donors API URL: $uri");

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      debugPrint("Nearby Donors Status: ${response.statusCode}");
      debugPrint("Nearby Donors Body: ${response.body}");

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 200 && responseBody["success"] == true) {
        final dynamic data = responseBody["data"];

        final List donors = data is List
            ? data
            : data is Map && data["donors"] is List
                ? data["donors"]
                : responseBody["donors"] is List
                    ? responseBody["donors"]
                    : [];

        setState(() {
          nearbyDonors = donors
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        });
      } else {
        final errorMessage =
            responseBody["message"] ?? "Failed to fetch nearby donors.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchRequestHistory() async {
    setState(() => _isHistoryLoading = true);

    try {
      final response = await AuthTokenService.authorizedGet(
        '/donation-request-history',
      );

      debugPrint("Request History Status: ${response.statusCode}");
      debugPrint("Request History Body: ${response.body}");

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200 && responseBody['success'] == true) {
        final List list =
            responseBody['data'] is List ? responseBody['data'] : [];

        setState(() {
          requestHistory = list
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? 'Failed to fetch request history.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("History Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isHistoryLoading = false);
      }
    }
  }

  String _formatDistance(dynamic value) {
    if (value == null) return "N/A";

    final double? distance = double.tryParse(value.toString());

    if (distance == null) return "N/A";

    return "${distance.toStringAsFixed(2)} km";
  }

  String _formatLastDonation(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return "Not provided";
    }

    return value.toString();
  }

  Color _statusColor(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus == "accepted") {
      return Colors.green;
    }

    if (lowerStatus == "pending") {
      return Colors.orange;
    }

    if (lowerStatus == "rejected" || lowerStatus == "declined") {
      return Colors.red;
    }

    return Colors.orange;
  }

  String _statusText(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus == "pending") return "Pending";
    if (lowerStatus == "accepted") return "Accepted";
    if (lowerStatus == "rejected") return "Rejected";
    if (lowerStatus == "declined") return "Declined";

    return status.trim().isEmpty ? "N/A" : status;
  }

  Future<void> _refreshData() async {
    await _fetchPatientProfile();

    await Future.wait([
      _fetchNearbyDonors(),
      _fetchRequestHistory(),
    ]);
  }

  Future<void> _changeFilter(DonorFilterType filter) async {
    if (_selectedFilter == filter) return;

    setState(() {
      _selectedFilter = filter;
    });

    await _fetchNearbyDonors();
  }

  Future<void> _showRequestSuccessCard() async {
    if (!mounted) return;

    setState(() {
      _showSuccessCard = true;
    });

    _successAnimationController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    setState(() {
      _showSuccessCard = false;
    });
  }

  Future<void> _sendRequest(Map<String, dynamic> donor) async {
    if (_isSendingRequest || _showSuccessCard) return;

    final donorRequestId = donor["id"]?.toString();

    if (donorRequestId == null || donorRequestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donor request ID missing.")),
      );
      return;
    }

    setState(() {
      _isSendingRequest = true;
    });

    try {
      final response = await AuthTokenService.authorizedPost(
        '/donation-requests',
        {
          'donor_request_id': donorRequestId,
          'message': 'Patient needs blood urgently.',
        },
      );

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 201 && responseBody['success'] == true) {
        ScaffoldMessenger.of(context).clearSnackBars();

        setState(() {
          _isSendingRequest = false;
        });

        await _fetchRequestHistory();

        if (!mounted) return;

        await _showRequestSuccessCard();

        if (!mounted) return;

        _showHistorySheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? "Failed to send request.",
            ),
          ),
        );

        setState(() {
          _isSendingRequest = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );

      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F9FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refreshSheet() async {
              await _fetchRequestHistory();

              if (context.mounted) {
                setSheetState(() {});
              }
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      width: 45,
                      height: 5,
                      margin: const EdgeInsets.only(top: 12, bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Your Request History",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: refreshSheet,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _isHistoryLoading
                          ? const Center(child: CircularProgressIndicator())
                          : requestHistory.isEmpty
                              ? const Center(
                                  child: Text(
                                    "No request history found.",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: refreshSheet,
                                  child: ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      20,
                                    ),
                                    itemCount: requestHistory.length,
                                    itemBuilder: (context, index) {
                                      return _buildHistoryCard(
                                        requestHistory[index],
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
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
                  "Request sent successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Moved to request history.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final String donorName =
        item['donor_name']?.toString().trim().isNotEmpty == true
            ? item['donor_name'].toString()
            : 'Donor';

    final String bloodGroup =
        item['donor_blood_group']?.toString().trim().isNotEmpty == true
            ? item['donor_blood_group'].toString()
            : item['blood_group']?.toString().trim().isNotEmpty == true
                ? item['blood_group'].toString()
                : 'N/A';

    final String status = item['status']?.toString() ?? 'N/A';
    final String message = item['message']?.toString() ?? 'N/A';
    final String donorPhone = item['donor_phone']?.toString() ?? '';
    final bool phoneVisible = item['phone_visible_to_patient'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryMaroon.withOpacity(0.12),
                  child: Text(
                    bloodGroup,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryMaroon,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    donorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Message: $message",
              style: const TextStyle(color: Colors.black54),
            ),
            if (phoneVisible && donorPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Donor Phone: $donorPhone",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (!phoneVisible) ...[
              const SizedBox(height: 8),
              const Text(
                "Donor phone will be visible after acceptance.",
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required String title,
    required DonorFilterType filter,
  }) {
    final bool selected = _selectedFilter == filter;

    return Expanded(
      child: GestureDetector(
        onTap: _isLoading || _isSendingRequest || _showSuccessCard
            ? null
            : () => _changeFilter(filter),
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? primaryMaroon : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? primaryMaroon : Colors.grey.shade400,
              width: 1.2,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    Color color = Colors.black54,
    FontWeight fontWeight = FontWeight.normal,
    int maxLines = 2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final String name = _readString(
          donor,
          ['name', 'user_name', 'donor_name'],
        ) ??
        "N/A";

    final String bloodGroup = _readString(
          donor,
          ['blood_group', 'bloodGroup', 'donor_blood_group'],
        ) ??
        "N/A";

    final String? hospitalName = _readString(
      donor,
      [
        'hospital_name',
        'hospitalName',
        'hospital',
        'selected_hospital_name',
        'selectedHospitalName',
      ],
    );

    final String location = _getReadableLocation(donor);

    final String distance = _formatDistance(donor["distance_km"]);

    final String lastDonation = _formatLastDonation(
      donor["last_donated_date"],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: primaryMaroon.withOpacity(0.1),
              child: Text(
                bloodGroup,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B0000),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildInfoRow(
                    icon: Icons.bloodtype,
                    text: "Blood Group: $bloodGroup",
                    color: primaryMaroon,
                    fontWeight: FontWeight.w600,
                    maxLines: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.social_distance,
                    text: "$distance away",
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    maxLines: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.calendar_month,
                    text: "Last donated: $lastDonation",
                    color: Colors.black54,
                    maxLines: 1,
                  ),
                  if (hospitalName != null)
                    _buildInfoRow(
                      icon: Icons.local_hospital,
                      text: "Hospital: $hospitalName",
                      color: primaryMaroon,
                      fontWeight: FontWeight.w600,
                      maxLines: 1,
                    ),
                  _buildInfoRow(
                    icon: Icons.location_on,
                    text: "Location: $location",
                    color: Colors.black54,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _isSendingRequest || _showSuccessCard
                          ? null
                          : () => _sendRequest(donor),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        disabledBackgroundColor:
                            primaryMaroon.withOpacity(0.65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Send Request",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _headerText() {
    if (_selectedFilter == DonorFilterType.nearby) {
      return "${filteredDonors.length} Donors Nearby";
    }

    if (_selectedFilter == DonorFilterType.inCity) {
      return "${filteredDonors.length} Donors In City";
    }

    return "${filteredDonors.length} All Donors";
  }

  String _emptyText() {
    if (_patientBloodGroup == null || _patientBloodGroup!.trim().isEmpty) {
      return "Patient blood group not found";
    }

    if (_selectedFilter == DonorFilterType.nearby) {
      return "No nearby donors found";
    }

    if (_selectedFilter == DonorFilterType.inCity) {
      return "No donors found in your city";
    }

    return "No donors found";
  }

  @override
  void dispose() {
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = requestHistory
        .where((item) => item['status']?.toString().toLowerCase() == 'pending')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Nearby Donors"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed:
                _showSuccessCard || _isSendingRequest ? null : _showHistorySheet,
            icon: const Icon(
              Icons.history,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              pendingCount > 0
                  ? "Your History ($pendingCount)"
                  : "Your History",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _buildFilterButton(
                      title: "Nearby",
                      filter: DonorFilterType.nearby,
                    ),
                    _buildFilterButton(
                      title: "In City",
                      filter: DonorFilterType.inCity,
                    ),
                    _buildFilterButton(
                      title: "All",
                      filter: DonorFilterType.all,
                    ),
                  ],
                ),
              ),

              if (_selectedFilter == DonorFilterType.nearby)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Radius",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text("${_radius.round()} km"),
                        ],
                      ),
                      Slider(
                        value: _radius,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        label: "${_radius.round()} km",
                        activeColor: primaryMaroon,
                        onChanged:
                            _isSendingRequest || _showSuccessCard
                                ? null
                                : (value) {
                                    setState(() {
                                      _radius = value;
                                    });
                                  },
                        onChangeEnd:
                            _isSendingRequest || _showSuccessCard
                                ? null
                                : (value) async {
                                    await _fetchNearbyDonors();
                                  },
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _headerText(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _isLoading || _isSendingRequest || _showSuccessCard
                          ? null
                          : _refreshData,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text("Refresh"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : filteredDonors.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_search,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _emptyText(),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredDonors.length,
                            itemBuilder: (context, index) {
                              final donor = filteredDonors[index];
                              return _buildDonorCard(donor);
                            },
                          ),
              ),
            ],
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
}