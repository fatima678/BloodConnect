// // lib/screens/blood_request_screen.dart

// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// import '../../theme.dart';
// import '../../sdk/patient/blood_request_sdk.dart';
// import '../../sdk/core/sdk_exception.dart';

// class BloodRequestScreen extends StatefulWidget {
//   static const String routeName = '/blood_request';

//   const BloodRequestScreen({super.key});

//   @override
//   State<BloodRequestScreen> createState() => _BloodRequestScreenState();
// }

// class _BloodRequestScreenState extends State<BloodRequestScreen> {
//   final _formKey = GlobalKey<FormState>();

//   static const String latestActiveBloodRequestIdKey =
//       'latest_active_blood_request_id';

//   String? selectedBloodGroup;

//   final String googleMapsApiKey = "AIzaSyCIm0pDpMsEePYylMAZBuZfj8q3cUn3eHc";

//   double? latitude;
//   double? longitude;

//   bool isGettingLocation = false;
//   bool isSubmitting = false;
//   bool isSearchingLocation = false;

//   List<Map<String, dynamic>> placeSuggestions = [];

//   final List<String> bloodGroups = [
//     'A+',
//     'B+',
//     'AB+',
//     'O+',
//     'A-',
//     'B-',
//     'AB-',
//     'O-',
//   ];

//   final patientNameController = TextEditingController();
//   final locationController = TextEditingController();
//   final hospitalController = TextEditingController();
//   final caseController = TextEditingController();

//   final Map<String, bool> bloodConstituents = {
//     "Whole Blood": false,
//     "FFP": false,
//     "PCV": false,
//     "PRP": false,
//   };

//   Future<void> searchPlaces(String input) async {
//     final String query = input.trim();

//     setState(() {
//       latitude = null;
//       longitude = null;
//     });

//     if (query.length < 3) {
//       setState(() {
//         placeSuggestions = [];
//         isSearchingLocation = false;
//       });
//       return;
//     }

//     setState(() => isSearchingLocation = true);

//     try {
//       final Uri url = Uri.parse(
//         "https://maps.googleapis.com/maps/api/place/autocomplete/json"
//         "?input=${Uri.encodeComponent(query)}"
//         "&components=country:pk"
//         "&key=$googleMapsApiKey",
//       );

//       final http.Response response = await http.get(url).timeout(
//             const Duration(seconds: 12),
//           );

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         if (data["status"] == "OK" && data["predictions"] != null) {
//           final List predictions = data["predictions"];

//           setState(() {
//             placeSuggestions = predictions.map<Map<String, dynamic>>((place) {
//               return {
//                 "description": place["description"],
//                 "place_id": place["place_id"],
//               };
//             }).toList();
//           });
//         } else {
//           setState(() => placeSuggestions = []);
//         }
//       } else {
//         setState(() => placeSuggestions = []);
//       }
//     } catch (_) {
//       if (!mounted) return;
//       setState(() => placeSuggestions = []);
//     } finally {
//       if (mounted) {
//         setState(() => isSearchingLocation = false);
//       }
//     }
//   }

//   Future<void> selectPlaceSuggestion(Map<String, dynamic> place) async {
//     final String? placeId = place["place_id"];
//     final String description = place["description"] ?? "";

//     if (placeId == null || placeId.isEmpty) {
//       return;
//     }

//     setState(() {
//       locationController.text = description;
//       placeSuggestions = [];
//       isGettingLocation = true;
//     });

//     try {
//       final Uri url = Uri.parse(
//         "https://maps.googleapis.com/maps/api/place/details/json"
//         "?place_id=$placeId"
//         "&fields=formatted_address,geometry,name"
//         "&key=$googleMapsApiKey",
//       );

//       final http.Response response = await http.get(url).timeout(
//             const Duration(seconds: 12),
//           );

//       if (!mounted) return;

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         if (data["status"] == "OK" && data["result"] != null) {
//           final result = data["result"];
//           final geometry = result["geometry"];
//           final selectedLocation = geometry?["location"];

//           if (selectedLocation != null) {
//             setState(() {
//               latitude = (selectedLocation["lat"] as num).toDouble();
//               longitude = (selectedLocation["lng"] as num).toDouble();
//               locationController.text =
//                   result["formatted_address"] ?? description;
//             });
//           }
//         }
//       }
//     } catch (e) {
//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to select location: $e")),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isGettingLocation = false);
//       }
//     }
//   }

//   Future<void> getCurrentLocation() async {
//     setState(() {
//       isGettingLocation = true;
//       placeSuggestions = [];
//     });

//     try {
//       final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

//       if (!serviceEnabled) {
//         if (!mounted) return;

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Please enable location services.")),
//         );
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();

//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }

//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         if (!mounted) return;

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Location permission is required.")),
//         );
//         return;
//       }

//       final Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       latitude = position.latitude;
//       longitude = position.longitude;

//       final String? address = await getAddressFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );

//       if (!mounted) return;

//       setState(() {
//         locationController.text = address ??
//             "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
//       });
//     } catch (e) {
//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to get location: $e")),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isGettingLocation = false);
//       }
//     }
//   }

//   Future<String?> getAddressFromCoordinates(
//     double latitude,
//     double longitude,
//   ) async {
//     try {
//       final Uri url = Uri.parse(
//         "https://maps.googleapis.com/maps/api/geocode/json"
//         "?latlng=$latitude,$longitude"
//         "&key=$googleMapsApiKey",
//       );

//       final http.Response response = await http.get(url).timeout(
//             const Duration(seconds: 15),
//           );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         if (data["status"] == "OK" &&
//             data["results"] != null &&
//             data["results"].isNotEmpty) {
//           return data["results"][0]["formatted_address"];
//         }
//       }

//       return null;
//     } catch (_) {
//       return null;
//     }
//   }

//   String? extractCityFromLocationText(String? location) {
//     if (location == null || location.trim().isEmpty) return null;

//     final parts = location.split(',');

//     if (parts.length >= 2) {
//       for (int i = 0; i < parts.length; i++) {
//         final city = parts[i].trim();

//         if (city.isEmpty) continue;

//         final lowerCity = city.toLowerCase();

//         if (lowerCity == "pakistan" || lowerCity == "punjab") {
//           continue;
//         }

//         if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(city)) {
//           continue;
//         }

//         if (i > 0) {
//           return city;
//         }
//       }
//     }

//     for (final part in parts) {
//       final city = part.trim();

//       if (city.isNotEmpty && !RegExp(r'^-?\d+(\.\d+)?$').hasMatch(city)) {
//         return city;
//       }
//     }

//     return null;
//   }

//   void clearFormFields() {
//     patientNameController.clear();
//     locationController.clear();
//     hospitalController.clear();
//     caseController.clear();

//     selectedBloodGroup = null;
//     latitude = null;
//     longitude = null;
//     placeSuggestions = [];

//     for (final key in bloodConstituents.keys) {
//       bloodConstituents[key] = false;
//     }

//     _formKey.currentState?.reset();
//   }

//   Future<void> submitBloodRequest() async {
//     if (isSubmitting) return;

//     if (!_formKey.currentState!.validate()) return;

//     if (selectedBloodGroup == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please select blood group.")),
//       );
//       return;
//     }

//     final selectedConstituents = bloodConstituents.entries
//         .where((entry) => entry.value == true)
//         .map((entry) => entry.key)
//         .toList();

//     if (selectedConstituents.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please select blood constituents.")),
//       );
//       return;
//     }

//     if (latitude == null || longitude == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             "Please select location from suggestions or use current location.",
//           ),
//         ),
//       );
//       return;
//     }

//     FocusScope.of(context).unfocus();

//     setState(() => isSubmitting = true);

//     try {
//       final String bloodRequestId = await BloodRequestSdk.createBloodRequest(
//         patientName: patientNameController.text.trim(),
//         location: locationController.text.trim(),
//         city: extractCityFromLocationText(locationController.text.trim()),
//         hospitalName: hospitalController.text.trim(),
//         bloodGroup: selectedBloodGroup!,
//         bloodConstituents: selectedConstituents,
//         caseDescription: caseController.text.trim(),
//         latitude: latitude!,
//         longitude: longitude!,
//       );

//       final SharedPreferences prefs = await SharedPreferences.getInstance();

//       await prefs.setString(
//         latestActiveBloodRequestIdKey,
//         bloodRequestId,
//       );

//       debugPrint("Blood request created through SDK ID: $bloodRequestId");

//       if (!mounted) return;

//       ScaffoldMessenger.of(context).clearSnackBars();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Request Sent Successfully!"),
//           backgroundColor: Colors.green,
//         ),
//       );

//       clearFormFields();

//       Navigator.pop(context);
//     } on SdkException catch (e) {
//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(e.message)),
//       );
//     } catch (e) {
//       if (!mounted) return;

//       debugPrint("Blood request submit unknown error: $e");

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e")),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => isSubmitting = false);
//       }
//     }
//   }

//   Widget buildLocationSuggestions() {
//     if (placeSuggestions.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return Container(
//       margin: const EdgeInsets.only(top: 6),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: ListView.separated(
//         shrinkWrap: true,
//         physics: const NeverScrollableScrollPhysics(),
//         itemCount: placeSuggestions.length,
//         separatorBuilder: (_, __) => Divider(
//           height: 1,
//           color: Colors.grey.shade200,
//         ),
//         itemBuilder: (context, index) {
//           final place = placeSuggestions[index];

//           return ListTile(
//             dense: true,
//             leading: const Icon(Icons.location_on, color: primaryMaroon),
//             title: Text(
//               place["description"] ?? "",
//               style: const TextStyle(fontSize: 13),
//             ),
//             onTap: isSubmitting ? null : () => selectPlaceSuggestion(place),
//           );
//         },
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     patientNameController.dispose();
//     locationController.dispose();
//     hospitalController.dispose();
//     caseController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bool disableForm = isSubmitting;

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: primaryMaroon,
//         iconTheme: const IconThemeData(color: whiteColor),
//         title: const Text(
//           "Request Form",
//           style: TextStyle(color: whiteColor),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: disableForm ? null : () => Navigator.pop(context),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: AbsorbPointer(
//             absorbing: disableForm,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 _buildLabel("Patient Name"),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   controller: patientNameController,
//                   decoration: _inputDecoration(hint: "Enter patient name"),
//                   validator: (value) =>
//                       value == null || value.trim().isEmpty ? "Required" : null,
//                 ),

//                 const SizedBox(height: 20),

//                 _buildLabel("Location"),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   controller: locationController,
//                   decoration: _inputDecoration(
//                     hint: "Type location or tap pin icon",
//                     suffixIcon: IconButton(
//                       icon: isGettingLocation
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                           : const Icon(Icons.location_pin, color: Colors.red),
//                       onPressed: isGettingLocation ? null : getCurrentLocation,
//                     ),
//                   ),
//                   onChanged: searchPlaces,
//                   validator: (value) {
//                     if (value == null || value.trim().isEmpty) {
//                       return "Required";
//                     }

//                     if (latitude == null || longitude == null) {
//                       return "Please select location from suggestions or use current location";
//                     }

//                     return null;
//                   },
//                 ),

//                 if (isSearchingLocation)
//                   const Padding(
//                     padding: EdgeInsets.only(top: 8),
//                     child: LinearProgressIndicator(),
//                   ),

//                 buildLocationSuggestions(),

//                 const SizedBox(height: 20),

//                 _buildLabel("Hospital Name"),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   controller: hospitalController,
//                   decoration: _inputDecoration(hint: "Enter hospital name"),
//                   validator: (value) =>
//                       value == null || value.trim().isEmpty ? "Required" : null,
//                 ),

//                 const SizedBox(height: 24),

//                 _buildLabel("Blood Group"),
//                 const SizedBox(height: 12),
//                 Wrap(
//                   spacing: 12,
//                   runSpacing: 12,
//                   children: bloodGroups.map((group) {
//                     final isSelected = selectedBloodGroup == group;

//                     return GestureDetector(
//                       onTap: () => setState(() => selectedBloodGroup = group),
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 24,
//                           vertical: 14,
//                         ),
//                         decoration: BoxDecoration(
//                           color: isSelected ? primaryMaroon : Colors.white,
//                           border: Border.all(
//                             color: isSelected
//                                 ? primaryMaroon
//                                 : Colors.grey.shade400,
//                             width: 1.5,
//                           ),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           group,
//                           style: TextStyle(
//                             color: isSelected ? Colors.white : Colors.black,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                 ),

//                 const SizedBox(height: 24),

//                 _buildLabel("Blood Constituents"),
//                 const SizedBox(height: 8),
//                 Container(
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade300),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Column(
//                     children: bloodConstituents.keys.map((key) {
//                       return CheckboxListTile(
//                         title: Text(key),
//                         value: bloodConstituents[key],
//                         activeColor: primaryMaroon,
//                         onChanged: (value) => setState(
//                           () => bloodConstituents[key] = value ?? false,
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ),

//                 const SizedBox(height: 24),

//                 _buildLabel("Case"),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   controller: caseController,
//                   decoration: _inputDecoration(hint: "eg: Accident, Pregnancy"),
//                   validator: (value) =>
//                       value == null || value.trim().isEmpty ? "Required" : null,
//                 ),

//                 const SizedBox(height: 40),

//                 SizedBox(
//                   width: double.infinity,
//                   height: 56,
//                   child: ElevatedButton(
//                     onPressed: isSubmitting ? null : submitBloodRequest,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: primaryMaroon,
//                       disabledBackgroundColor: primaryMaroon.withOpacity(0.65),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     child: isSubmitting
//                         ? const CircularProgressIndicator(color: Colors.white)
//                         : const Text(
//                             "SEND REQUEST",
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLabel(String text) {
//     return Text(
//       text,
//       style: const TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w600,
//       ),
//     );
//   }

//   InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) {
//     return InputDecoration(
//       hintText: hint,
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(10),
//       ),
//       suffixIcon: suffixIcon,
//       contentPadding: const EdgeInsets.symmetric(
//         horizontal: 16,
//         vertical: 14,
//       ),
//     );
//   }
// }