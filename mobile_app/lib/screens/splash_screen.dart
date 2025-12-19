import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 3)); // Show splash for 3 seconds
    if (!mounted) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    // Wait for auth check to complete if it hasn't already (though provider constructor starts it)
    // A better way is to listen to the provider, but for simplicity:
    if (appProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark blue/slate
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 100,
              color: Colors.cyanAccent,
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 1200.ms, color: const Color(0xFF80DDFF))
            .animate() // Add another effect
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOut)
            .then()
            .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1), duration: 1000.ms, curve: Curves.easeInOut),
            
            const SizedBox(height: 24),
            
            const Text(
              'GSM MONITOR',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0),
            
            const SizedBox(height: 8),
            
            const Text(
              'AI-Powered Industrial Safety',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
