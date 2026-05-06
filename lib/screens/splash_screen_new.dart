import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreenNew extends StatefulWidget {
  const SplashScreenNew({super.key});

  @override
  State<SplashScreenNew> createState() => _SplashScreenNewState();
}

class _SplashScreenNewState extends State<SplashScreenNew> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate app initialization
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // User is logged in, navigate to main app
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        // User is not logged in, navigate to auth
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFd4af37),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // DJINAN Logo
                  Text(
                    'DJINAN',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تجارة ذكية',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFd4af37),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Loading indicator
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: const Color(0xFFd4af37),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'جاري التحميل...',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
