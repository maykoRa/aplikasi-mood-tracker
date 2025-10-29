import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Gunakan StreamBuilder untuk mendengarkan perubahan status autentikasi
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Stream status login
      builder: (context, snapshot) {
        // Tampilkan loading indicator jika masih memeriksa status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
