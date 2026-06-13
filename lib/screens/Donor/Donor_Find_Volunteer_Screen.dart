import 'package:flutter/material.dart';

import '../../theme.dart';
import 'package:blood_donation_app/sdk/donor/find_volunteer_sdk.dart';

class FindVolunteerScreen extends StatefulWidget {
  static const String routeName = '/find_volunteer';

  const FindVolunteerScreen({super.key});

  @override
  State<FindVolunteerScreen> createState() => _FindVolunteerScreenState();
}

class _FindVolunteerScreenState extends State<FindVolunteerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DonorFindVolunteerModel> _volunteers = [];

  @override
  void initState() {
    super.initState();
    _fetchVolunteers();
  }

  Future<void> _fetchVolunteers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final volunteers = await DonorFindVolunteerSdk.fetchVolunteers();

      if (!mounted) return;

      setState(() {
        _volunteers = volunteers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load volunteers.';
        _isLoading = false;
      });
    }
  }

  void _showCallMessage(String phone) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Calling $phone..."),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Nearest Volunteer",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchVolunteers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchVolunteers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                          ),
                          child: const Text(
                            "Retry",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _volunteers.isEmpty
                  ? const Center(
                      child: Text(
                        "No volunteers found.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _volunteers.length,
                      itemBuilder: (context, index) {
                        final volunteer = _volunteers[index];

                        final bool hasPhoto =
                            volunteer.photoUrl.trim().isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: hasPhoto
                                      ? NetworkImage(volunteer.photoUrl)
                                      : null,
                                  child: hasPhoto
                                      ? null
                                      : const Icon(
                                          Icons.person,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                ),

                                const SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        volunteer.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        volunteer.location.isEmpty
                                            ? "Location not available"
                                            : volunteer.location,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        volunteer.phone,
                                        style: const TextStyle(fontSize: 14),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        volunteer.bloodGroup.isEmpty
                                            ? "Blood Group: -"
                                            : "Blood Group: ${volunteer.bloodGroup}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                GestureDetector(
                                  onTap: () {
                                    _showCallMessage(volunteer.phone);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.phone,
                                      color: Colors.green,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}