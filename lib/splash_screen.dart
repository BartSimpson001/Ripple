import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ripple_sih/features/Home/presentation/pages/HomeScreen.dart';
import 'package:ripple_sih/features/auth/presentation/pages/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _mainTextScale;
  late Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _mainTextScale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0),
      ),
    );

    _controller.forward();
    _initializeAppFlow();
  }

  Future<void> _initializeAppFlow() async {
    await _requestRequiredPermissions();

    // Splash delay
    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        user != null ? const RippleHomePage() : const LoginScreen(),
      ),
    );
  }

  Future<void> _requestRequiredPermissions() async {
    try {
      await [
        Permission.camera,
        Permission.location,
        Permission.photos,
      ].request();
    } catch (e) {
      debugPrint('Permission error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'Assets/AppIc.png',
                height: 150,
              ),
              const SizedBox(height: 20),
              ScaleTransition(
                scale: _mainTextScale,
                child: Text(
                  "Ripple 24/7",
                  style: GoogleFonts.squadaOne(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF273b70),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _subtitleOpacity,
                child: Text(
                  "Initiate Small / Change Big",
                  style: GoogleFonts.adventPro(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF273b70),
                    letterSpacing: 1,
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
