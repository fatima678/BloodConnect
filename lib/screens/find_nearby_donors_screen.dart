// lib/screens/Patient/patient_find_nearby_donors.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/patient/donation_request_sdk.dart';

class FindNearbyDonorsScreen extends StatefulWidget {
  static const String routeName = '/find-nearby-donors';

  final String? bloodRequestId;

  const FindNearbyDonorsScreen({
    super.key,
    this.bloodRequestId,
  });

  @override
  State<FindNearbyDonorsScreen> createState() => _FindNearbyDonorsScreenState();
}

class _FindNearbyDonorsScreenState extends State<FindNearbyDonorsScreen>
    with SingleTickerProviderStateMixin {
  static const String _latestActiveBloodRequestIdKey =
      'latest_active_blood_request_id';

  static const String _bloodRequestsCollection = 'blood_requests';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isHistoryLoading = false;
  bool _hasLoadedOnce = false;
  bool _showSuccessCard = false;
  bool _isInitialLoading = true;
  bool _isFetchingDonors = false;
  bool _needsBloodRequestForm = false;

  final Set<String> _sendingDonorRequestIds = <String>{};

  double _radius = 100.0;

  String? _bloodRequestId;
  String? _requestBloodGroup;
  String? _selectedFilterBloodGroup;
  String? _requestCity;
  String? _requestLocation;
  String? _hospitalName;
  double? _requestLatitude;
  double? _requestLongitude;

  late final AnimationController _successAnimationController;
  late final Animation<double> _successScaleAnimation;
  late final Animation<double> _successFadeAnimation;

  StreamSubscription<List<Map<String, dynamic>>>? _donorsSubscription;

  List<Map<String, dynamic>> nearbyDonors = [];
  List<Map<String, dynamic>> requestHistory = [];

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

  List<Map<String, dynamic>> get filteredDonors {
    List<Map<String, dynamic>> users = nearbyDonors;

    if (_selectedFilterBloodGroup != null &&
        _selectedFilterBloodGroup!.trim().isNotEmpty) {
      users = users.where((user) {
        final userBloodGroup = _readString(
          user,
          [
            'blood_group',
            'blood_type',
            'bloodGroup',
            'donor_blood_group',
            'donorBloodGroup',
          ],
        );

        return _normalizeBloodGroup(userBloodGroup) ==
            _normalizeBloodGroup(_selectedFilterBloodGroup);
      }).toList();
    }

    users = users.where((user) {
      final double? distanceKm = _readDistanceKm(user);

      if (distanceKm == null) {
        return true;
      }

      return distanceKm <= _radius;
    }).toList();

    return users;
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

    _resolveBloodRequestId();
    _loadInitialData();
  }

  void _debug(String message) {
    debugPrint('[NearbyDonorsDebug] $message');
  }

  void _resolveBloodRequestId() {
    _bloodRequestId = widget.bloodRequestId;

    final Object? args = ModalRoute.of(context)?.settings.arguments;

    if (args is String && args.trim().isNotEmpty) {
      _bloodRequestId = args.trim();
      _debug('Route argument bloodRequestId=$_bloodRequestId');
      return;
    }

    if (args is Map) {
      final dynamic value = args['blood_request_id'] ??
          args['bloodRequestId'] ??
          args['request_id'] ??
          args['requestId'] ??
          args['id'];

      if (value != null && value.toString().trim().isNotEmpty) {
        _bloodRequestId = value.toString().trim();
        _debug('Route map bloodRequestId=$_bloodRequestId');
      }
    }
  }

  Future<void> _loadInitialData() async {
    _debug('loadInitialData started. initialBloodRequestId=$_bloodRequestId');

    if (mounted) {
      setState(() {
        _isInitialLoading = true;
        _isLoading = true;
        _needsBloodRequestForm = false;
      });
    }

    try {
      await _loadLatestBloodRequestIdIfNeeded();

      _debug('After latest request resolve bloodRequestId=$_bloodRequestId');

      if (_bloodRequestId == null || _bloodRequestId!.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _needsBloodRequestForm = true;
            nearbyDonors = [];
          });
        }
        _debug('No usable blood request found. Showing fill form card.');
        return;
      }

      await _saveLatestActiveBloodRequestId(_bloodRequestId!.trim());
      await _fetchRequestHistory(showLoader: false);
      await _fetchNearbyDonors(showLoader: false);
      _startDonorsLiveListener();
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLatestBloodRequestIdIfNeeded() async {
    if (_bloodRequestId != null && _bloodRequestId!.trim().isNotEmpty) {
      return;
    }

    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      _debug('No current auth user while loading latest blood request.');
      return;
    }

    try {
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docs = {};

      final userIdSnapshot = await _firestore
          .collection(_bloodRequestsCollection)
          .where('user_id', isEqualTo: currentUser.uid)
          .get();

      for (final doc in userIdSnapshot.docs) {
        docs[doc.id] = doc;
      }

      final patientUidSnapshot = await _firestore
          .collection(_bloodRequestsCollection)
          .where('patient_uid', isEqualTo: currentUser.uid)
          .get();

      for (final doc in patientUidSnapshot.docs) {
        docs[doc.id] = doc;
      }

      _debug(
        'Latest request query completed. user_id=${userIdSnapshot.docs.length}, patient_uid=${patientUidSnapshot.docs.length}, merged=${docs.length}',
      );

      final List<Map<String, dynamic>> activeRequests = [];

      for (final doc in docs.values) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['blood_request_id'] = data['blood_request_id'] ?? doc.id;
        data['request_id'] = data['request_id'] ?? doc.id;

        if (_isUsableBloodRequest(data)) {
          activeRequests.add(data);
        } else {
          _debug(
            'Skipping unusable blood request docId=${doc.id}, status=${_readString(data, [
                  'status',
                  'request_status',
                ])}, is_active=${data['is_active']}',
          );
        }
      }

      activeRequests.sort((a, b) {
        return _readDateMillis(b).compareTo(_readDateMillis(a));
      });

      if (activeRequests.isNotEmpty) {
        _bloodRequestId =
            activeRequests.first['blood_request_id']?.toString().trim();

        if (_bloodRequestId == null || _bloodRequestId!.isEmpty) {
          _bloodRequestId = activeRequests.first['id']?.toString().trim();
        }

        _debug('Latest active blood request selected=$_bloodRequestId');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_latestActiveBloodRequestIdKey);

      if (savedId != null && savedId.trim().isNotEmpty) {
        _bloodRequestId = savedId.trim();
        _debug('Fallback SharedPreferences bloodRequestId=$_bloodRequestId');
      }
    } catch (e) {
      _debug('Load latest blood request error: $e');
    }
  }

  bool _isUsableBloodRequest(Map<String, dynamic> data) {
    final String status = _readString(
          data,
          ['status', 'request_status'],
        )?.toLowerCase() ??
        '';

    if (data['is_active'] == false) {
      return false;
    }

    if (status == 'accepted' ||
        status == 'rejected' ||
        status == 'declined' ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'canceled') {
      return false;
    }

    return true;
  }

  int _readDateMillis(Map<String, dynamic> data) {
    final dynamic value = data['created_at'] ?? data['updated_at'];

    if (value == null) return 0;

    if (value is Timestamp) {
      return value.toDate().millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    final parsed = DateTime.tryParse(value.toString());

    return parsed?.millisecondsSinceEpoch ?? 0;
  }

  Future<void> _saveLatestActiveBloodRequestId(String bloodRequestId) async {
    if (bloodRequestId.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _latestActiveBloodRequestIdKey,
      bloodRequestId.trim(),
    );
  }

  Future<void> _clearLatestActiveBloodRequestId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latestActiveBloodRequestIdKey);
  }

  String _getDonorRequestId(Map<String, dynamic> donor) {
    final dynamic value = donor['donor_request_id'] ??
        donor['donor_uid'] ??
        donor['uid'] ??
        donor['user_id'] ??
        donor['request_id'] ??
        donor['requestId'] ??
        donor['id'];

    return value?.toString().trim() ?? '';
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return null;
  }

  double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value.toString().trim());

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  double? _readDistanceKm(Map<String, dynamic> donor) {
    final value = donor['route_distance_km'] ??
        donor['distance_km'] ??
        donor['distanceKm'] ??
        donor['distance'];

    if (value == null) return null;

    return double.tryParse(value.toString());
  }

  String _normalizeBloodGroup(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll(' ', '')
            .replaceAll('POSITIVE', '+')
            .replaceAll('NEGATIVE', '-') ??
        '';
  }

  String? _extractCityFromLocation(String? location) {
    if (location == null || location.trim().isEmpty) return null;

    final parts = location.split(',');

    if (parts.isNotEmpty) {
      for (final part in parts) {
        final city = part.trim();
        final lowerCity = city.toLowerCase();

        if (city.isEmpty) continue;
        if (lowerCity == 'pakistan' || lowerCity == 'punjab') continue;
        if (_looksLikeCoordinates(city)) continue;

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

  void _setBloodRequestMeta(Map<String, dynamic> bloodRequest) {
    final String? bloodGroup = _readString(
      bloodRequest,
      [
        'blood_group',
        'bloodGroup',
        'patient_blood_group',
        'patientBloodGroup',
      ],
    );

    final String? city = _readString(
      bloodRequest,
      [
        'city',
        'current_city',
        'currentCity',
        'patient_city',
        'patientCity',
      ],
    );

    final String? location = _readString(
      bloodRequest,
      [
        'location',
        'current_location',
        'currentLocation',
        'address',
        'patient_location',
        'patientLocation',
      ],
    );

    final String? hospital = _readString(
      bloodRequest,
      [
        'hospital_name',
        'hospitalName',
        'hospital',
      ],
    );

    final double? latitude = _readDouble(
      bloodRequest,
      [
        'latitude',
        'lat',
        'patient_latitude',
        'patientLatitude',
      ],
    );

    final double? longitude = _readDouble(
      bloodRequest,
      [
        'longitude',
        'lng',
        'patient_longitude',
        'patientLongitude',
      ],
    );

    _debug(
      'Request meta set -> bloodGroup=$bloodGroup, city=$city, location=$location, hospital=$hospital, lat=$latitude, lng=$longitude',
    );

    setState(() {
      _requestBloodGroup = bloodGroup ?? _requestBloodGroup;
      _requestCity = city ?? _extractCityFromLocation(location) ?? _requestCity;
      _requestLocation = location ?? _requestLocation;
      _hospitalName = hospital ?? _hospitalName;
      _requestLatitude = latitude ?? _requestLatitude;
      _requestLongitude = longitude ?? _requestLongitude;
    });
  }

  void _startDonorsLiveListener() {
    _donorsSubscription?.cancel();

    _debug(
      'Starting live users listener -> optionalBloodFilter=$_selectedFilterBloodGroup, requestLat=$_requestLatitude, requestLng=$_requestLongitude, requestCity=$_requestCity, requestLocation=$_requestLocation, radius=$_radius',
    );

    _donorsSubscription = DonationRequestSdk.watchAvailableDonors(
      bloodGroup: _selectedFilterBloodGroup,
      requestLatitude: _requestLatitude,
      requestLongitude: _requestLongitude,
      requestCity: _requestCity,
      requestLocation: _requestLocation,
      radiusKm: _radius,
    ).listen(
      (donors) {
        if (!mounted) return;

        _debug('Live listener returned users=${donors.length}');

        setState(() {
          nearbyDonors = donors;
          _needsBloodRequestForm = false;
          _isFetchingDonors = false;
          _isLoading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;

        _debug('Live listener error=$error');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donors Error: $error')),
        );
      },
    );
  }

  Future<void> _fetchNearbyDonors({
    bool showLoader = true,
  }) async {
    if (mounted) {
      setState(() {
        _isFetchingDonors = true;

        if (showLoader) {
          _isLoading = nearbyDonors.isEmpty;
        }
      });
    }

    try {
      if (_bloodRequestId == null || _bloodRequestId!.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _needsBloodRequestForm = true;
            nearbyDonors = [];
          });
        }
        _debug('fetchNearbyDonors stopped because bloodRequestId is empty.');
        return;
      }

      _debug(
        'Fetching initial nearby users for bloodRequestId=$_bloodRequestId, optionalBloodFilter=$_selectedFilterBloodGroup',
      );

      final result = await DonationRequestSdk.fetchNearbyDonors(
        bloodRequestId: _bloodRequestId!.trim(),
        bloodGroup: _selectedFilterBloodGroup,
        radiusKm: _radius,
      );

      if (!mounted) return;

      _setBloodRequestMeta(result.bloodRequest);
      await _saveLatestActiveBloodRequestId(_bloodRequestId!.trim());

      _debug('Initial nearby users returned=${result.donors.length}');

      setState(() {
        _needsBloodRequestForm = false;
        nearbyDonors = result.donors;
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      _debug('SDK error while fetching nearby users: ${e.message}');

      if (e.message.toLowerCase().contains('blood request not found') ||
          e.message.toLowerCase().contains('not pending')) {
        await _clearLatestActiveBloodRequestId();

        if (!mounted) return;

        setState(() {
          _bloodRequestId = null;
          _needsBloodRequestForm = true;
          nearbyDonors = [];
          _requestBloodGroup = null;
          _selectedFilterBloodGroup = null;
          _requestCity = null;
          _requestLocation = null;
          _hospitalName = null;
          _requestLatitude = null;
          _requestLongitude = null;
        });

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;

      _debug('Unknown error while fetching nearby users: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingDonors = false;

          if (showLoader) {
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _fetchRequestHistory({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() => _isHistoryLoading = true);
    }

    try {
      final list = await DonationRequestSdk.fetchRequestHistory(
        bloodRequestId: _bloodRequestId,
      );

      if (!mounted) return;

      _debug('Request history returned=${list.length}');

      setState(() {
        requestHistory = list;
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      _debug('SDK error while fetching history: ${e.message}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;

      _debug('Unknown history error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('History Error: $e')),
      );
    } finally {
      if (showLoader && mounted) {
        setState(() => _isHistoryLoading = false);
      }
    }
  }

  String _formatDistance(dynamic value) {
    if (value == null) return 'N/A';

    final double? distance = double.tryParse(value.toString());

    if (distance == null) return 'N/A';

    return '${distance.toStringAsFixed(2)} km';
  }

  String _formatRouteDuration(Map<String, dynamic> donor) {
    final secondsValue = donor['route_duration_seconds'];
    final minutesValue = donor['route_duration_min'];

    final int? seconds = int.tryParse(secondsValue?.toString() ?? '');

    if (seconds != null && seconds > 0) {
      final int minutes = seconds ~/ 60;
      final int remainingSeconds = seconds % 60;

      if (minutes > 0 && remainingSeconds > 0) {
        return '$minutes min $remainingSeconds sec';
      }

      if (minutes > 0) {
        return '$minutes min';
      }

      return '$seconds sec';
    }

    final int? minutes = int.tryParse(minutesValue?.toString() ?? '');

    if (minutes != null && minutes > 0) {
      return '$minutes min';
    }

    return 'N/A';
  }

  String _formatLastDonation(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return value.toString();
  }

  Color _statusColor(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus == 'accepted') return Colors.green;
    if (lowerStatus == 'pending') return Colors.orange;
    if (lowerStatus == 'rejected' || lowerStatus == 'declined') {
      return Colors.red;
    }
    if (lowerStatus == 'active' || lowerStatus.contains('available')) {
      return Colors.green;
    }

    return Colors.orange;
  }

  String _statusText(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus == 'pending') return 'Pending';
    if (lowerStatus == 'accepted') return 'Accepted';
    if (lowerStatus == 'rejected') return 'Rejected';
    if (lowerStatus == 'declined') return 'Declined';

    return status.trim().isEmpty ? 'N/A' : status;
  }

  Future<void> _showRequestSuccessCard() async {
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
  }

  Future<void> _sendRequest(Map<String, dynamic> donor) async {
    if (_showSuccessCard) return;

    if (_bloodRequestId == null || _bloodRequestId!.trim().isEmpty) {
      setState(() {
        _needsBloodRequestForm = true;
        nearbyDonors = [];
      });
      _debug('Send request stopped because bloodRequestId is empty.');
      return;
    }

    final String donorRequestId = _getDonorRequestId(donor);

    if (donorRequestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID missing.')),
      );
      return;
    }

    if (_sendingDonorRequestIds.contains(donorRequestId)) {
      return;
    }

    _debug('Sending request to userDocId=$donorRequestId');

    setState(() {
      _sendingDonorRequestIds.add(donorRequestId);
    });

    try {
      await DonationRequestSdk.sendRequestToDonor(
        bloodRequestId: _bloodRequestId!.trim(),
        donorRequestId: donorRequestId,
        message: 'Blood is needed urgently.',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();

      final Future<void> historyFuture = _fetchRequestHistory(
        showLoader: false,
      );

      await _showRequestSuccessCard();

      await historyFuture;

      if (!mounted) return;

      _showHistorySheet();
    } on SdkException catch (e) {
      if (!mounted) return;

      _debug('SDK error while sending request: ${e.message}');

      if (e.message.toLowerCase().contains('not pending')) {
        await _clearLatestActiveBloodRequestId();

        if (!mounted) return;

        setState(() {
          _bloodRequestId = null;
          _needsBloodRequestForm = true;
          nearbyDonors = [];
          _requestBloodGroup = null;
          _selectedFilterBloodGroup = null;
          _requestCity = null;
          _requestLocation = null;
          _hospitalName = null;
          _requestLatitude = null;
          _requestLongitude = null;
        });

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;

      _debug('Unknown error while sending request: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingDonorRequestIds.remove(donorRequestId);
        });
      }
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
              await _fetchRequestHistory(showLoader: false);

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
                              'Your Request History',
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
                                    'No request history found.',
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

  Future<void> _openBloodRequestForm() async {
    await Navigator.pushNamed(context, '/blood_request');

    if (!mounted) return;

    setState(() {
      _bloodRequestId = null;
      _requestBloodGroup = null;
      _selectedFilterBloodGroup = null;
      _requestCity = null;
      _requestLocation = null;
      _hospitalName = null;
      _requestLatitude = null;
      _requestLongitude = null;
      nearbyDonors = [];
      requestHistory = [];
    });

    await _loadInitialData();
  }

  Widget _buildFillFormCard() {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 390),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryMaroon.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: primaryMaroon.withOpacity(0.10),
              child: const Icon(
                Icons.assignment,
                color: primaryMaroon,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fill the form to find nearby donors',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submit a blood request first. Users will be shown according to the blood request location and selected radius.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _openBloodRequestForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Fill Blood Request Form',
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
                  'Request sent successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Moved to request history.',
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
            : 'User';

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
              'Message: $message',
              style: const TextStyle(color: Colors.black54),
            ),
            if (phoneVisible && donorPhone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Phone: $donorPhone',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (!phoneVisible) ...[
              const SizedBox(height: 8),
              const Text(
                'Phone will be visible after acceptance.',
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
    final String name = _readString(donor, ['name', 'user_name']) ?? 'N/A';

    final String bloodGroup =
        _readString(donor, ['blood_group', 'blood_type', 'bloodGroup']) ??
            'N/A';

    final String location = _readString(
          donor,
          [
            'current_location',
            'currentLocation',
            'location_name',
            'locationName',
            'address',
            'location',
          ],
        ) ??
        'N/A';

    final String distance = _formatDistance(
      donor['route_distance_km'] ?? donor['distance_km'],
    );

    final String drivingTime = _formatRouteDuration(donor);

    final String lastDonation = _formatLastDonation(
      donor['last_donated_date'],
    );

    final String status = donor['status']?.toString() ?? 'Active';

    final String donorRequestId = _getDonorRequestId(donor);
    final bool isThisDonorSending =
        _sendingDonorRequestIds.contains(donorRequestId);

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
                    icon: Icons.route,
                    text: 'Distance: $distance',
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    maxLines: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.access_time,
                    text: 'Estimated Time: $drivingTime',
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    maxLines: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.calendar_month,
                    text: 'Last donated: $lastDonation',
                    color: Colors.black54,
                    maxLines: 1,
                  ),
                  _buildInfoRow(
                    icon: Icons.location_on,
                    text: 'Location: $location',
                    color: Colors.black54,
                    maxLines: 2,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: isThisDonorSending || _showSuccessCard
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
                      child: Text(
                        isThisDonorSending ? 'Sending...' : 'Send Request',
                        style: const TextStyle(
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
    if (_selectedFilterBloodGroup != null &&
        _selectedFilterBloodGroup!.trim().isNotEmpty) {
      return '${filteredDonors.length} $_selectedFilterBloodGroup Users Nearby';
    }

    return '${filteredDonors.length} Users Nearby';
  }

  String _emptyText() {
    if (_isInitialLoading) return '';

    if (_bloodRequestId == null || _bloodRequestId!.trim().isEmpty) {
      return 'Fill the form to find nearby users';
    }

    if (_selectedFilterBloodGroup != null &&
        _selectedFilterBloodGroup!.trim().isNotEmpty) {
      return 'No nearby users found for $_selectedFilterBloodGroup';
    }

    return 'No nearby users found in selected radius';
  }

  @override
  void dispose() {
    _donorsSubscription?.cancel();
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = requestHistory
        .where((item) => item['status']?.toString().toLowerCase() == 'pending')
        .length;

    final bool shouldShowFullLoader =
        (_isInitialLoading || _isLoading) && nearbyDonors.isEmpty;

    final List<Map<String, dynamic>> displayDonors = filteredDonors;

    final bool shouldHideEmptyMessage =
        _isFetchingDonors && displayDonors.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Nearby Donors'),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showSuccessCard || _needsBloodRequestForm
                ? null
                : _showHistorySheet,
            icon: const Icon(
              Icons.history,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              pendingCount > 0
                  ? 'Your History ($pendingCount)'
                  : 'Your History',
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
          if (_needsBloodRequestForm)
            _buildFillFormCard()
          else
            Column(
              children: [
                if (_requestLocation != null || _hospitalName != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryMaroon.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryMaroon.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_hospitalName != null)
                          Text(
                            'Hospital: $_hospitalName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        if (_requestLocation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Request Location: $_requestLocation',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (_requestBloodGroup != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Request Blood Group: $_requestBloodGroup',
                            style: const TextStyle(
                              color: primaryMaroon,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilterBloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Optional Blood Type Filter',
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
                    onChanged: _showSuccessCard
                        ? null
                        : (value) {
                            setState(() {
                              _selectedFilterBloodGroup = value;
                            });

                            _fetchNearbyDonors(showLoader: false);
                            _startDonorsLiveListener();
                          },
                  ),
                ),
                if (_selectedFilterBloodGroup != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _showSuccessCard
                            ? null
                            : () {
                                setState(() {
                                  _selectedFilterBloodGroup = null;
                                });

                                _fetchNearbyDonors(showLoader: false);
                                _startDonorsLiveListener();
                              },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Clear filter'),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Radius',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text('${_radius.round()} km'),
                        ],
                      ),
                      Slider(
                        value: _radius,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        label: '${_radius.round()} km',
                        activeColor: primaryMaroon,
                        onChanged: _showSuccessCard
                            ? null
                            : (value) {
                                setState(() {
                                  _radius = value;
                                });
                              },
                        onChangeEnd: _showSuccessCard
                            ? null
                            : (value) {
                                _fetchNearbyDonors(showLoader: false);
                                _startDonorsLiveListener();
                              },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _headerText(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: shouldShowFullLoader
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : shouldHideEmptyMessage
                          ? const SizedBox.shrink()
                          : displayDonors.isEmpty
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: displayDonors.length,
                                  itemBuilder: (context, index) {
                                    final donor = displayDonors[index];
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
