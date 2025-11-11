// lib/features_page.dart
import 'package:flutter/material.dart';
import 'statistics_page.dart'; // Import halaman stats Anda
import 'chatbot_page.dart'; // Import halaman chatbot Anda
import 'reflection_page.dart'; // Import halaman refleksi baru

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);

    return Scaffold(
      // Kita gunakan background putih agar card birunya menonjol
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pusat Fitur'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- PERUBAHAN DI SINI ---
          // Ikon untuk semua card diubah menjadi 'primaryBlue'
          // agar warnanya seragam dan sesuai tema.
          _buildFeatureCard(
            context: context,
            icon: Icons.chat_bubble_outline,
            title: 'MoodBuddy (Chatbot)',
            subtitle: 'Bicarakan perasaan Anda dengan AI',
            iconColor: primaryBlue, // <-- Diubah menjadi biru
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatbotPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context: context,
            icon: Icons.bar_chart_outlined,
            title: 'Statistik Mood',
            subtitle: 'Lihat pola mood Anda dari waktu ke waktu',
            iconColor: primaryBlue, // <-- Diubah menjadi biru
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context: context,
            icon: Icons.lightbulb_outline,
            title: 'Refleksi Hari Ini',
            subtitle: 'Rangkuman dan motivasi harian dari AI',
            iconColor: primaryBlue, // <-- Diubah menjadi biru
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReflectionPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- PERUBAHAN UTAMA PADA STYLING CARD ---
  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor, // Menggunakan parameter ini untuk ikon
    required VoidCallback onTap,
  }) {
    // Mengganti 'Card' dengan 'Container' agar bisa meniru
    // style dari 'HomeScreenContent' dengan tepat.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF), // Latar belakang biru muda (dari Home)
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(
          color: const Color(0xFFE0F2FE),
          width: 1.5,
        ), // Border biru (dari Home)
        boxShadow: [
          // Menambahkan shadow manual agar mirip Card
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // Bungkus dengan 'Material' agar 'InkWell' (efek ripple) berfungsi
      child: Material(
        color: Colors.transparent, // Transparan agar warna Container terlihat
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15.0), // Samakan radiusnya
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(icon, size: 36, color: iconColor), // Pakai iconColor
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87, // Pastikan teks jelas
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700], // Sedikit lebih gelap
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
