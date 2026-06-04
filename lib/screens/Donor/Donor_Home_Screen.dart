// lib/screens/home_screen.dart
import 'dart:convert';
import 'package:blood_donation_app/screens/Donor/Donor_Donation_Request_Screen.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

// import 'Ambulance.dart';
import 'Donor_Find_Nearby_Donors.dart';
import 'Donor_Blood_Bank_Screen.dart';
// import 'Donor_Blood_Request_Screen.dart';
import 'Donor_Profile_Screen.dart';
import 'Donor_Blood_Donate_Screen.dart';
import 'Public_Request_Nearby.dart';
import 'Donor_Find_Volunteer_Screen.dart';
import 'Donor_Notification_Screen.dart';
import 'Donor_Search_Screen.dart';
import 'Certificate_Screen.dart';
// import 'Forget_Password.dart';
import 'Sos.dart';

class DonorHomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  const DonorHomeScreen({super.key});

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const DashboardContent(),
      const SearchScreen(),
      const DonorNotificationScreen(),
      DonorProfileTabContent(
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
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: "Search",
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

  // ==================== Drawer ====================
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
            decoration: const BoxDecoration(color: primaryMaroon),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 55, color: Color(0xFF6B0000)),
                ),
                SizedBox(height: 12),
                Text(
                  "Hello,",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  "Blood Connect",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(Icons.list_alt_outlined, "View Requests"),
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
                _buildDrawerItem(
                  Icons.notifications_outlined,
                  "Notifications",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DonorNotificationScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(Icons.contact_mail_outlined, "Contact Us"),
                _buildDrawerItem(Icons.favorite_border, "Thank You"),
                _buildDrawerItem(Icons.share_outlined, "Share App"),
                _buildDrawerItem(Icons.star_border, "Rate Us"),
                _buildDrawerItem(Icons.privacy_tip_outlined, "Privacy Policy"),
                _buildDrawerItem(
                  Icons.description_outlined,
                  "License Agreement",
                ),
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
                    await AuthTokenService.clearSession();
                    if (!mounted) return;
                    Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
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
      final response = await AuthTokenService.authorizedGet('/fetch-banners');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List dynamicList = data['data'];
          final List<String> loadedUrls = [];
          for (var item in dynamicList) {
            if (item is Map) {
              if (item['image_url'] != null) {
                loadedUrls.add(item['image_url'].toString());
              } else if (item['url'] != null) {
                loadedUrls.add(item['url'].toString());
              } else if (item['image'] != null) {
                loadedUrls.add(item['image'].toString());
              }
            }
          }
          if (loadedUrls.isNotEmpty) {
            setState(() {
              _carouselImages = loadedUrls;
              _isLoadingBanners = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching database dynamic slider banners: $e");
    }

    // Fallback block if backend dashboard nodes are entirely unreachable
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
      appBar: AppBar(
        title: const Text(
          "BLOOD CONNECT",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
              Icons.remove_red_eye_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PublicRequestsNearby()),
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
                          child: CircularProgressIndicator(color: primaryMaroon),
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
                          final isNetworkImage = imagePathOrUrl.startsWith('http://') || imagePathOrUrl.startsWith('https://');

                          return isNetworkImage
                              ? Image.network(
                                  imagePathOrUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                  ),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(color: primaryMaroon),
                                      ),
                                    );
                                  },
                                )
                              : Image.asset(
                                  imagePathOrUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) => Container(
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
                childAspectRatio: 1.08,
                children: [
                  _buildServiceCard(
                    title: "Donate Blood",
                    icon: Icons.favorite,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BloodDonateScreen(),
                      ),
                    ),
                  ),
                  _buildServiceCard(
                    title: "Blood Bank",
                    icon: Icons.local_hospital,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BloodBankScreen(),
                      ),
                    ),
                  ),
                  _buildServiceCard(
                    title: "Donation Requests",
                    icon: Icons.message,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DonorDonationRequestScreen(
                        ),
                      ),
                    ),
                  ),
                  _buildServiceCard(
                    title: "Nearby Volunteers",
                    icon: Icons.search,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FindVolunteerScreen(),
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}