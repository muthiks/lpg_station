import 'package:flutter/material.dart';
import 'package:lpg_station/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup fade animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for animation to complete and show splash for minimum 2 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if user is logged in
    final isLoggedIn = await AuthService.instance.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Navigate to login screen
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo without shadow
              Image.asset('assets/images/logo.png', width: 200, height: 200),
              // const SizedBox(height: 40),
              // // App name
              // const Text(
              //   'LPG Depot',
              //   style: TextStyle(
              //     fontSize: 28,
              //     fontWeight: FontWeight.bold,
              //     color: Colors.black87,
              //     letterSpacing: 1.2,
              //   ),
              // ),
              const SizedBox(height: 10),
              // Tagline
              Text(
                'Cylinder Management System',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),
              // Loading indicator
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
