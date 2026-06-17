import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';
import 'package:blood_donation_app/sdk/patient/patient_banner_sdk.dart';

import '../screens/Patient/Patient_Search_Screen.dart';
import '../screens/Patient/Patient_Notification_Screen.dart';
import '../screens/Patient/patient_blood_bank_map_screen.dart';
import 'blood_request_screen.dart';
// import '../screens/Patient/Patient_Profile_Screen.dart';
import '../screens/Patient/Patient_Public_Request_Nearby.dart';
import '../screens/Patient/Patient_find_volunteer_screen.dart';
import '../screens/Patient/patient_find_nearby_donors.dart';
import '../screens/Patient/patient_Blood_Bank_Screen.dart';
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

  @override
  void initState() {
    super.initState();
    _listenToUserData();
  }

  // Realtime user verification status tracker to safely handle dashboard header names
  void _listenToUserData() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          if (mounted) {
            setState(() {
              _currentUserName = data['name'] ?? "Blood Connect";
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const DashboardContent(),
      const SearchScreen(),
      const PatientNotificationsScreen(),
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
        body: _screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: primaryMaroon,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
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
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
              BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Notifications"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Drawer ====================
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
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 55, color: Color(0xFF6B0000)),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Hello,",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
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
                _buildDrawerItem(Icons.list_alt_outlined, "View Requests", onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BloodRequestsNearbyScreen()),
                  );
                }),
                _buildDrawerItem(
                  Icons.people_outline,
                  "Find Volunteer",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FindVolunteerScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(Icons.star_border, "Rate Us"),
                _buildDrawerItem(Icons.info_outline, "About App"),
                _buildDrawerItem(Icons.feedback_outlined, "Help/Feedback"),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: primaryMaroon),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: primaryMaroon,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    await AuthTokenService.clearSession();
                    if (!mounted) return;
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  },
                ),
              ],
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
      leading: Icon(icon, color: isSelected ? primaryMaroon : Colors.black87),
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
}

// ==================== Dashboard Content ====================
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text(
          "BLOOD CONNECT",
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
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
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PatientNotificationsScreen(),
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                      ),
                                )
                              : Image.asset(
                                  imagePathOrUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    );
  }
}