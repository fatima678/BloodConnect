import 'package:flutter/material.dart';
import 'dart:async';
import 'role_screen.dart';
import '../../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Main Animation Controllers for sequential pop-ups
  late AnimationController _logoController;
  late AnimationController _nameController;
  late AnimationController _taglineController;
  late AnimationController _dotsFadeController;
  
  // Continuous and Action Controllers
  late AnimationController _pulseController;
  late AnimationController _blinkController; 

  // Animations Mapping Setup
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _nameFade;
  late Animation<Offset> _nameSlide;
  late Animation<double> _taglineFade;
  late Animation<double> _dotsFade;
  late Animation<double> _pulseAnimation;

  // Navigation controller flag to prevent double routing executions
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 1. Logo Animation Configuration (0ms to 800ms)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // 2. App Name Animation Configuration (Starts at 700ms, duration 700ms)
    _nameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _nameFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _nameController, curve: Curves.easeOut),
    );
    _nameSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _nameController, curve: Curves.easeOutCubic),
    );

    // 3. Tagline Animation Configuration (Starts at 1300ms, duration 600ms)
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );

    // 4. Loading Dots Section Fade-in Configuration (Starts at 1800ms, duration 500ms)
    _dotsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotsFadeController, curve: Curves.easeIn),
    );

    // Continuous Idle Pulse Background effect for main logo frame container
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Single Execution Blinking Controller for lower dots (1600ms lifecycle duration)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Listener to catch exactly when the 3rd dot blinks to invoke instant screen transitions
    _blinkController.addListener(() {
      // 3rd dot activates during the last third portion of the single loop sequence (value >= 0.66)
      if (_blinkController.value >= 0.66 && !_hasNavigated) {
        _navigateToRoleScreen();
      }
    });

    // Trigger sequential staggered timeline execution delays
    _logoController.forward();
    
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) _nameController.forward();
    });
    
    Timer(const Duration(milliseconds: 1300), () {
      if (mounted) _taglineController.forward();
    });
    
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _dotsFadeController.forward();
        _blinkController.forward(); // Run dots blink sequence forward once
      }
    });

    // Safety fallback insurance mechanism to ensure application layout transitions regardless
    Timer(const Duration(milliseconds: 7000), () {
      if (mounted && !_hasNavigated) {
        _navigateToRoleScreen();
      }
    });
  }

  // Central routing controller method
  void _navigateToRoleScreen() {
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const RoleSelectionScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    _dotsFadeController.dispose();
    _pulseController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  // Staggered blink calculation formula matrix mapping
  Widget buildBlinkingDot(int dotIndex) {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        double animationValue = _blinkController.value;
        double opacity = 0.3; // Base inactive state visibility dim level
        
        if (_blinkController.isCompleted || _hasNavigated) {
          opacity = 1.0;
        } else {
          // Break single execution forward pass frame timeline logically into 3 active window partitions
          if (dotIndex == 0 && animationValue < 0.33) {
            opacity = 1.0;
          } else if (dotIndex == 1 && animationValue >= 0.33 && animationValue < 0.66) {
            opacity = 1.0;
          } else if (dotIndex == 2 && animationValue >= 0.66) {
            opacity = 1.0; // 3rd dot shines bright, instantly firing navigation handler
          }
        }

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: opacity == 1.0 ? 1.15 : 0.9,
            child: child,
          ),
        );
      },
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: splashGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Compresses child stacks strictly to accurate core center heights
                  children: [
                    
                    // ==================== 1. LOGO SECTION (POP-UP) ====================
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // OUTER GLOW
                              Container(
                                height: 240,
                                width: 240,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.18),
                                      blurRadius: 90,
                                      spreadRadius: 35,
                                    ),
                                    BoxShadow(
                                      color: primaryMaroon.withOpacity(0.45),
                                      blurRadius: 70,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                              ),

                              // MAIN CIRCLE
                              Container(
                                height: 185,
                                width: 185,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.20),
                                    width: 1.5,
                                  ),
                                ),
                              ),

                              // BLOOD ICON
                              const Icon(
                                Icons.bloodtype_rounded,
                                size: 165,
                                color: whiteColor,
                              ),

                              // MEDICAL PLUS ICON
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 42,
                                  color: primaryMaroon,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 45),

                    // ==================== 2. TEXTS SECTION (POP-UP WITH BACK SHADOWS) ====================
                    SlideTransition(
                      position: _nameSlide,
                      child: FadeTransition(
                        opacity: _nameFade,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              appNamePart1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: whiteColor,
                                letterSpacing: 6,
                                height: 1,
                                shadows: [
                                  BoxShadow(
                                    blurRadius: 18,
                                    color: Colors.black38,
                                    offset: Offset(2, 4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xffFFE5E5),
                                  ],
                                ).createShader(bounds);
                              },
                              child: Text(
                                appNamePart2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                  height: 1,
                                  shadows: [
                                    // Synchronized identical back shadow layer to match appNamePart1 precisely
                                    BoxShadow(
                                      blurRadius: 18,
                                      color: Colors.black38,
                                      offset: Offset(2, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 45),

                    // ==================== 3. TAGLINE SECTION (POP-UP) ====================
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          tagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: whiteColor,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ==================== 4. DOTS SECTION (FADE & POP RUN TO ROUTE) ====================
                    FadeTransition(
                      opacity: _dotsFade,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildBlinkingDot(0),
                          const SizedBox(width: 8),
                          buildBlinkingDot(1),
                          const SizedBox(width: 8),
                          buildBlinkingDot(2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}