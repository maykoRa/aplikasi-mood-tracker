import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'firebase_options.dart'; // Import file konfigurasi
import 'splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

// Ubah main menjadi async
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Wajib ada sebelum init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Gunakan konfigurasi
  );
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoodWise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Nanti kita ganti ini dengan AuthWrapper
    );
  }
}
