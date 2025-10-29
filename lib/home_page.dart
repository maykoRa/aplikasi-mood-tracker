import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_entry_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Index untuk BottomNavigationBar

  static List<Widget> _widgetOptions = <Widget>[
    HomeScreenContent(), // Konten Halaman Home (Index 0)
    Scaffold(body: Center(child: Text('Halaman Stats'))), // Placeholder
    Scaffold(
      body: Center(child: Text('Placeholder FAB')),
    ), // Index 2 tidak dipakai langsung
    Scaffold(body: Center(child: Text('Halaman Chatbot'))), // Placeholder
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (index != 2) {
      // Index 2 (FAB) ditangani terpisah
      setState(() {
        _selectedIndex = index;
      });
      // Navigasi ke halaman lain jika diperlukan (misal pakai Navigator)
      // switch (index) {
      //   case 1: Navigator.push(context, MaterialPageRoute(builder: (_) => StatsPage())); break;
      //   case 3: Navigator.push(context, MaterialPageRoute(builder: (_) => ChatbotPage())); break;
      //   case 4: Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage())); break;
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tampilkan konten halaman yang sesuai dengan index terpilih
      body: IndexedStack(
        // Gunakan IndexedStack agar state halaman tidak hilang saat ganti tab
        index: _selectedIndex,
        children: _widgetOptions,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigasi ke AddEntryPage saat FAB ditekan
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEntryPage()),
          );
        },
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2.0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                // Item Kiri
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildBottomNavItem(
                    Icons.home_filled,
                    'Home',
                    0,
                  ), // Icon filled jika aktif
                  _buildBottomNavItem(Icons.bar_chart, 'Stats', 1),
                ],
              ),
              Row(
                // Item Kanan
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildBottomNavItem(
                    Icons.chat_bubble,
                    'Chatbot',
                    3,
                  ), // Icon filled jika aktif
                  _buildBottomNavItem(
                    Icons.person,
                    'Profile',
                    4,
                  ), // Icon filled jika aktif
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget untuk membuat item BottomNavigationBar
  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? const Color(0xFF3B82F6) : Colors.grey;
    // Gunakan ikon filled jika terpilih (opsional, sesuaikan nama ikonnya)
    IconData displayIcon = icon;
    if (isSelected) {
      switch (index) {
        case 0:
          displayIcon = Icons.home_filled;
          break;
        case 1:
          displayIcon = Icons.bar_chart;
          break; // Ganti jika ada versi filled
        case 3:
          displayIcon = Icons.chat_bubble;
          break; // Ganti jika ada versi filled
        case 4:
          displayIcon = Icons.person;
          break; // Ganti jika ada versi filled
      }
    }

    return MaterialButton(
      minWidth: 40,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(displayIcon, color: color), // Gunakan displayIcon
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// Widget terpisah untuk konten Halaman Home
class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  // Helper untuk menentukan warna border berdasarkan mood text
  Color _getBorderColor(String mood) {
    switch (mood) {
      case 'Sangat Baik':
        return Colors.green;
      case 'Baik':
        return Colors.lightGreen;
      case 'Biasa Saja':
        return Colors.orange;
      case 'Buruk':
        return Colors.deepOrange;
      case 'Sangat Buruk':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper untuk mendapatkan emoji berdasarkan mood text
  String _getEmoji(String mood) {
    switch (mood) {
      case 'Sangat Baik':
        return '😄';
      case 'Baik':
        return '😊';
      case 'Biasa Saja':
        return '😐';
      case 'Buruk':
        return '😟';
      case 'Sangat Buruk':
        return '😠';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    final user = FirebaseAuth.instance.currentUser;
    // Coba ambil nama dari profil, fallback ke bagian email, fallback lagi ke default
    final String userName =
        user?.displayName ?? user?.email?.split('@').first ?? "Pengguna";

    // Format tanggal BARU untuk tampilan di card (termasuk jam:menit)
    final DateFormat cardDateTimeFormat = DateFormat(
      'd MMMM yyyy, HH:mm',
      'id_ID',
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Gunakan ListView agar seluruh halaman bisa di-scroll jika konten panjang
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
          children: [
            // Greeting Text
            Text(
              'Halo, ${userName.split(' ').first}!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Recommendation Card Title
            const Text(
              'Rekomendasi hari ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 10),

            // Recommendation Card (Statis)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(15.0),
                border: Border.all(color: const Color(0xFFE0F2FE), width: 1.0),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Coba luangkan waktu istirahat sejenak dan nikmati hal kecil hari ini',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('📝', style: TextStyle(fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // Mood & Journal Entry Title
            const Text(
              'Entri Mood & Jurnal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 15),

            // StreamBuilder untuk menampilkan entri dari Firestore
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('mood_entries')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30.0),
                      child: Text(
                        'Belum ada entri.\nYuk, tambahkan mood hari ini!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }

                // Jika ada data, tampilkan dalam Column (karena sudah di dalam ListView)
                final entries = snapshot.data!.docs;
                return Column(
                  // Ganti ListView.builder menjadi Column
                  children: entries.map((doc) {
                    final entry = doc.data() as Map<String, dynamic>;
                    final mood = entry['mood'] as String? ?? 'Tidak Diketahui';
                    final journal = entry['journal'] as String? ?? '';
                    final timestamp = entry['timestamp'] as Timestamp?;
                    final dateTimeString = timestamp != null
                        ? cardDateTimeFormat.format(timestamp.toDate())
                        : 'Waktu tidak valid';
                    final borderColor = _getBorderColor(mood);
                    final emoji = _getEmoji(mood);

                    // Beri jarak antar card
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: _buildMoodCard(
                        emoji: emoji,
                        moodText: mood,
                        description: journal.isNotEmpty
                            ? journal
                            : 'Tidak ada catatan jurnal.',
                        date: dateTimeString, // Sudah termasuk waktu
                        borderColor: borderColor,
                      ),
                    );
                  }).toList(), // Ubah hasil map menjadi list
                );
              },
            ),
            const SizedBox(
              height: 80,
            ), // Beri space di bawah agar tidak tertutup FAB
          ],
        ),
      ),
    );
  }

  // Helper widget untuk membuat card entri mood
  Widget _buildMoodCard({
    required String emoji,
    required String moodText,
    required String description,
    required String date, // Sekarang berisi tanggal dan waktu
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moodText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                // Tampilkan deskripsi hanya jika ada
                if (description.isNotEmpty &&
                    description != 'Tidak ada catatan jurnal.')
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 3.0,
                      bottom: 8.0,
                    ), // Beri padding atas bawah
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const SizedBox(
                    height: 8,
                  ), // Beri space jika tidak ada deskripsi
                Text(
                  date, // Tampilkan tanggal dan waktu
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ), // Warna sedikit diubah
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // Akhir HomeScreenContent
