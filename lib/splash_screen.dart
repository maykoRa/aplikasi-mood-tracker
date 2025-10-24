import 'dart:async';
import 'package:flutter/material.dart';
// import 'login_page.dart'; // Akan kita buat nanti

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          // Placeholder untuk halaman login
          builder: (context) => const Scaffold(
            backgroundColor:
                Colors.white, // Ganti background jadi putih untuk kontras
            body: Center(
              child: Text(
                'Halaman Login Nanti di Sini',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ),
          // builder: (context) => const LoginPage(), // Ganti dengan ini nanti
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color blueBgColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: blueBgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/app-logo.png', width: 240),
            // Bungkus Text dengan Transform.translate
            Transform.translate(
              offset: const Offset(0, -50),
              child: const Text(
                'MoodWise',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
