// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'firebase_options.dart'; // Import file konfigurasi
import 'splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// --- TAMBAHKAN IMPORT INI ---
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart'; // Import service baru kita
// --- AKHIR IMPORT ---

// Ubah main menjadi async
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);

  // --- TAMBAHKAN BLOK INISIALISASI INI ---
  // Setup Timezone
  tz.initializeTimeZones();
  // Set lokasi lokal (Gunakan lokasi yang relevan atau biarkan default)
  // 'Asia/Makassar' didapat dari konteks, ganti jika perlu
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Makassar'));
  } catch (e) {
    print("Gagal mengatur lokasi, menggunakan UTC: $e");
    tz.setLocalLocation(tz.UTC);
  }

  // Inisialisasi Notification Service
  await NotificationService().init();
  // --- AKHIR BLOK ---

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Bahasa Indonesia
      ],
      locale: const Locale('id', 'ID'),
      home: const SplashScreen(),
    );
  }
}
