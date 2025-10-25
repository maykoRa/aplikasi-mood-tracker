// lib/login_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'register_page.dart';
// import 'home_page.dart'; // Nanti

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false; // State untuk loading indicator

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Fungsi untuk handle Sign In
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Sign in dengan Firebase Authentication
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Jika berhasil, navigasi ke Halaman Home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const Scaffold(body: Center(child: Text('Halaman Home'))),
            // builder: (context) => const HomePage(), // Nanti ganti ke sini
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Tangani error spesifik dari Firebase Auth
      String message = 'Login gagal. Periksa kembali email dan password Anda.';
      print('Firebase Auth Error Code: ${e.code}'); // Untuk debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Tangani error umum lainnya
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    const Color lightBlueOutline = Color(0xFFADD8E6);
    const Color hintTextColor = Colors.grey;

    return Scaffold(
      backgroundColor: Colors.white, // Background putih
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 30.0,
            ), // Sesuaikan padding utama
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/app-logo-icon.png', // Logo tanpa background
                  height: 120, // Sedikit lebih besar?
                ),
                const SizedBox(height: 10),

                // Welcome Text (lebih kecil)
                const Text(
                  'Welcome to MoodWise',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, // Ukuran lebih kecil
                    fontWeight: FontWeight.w500, // Medium
                    color: Colors.black54, // Warna sedikit pudar
                  ),
                ),
                const SizedBox(height: 40), // Jarak lebih besar sebelum card
                // Sign In Title
                const Text(
                  'SIGN IN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28, // Sedikit lebih besar
                    fontWeight: FontWeight.bold,
                    color: Colors.black87, // Sedikit pudar
                  ),
                ),
                const SizedBox(height: 30),

                // Card Container untuk Form
                Container(
                  padding: const EdgeInsets.all(25.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      20.0,
                    ), // Sudut lebih tumpul
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        spreadRadius: 3,
                        blurRadius: 10,
                        offset: const Offset(0, 5), // Shadow tipis
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Text Field
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isLoading, // Disable saat loading
                          decoration: InputDecoration(
                            hintText: 'Email', // Gunakan hintText
                            hintStyle: const TextStyle(color: hintTextColor),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15.0,
                              horizontal: 20.0,
                            ), // Padding dalam field
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                15.0,
                              ), // Sudut lebih tumpul
                              borderSide: const BorderSide(
                                color: lightBlueOutline,
                                width: 1.0,
                              ), // Border biru muda tipis
                            ),
                            enabledBorder: OutlineInputBorder(
                              // Border saat tidak fokus
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: const BorderSide(
                                color: lightBlueOutline,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              // Border saat fokus
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: const BorderSide(
                                color: primaryBlue,
                                width: 1.5,
                              ), // Border biru lebih tebal
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter your email';
                            if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value))
                              return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20), // Sesuaikan jarak
                        // Password Text Field
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_isLoading, // Disable saat loading
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: hintTextColor),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15.0,
                              horizontal: 20.0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: const BorderSide(
                                color: lightBlueOutline,
                                width: 1.0,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: const BorderSide(
                                color: lightBlueOutline,
                                width: 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15.0),
                              borderSide: const BorderSide(
                                color: primaryBlue,
                                width: 1.5,
                              ),
                            ),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Please enter your password';
                            return null;
                          },
                        ),
                        const SizedBox(height: 35), // Jarak ke tombol
                        // Sign In Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ), // Padding vertikal tombol
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                30.0,
                              ), // Sudut sangat tumpul (pil)
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.0,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                        const SizedBox(height: 15),

                        // Sign Up Button (Outlined Style)
                        OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  // Nonaktifkan saat loading
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: primaryBlue,
                              width: 1.5,
                            ), // Outline biru
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                30.0,
                              ), // Sudut sangat tumpul (pil)
                            ),
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: primaryBlue, // Warna teks biru
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ), // Akhir Card Container
              ],
            ),
          ),
        ),
      ),
    );
  }
}
