import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';
import 'package:blood_donation_app/sdk/patient/patient_banner_sdk.dart';
import 'package:blood_donation_app/screens/contact_donors_screen.dart';
import 'package:blood_donation_app/screens/find_nearby_donors_screen.dart';
import 'package:blood_donation_app/screens/notifications.dart';
import 'package:blood_donation_app/screens/rate_us_screen.dart';
import 'package:blood_donation_app/screens/about_app_screen.dart';
import 'package:blood_donation_app/screens/help_feedback_screen.dart';
import 'package:blood_donation_app/screens/incoming_blood_requests_screen.dart';
import 'package:blood_donation_app/screens/setting_screen.dart';

import 'blood_request_screen.dart';
import '../screens/Blood_Bank_Screen.dart';
import '../screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _currentUserName = "Blood Connect";
  String _currentUserPhotoUrl = "";
  bool _isLoggingOut = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userProfileSubscription;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  String _profileInitial() {
    final String name = _currentUserName.trim();

    if (name.isEmpty || name == "Blood Connect") {
      return "B";
    }

    return name.characters.first.toUpperCase();
  }

  void _listenToUserData() {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _userProfileSubscription?.cancel();

    _userProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;

        final String name = _readString(data, [
          'name',
          'user_name',
          'full_name',
        ]);

        final String photoUrl = _readString(data, [
          'photo_url',
          'photoUrl',
          'profile_image',
          'profileImage',
          'image_url',
          'imageUrl',
          'avatar',
        ]);

        setState(() {
          _currentUserName = name.isNotEmpty ? name : "Blood Connect";
          _currentUserPhotoUrl = photoUrl;
        });
      }
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _userProfileSubscription?.cancel();
      await FirebaseAuth.instance.signOut();
      await AuthTokenService.clearSession();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDrawerProfileAvatar() {
    final bool hasPhoto = _currentUserPhotoUrl.trim().isNotEmpty;

    if (!hasPhoto) {
      return CircleAvatar(
        radius: 45,
        backgroundColor: Colors.white,
        child: Text(
          _profileInitial(),
          style: const TextStyle(
            color: Color(0xFF6B0000),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Image.network(
          _currentUserPhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: Text(
                _profileInitial(),
                style: const TextStyle(
                  color: Color(0xFF6B0000),
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const DashboardContent(),
      const NotificationScreen(),
      ProfileTabContent(
        onBackToHome: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }

        return true;
      },
      child: Scaffold(
        drawer: _buildDrawer(),
        body: screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: primaryMaroon,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications),
                label: "Notifications",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Profile",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
            decoration: const BoxDecoration(color: primaryMaroon),
            child: Column(
              children: [
                _buildDrawerProfileAvatar(),
                const SizedBox(height: 12),
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  Icons.star_border,
                  "Rate Us",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RateUsScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  Icons.info_outline,
                  "About App",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AboutAppScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  Icons.feedback_outlined,
                  "Help/Feedback",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpFeedbackScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  Icons.settings_outlined,
                  "Settings",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: _isLoggingOut
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: primaryMaroon,
                        ),
                      )
                    : const Icon(Icons.logout, color: primaryMaroon),
                title: Text(
                  _isLoggingOut ? 'Logging out...' : 'Logout',
                  style: const TextStyle(
                    color: primaryMaroon,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _isLoggingOut ? null : _logout,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryMaroon : Colors.black87,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? primaryMaroon : Colors.black87,
        ),
      ),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  @override
  void dispose() {
    _userProfileSubscription?.cancel();
    super.dispose();
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  int _carouselIndex = 0;
  List<String> _carouselImages = [];
  bool _isLoadingBanners = true;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    try {
      final List<String> loadedUrls = await PatientBannerSdk.fetchBannerImages();

      if (!mounted) return;

      if (loadedUrls.isNotEmpty) {
        setState(() {
          _carouselImages = loadedUrls;
          _isLoadingBanners = false;
        });

        return;
      }
    } catch (e) {
      debugPrint("Error fetching banners: $e");
    }

    if (!mounted) return;

    setState(() {
      _carouselImages = [
        'lib/assets/blood_donation.png',
        'lib/assets/blood_donation.png',
        'lib/assets/blood_donation.png',
      ];
      _isLoadingBanners = false;
    });
  }

  int _acceptedDonorsCount(QuerySnapshot<Map<String, dynamic>> snapshot) {
    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final String status = (data['status'] ?? data['request_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status == 'accepted') {
        count++;
      }
    }

    return count;
  }

  Widget _buildContactDonorsCard(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildServiceCard(
        title: "Contact Donors",
        icon: Icons.call_rounded,
        badgeCount: 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ContactDonorsScreen(),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donation_requests')
          .where('patient_uid', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final int acceptedCount =
            snapshot.hasData ? _acceptedDonorsCount(snapshot.data!) : 0;

        return _buildServiceCard(
          title: "Contact Donors",
          icon: Icons.call_rounded,
          badgeCount: acceptedCount,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ContactDonorsScreen(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text(
          "BLOOD CONNECT",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.visibility_outlined,
              color: Colors.white,
              size: 27,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IncomingBloodRequestsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                _isLoadingBanners
                    ? Container(
                        height: MediaQuery.of(context).size.height * 0.28,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: primaryMaroon,
                          ),
                        ),
                      )
                    : CarouselSlider.builder(
                        itemCount: _carouselImages.length,
                        options: CarouselOptions(
                          height: MediaQuery.of(context).size.height * 0.28,
                          viewportFraction: 1.0,
                          autoPlay: true,
                          autoPlayInterval: const Duration(seconds: 4),
                          onPageChanged: (index, reason) {
                            setState(() => _carouselIndex = index);
                          },
                        ),
                        itemBuilder: (context, index, realIndex) {
                          final imagePathOrUrl = _carouselImages[index];

                          final bool isNetworkImage =
                              imagePathOrUrl.startsWith('http://') ||
                                  imagePathOrUrl.startsWith('https://');

                          return isNetworkImage
                              ? Image.network(
                                  imagePathOrUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  imagePathOrUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                        },
                      ),
                if (!_isLoadingBanners && _carouselImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _carouselImages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _carouselIndex == index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _carouselIndex == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.12,
                children: [
                  _buildServiceCard(
                    title: "Find Donors",
                    icon: Icons.search_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FindNearbyDonorsScreen(),
                      ),
                    ),
                  ),
                  _buildServiceCard(
                    title: "Blood Banks",
                    icon: Icons.local_hospital_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BloodBankScreen(),
                      ),
                    ),
                  ),
                  _buildServiceCard(
                    title: "Blood Request",
                    icon: Icons.assignment_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BloodRequestScreen(),
                      ),
                    ),
                  ),
                  _buildContactDonorsCard(context),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: primaryMaroon,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: blackColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 46, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: primaryMaroon,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
