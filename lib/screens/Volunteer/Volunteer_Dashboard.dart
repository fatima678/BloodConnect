// lib/screens/volunteer_dashboard_screen.dart
import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/routes.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  State<VolunteerDashboardScreen> createState() =>
      _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState extends State<VolunteerDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const DashboardContent(),
      const Scaffold(body: Center(child: Text("Search Screen"))),
      const Scaffold(body: Center(child: Text("Notifications Screen"))),
      const Scaffold(body: Center(child: Text("Profile Screen"))),
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
}

// ==================== Dashboard Content ====================
class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      debugPrint("Error fetching volunteer dashboard banners: $e");
    }

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
      key: _scaffoldKey,
      drawer: _buildDrawer(),
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
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {},
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
                          final isNetworkImage =
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
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: primaryMaroon,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.asset(
                                  imagePathOrUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
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
                childAspectRatio: 1.08,
                children: [
                  _buildServiceCard(
                    title: "Events",
                    icon: Icons.volunteer_activism,
                    onTap: () {
                      Navigator.pushNamed(context, '/volunteer-events');
                    },
                  ),
                  _buildServiceCard(
                    title: "Contact Admin",
                    icon: Icons.assignment_turned_in_outlined,
                    onTap: () {
                      Navigator.pushNamed(context, '/contact-admin');
                    },
                  ),
                  _buildServiceCard(
                    title: "Notifications",
                    icon: Icons.notifications,
                    onTap: () {
                      Navigator.pushNamed(context, '/volunteer-notifications');
                    },
                  ),
                  _buildServiceCard(
                    title: "Action 4",
                    icon: Icons.manage_accounts_outlined,
                    onTap: () {},
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
                  child: Icon(
                    Icons.groups_rounded,
                    size: 55,
                    color: Color(0xFF6B0000),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Welcome,",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  "Volunteer",
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
                _buildDrawerItem(
                  Icons.dashboard,
                  "Dashboard",
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  Icons.bloodtype,
                  "Blood Request Management",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/blood-request-management');
                  },
                ),
                _buildDrawerItem(
                  Icons.people,
                  "Donor Data",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/donor-data');
                  },
                ),
                _buildDrawerItem(
                  Icons.card_giftcard,
                  "Digital Certificate",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/certificate-generation');
                  },
                ),
                _buildDrawerItem(
                  Icons.notifications,
                  "Notifications",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
                _buildDrawerItem(
                  Icons.person,
                  "My Profile",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/volunteer-profile');
                  },
                ),
                _buildDrawerItem(
                  Icons.settings,
                  "Settings",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/volunteer-settings');
                  },
                ),
                _buildDrawerItem(
                  Icons.help_outline,
                  "Help & Support",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/help-support');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await AuthTokenService.clearSession();
                    if (!mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/role-selection', (route) => false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: primaryMaroon),
      title: Text(title),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}