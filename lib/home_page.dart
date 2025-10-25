import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Nanti untuk ambil nama user & logout

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Untuk index BottomNavigationBar

  // Nanti akan diganti dengan halaman sebenarnya
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreenContent(), // Konten Halaman Home (Index 0)
    Text(
      'Halaman Stats',
      style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
    ),
    Text(
      'Halaman Add',
      style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
    ), // Placeholder for FAB action
    Text(
      'Halaman Chatbot',
      style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
    ),
    Text(
      'Halaman Profile',
      style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
    ),
  ];

  void _onItemTapped(int index) {
    // Navigasi atau ganti tampilan berdasarkan index yang dipilih
    // Untuk tombol Add (index 2), kita akan handle di FAB
    if (index != 2) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(
          _selectedIndex,
        ), // Tampilkan konten sesuai index
      ),
      // Tombol Tambah (Floating Action Button) di tengah
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aksi saat tombol plus (+) ditekan -> Navigasi ke halaman Add Entry
          print("Navigasi ke halaman Add Entry");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Navigasi ke halaman Add Entry nanti'),
            ),
          );
        },
        backgroundColor: const Color(0xFF3B82F6), // Warna biru
        foregroundColor: Colors.white,
        elevation: 2.0,
        shape: const CircleBorder(), // Pastikan bulat
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked, // Posisi di tengah dock
      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Bentuk lengkung untuk FAB
        notchMargin: 8.0, // Jarak antara FAB dan BottomAppBar
        child: SizedBox(
          // Dibungkus SizedBox agar bisa atur height
          height: 60.0, // Tinggi BottomNavigationBar
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Sisi Kiri
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildBottomNavItem(Icons.home, 'Home', 0),
                  _buildBottomNavItem(Icons.bar_chart, 'Stats', 1),
                ],
              ),
              // Sisi Kanan (setelah FAB)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildBottomNavItem(Icons.chat_bubble_outline, 'Chatbot', 3),
                  _buildBottomNavItem(Icons.person_outline, 'Profile', 4),
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
    final Color color = isSelected
        ? const Color(0xFF3B82F6)
        : Colors.grey; // Warna biru jika aktif, abu jika tidak

    return MaterialButton(
      minWidth: 40,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, color: color),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// Widget terpisah untuk konten Halaman Home agar lebih rapi
class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    // Nanti ambil nama user dari Firebase Auth
    final String userName =
        FirebaseAuth.instance.currentUser?.displayName ?? "Pengguna";

    return Scaffold(
      backgroundColor: Colors.white, // Background putih
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Text
              Text(
                'Halo, ${userName.split(' ').first}!', // Ambil nama depan saja
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Recommendation Card Title
              const Text(
                'Rekomendasi hari ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600, // SemiBold
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 10),

              // Recommendation Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF), // Warna biru sangat muda
                  borderRadius: BorderRadius.circular(15.0),
                  border: Border.all(
                    color: const Color(0xFFE0F2FE),
                    width: 1.0,
                  ), // Border tipis
                ),
                child: const Row(
                  // Menggunakan Row agar bisa tambah icon di akhir
                  children: [
                    Expanded(
                      // Agar teks bisa wrap jika panjang
                      child: Text(
                        'Coba luangkan waktu istirahat sejenak dan nikmati hal kecil hari ini',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.4, // Line spacing
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      '📝',
                      style: TextStyle(fontSize: 20),
                    ), // Emoji (atau Icon)
                  ],
                ),
              ),
              const SizedBox(height: 35),

              // Mood & Journal Entry Title
              const Text(
                'Entri Mood & Jurnal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600, // SemiBold
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 15),

              // Mood Entry Cards (Contoh Statis)
              _buildMoodCard(
                emoji: '😄', // Atau Image.asset jika punya gambar
                moodText: 'Sangat Baik',
                description: 'Hari ini berjalan lancar dan penuh semangat!',
                date: '18 Oktober 2025',
                borderColor: Colors.green, // Warna border hijau
              ),
              const SizedBox(height: 15),
              _buildMoodCard(
                emoji: '😠', // Atau Image.asset
                moodText: 'Sangat Buruk',
                description:
                    'Hari ini cukup berat, tapi aku berusaha tetap tenang.',
                date: '17 Oktober 2025',
                borderColor: Colors.red, // Warna border merah
              ),
              // Nanti list ini akan dinamis dari data Firestore
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget untuk membuat card entri mood
  Widget _buildMoodCard({
    required String emoji,
    required String moodText,
    required String description,
    required String date,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: borderColor, width: 1.5), // Border berwarna
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
          // Emoji (atau Gambar)
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 15),
          // Teks Mood, Deskripsi, Tanggal
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
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  maxLines: 2, // Batasi deskripsi jika terlalu panjang
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: borderColor,
                    fontWeight: FontWeight.w500,
                  ), // Warna tanggal sesuai border
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
