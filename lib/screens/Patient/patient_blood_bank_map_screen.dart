// lib/screens/patient_blood_bank_map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme.dart';

class PatientBloodBankMapScreen extends StatefulWidget {
  final Map<String, dynamic> selectedBank;

  const PatientBloodBankMapScreen({super.key, required this.selectedBank});

  @override
  State<PatientBloodBankMapScreen> createState() => _PatientBloodBankMapScreenState();
}

class _PatientBloodBankMapScreenState extends State<PatientBloodBankMapScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services")),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission denied permanently")),
        );
      }
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() => currentPosition = position);
    _moveCameraToBank();
  }

  void _moveCameraToBank() {
    final bank = widget.selectedBank;
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(bank['lat'], bank['lng']),
        15.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bank = widget.selectedBank;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        title: Text(bank['name'], style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(bank['lat'], bank['lng']),
          zoom: 14,
        ),
        markers: {
          Marker(
            markerId: MarkerId(bank['name']),
            position: LatLng(bank['lat'], bank['lng']),
            infoWindow: InfoWindow(
              title: bank['name'],
              snippet: bank['location'],
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
          if (currentPosition != null)
            Marker(
              markerId: const MarkerId('my_location'),
              position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
              infoWindow: const InfoWindow(title: "You are here"),
            ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        onMapCreated: (controller) {
          mapController = controller;
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryMaroon,
        onPressed: _moveCameraToBank,
        child: const Icon(Icons.location_pin),
      ),
    );
  }
}