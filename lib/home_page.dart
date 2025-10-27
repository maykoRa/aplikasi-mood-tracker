import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_entry_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart';

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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEntryPage(),
            ), // <-- Arahkan ke AddEntryPage
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
    final user = FirebaseAuth.instance.currentUser; // Ambil user saat ini
    final String userName =
        user?.displayName ?? user?.email?.split('@').first ?? "Pengguna";

    // Format tanggal untuk tampilan di card
    final DateFormat cardDateFormat = DateFormat('d MMMM yyyy', 'id_ID');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // Bungkus Column dengan SingleChildScrollView
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (Greeting & Recommendation Card tetap sama)
              Text('Halo, ${userName.split(' ').first}!' /* ... style ... */),
              const SizedBox(height: 30),
              const Text('Rekomendasi hari ini' /* ... style ... */),
              const SizedBox(height: 10),
              Container(/* ... Recommendation Card ... */),
              const SizedBox(height: 35),

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
                // Query: ambil data dari 'mood_entries', filter by userId, urutkan descending by timestamp
                stream: FirebaseFirestore.instance
                    .collection('mood_entries')
                    .where(
                      'userId',
                      isEqualTo: user?.uid,
                    ) // Filter berdasarkan user ID
                    .orderBy(
                      'timestamp',
                      descending: true,
                    ) // Urutkan terbaru di atas
                    .snapshots(), // Dapatkan stream data
                builder: (context, snapshot) {
                  // Tampilkan loading jika masih menunggu data
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Tampilkan pesan error jika terjadi masalah
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  // Tampilkan pesan jika tidak ada data
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.0),
                        child: Text(
                          'Belum ada entri.\nYuk, tambahkan mood hari ini!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  // Jika ada data, tampilkan dalam bentuk list
                  final entries = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap:
                        true, // Agar ListView menyesuaikan tinggi kontennya
                    physics:
                        const NeverScrollableScrollPhysics(), // Nonaktifkan scroll internal ListView
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry =
                          entries[index].data() as Map<String, dynamic>;
                      final mood =
                          entry['mood'] as String? ?? 'Tidak Diketahui';
                      final journal = entry['journal'] as String? ?? '';
                      final timestamp = entry['timestamp'] as Timestamp?;
                      final dateString = timestamp != null
                          ? cardDateFormat.format(timestamp.toDate())
                          : 'Tanggal tidak valid';
                      final borderColor = _getBorderColor(mood);
                      final emoji = _getEmoji(mood);

                      // Gunakan _buildMoodCard yang sudah ada
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 15.0,
                        ), // Beri jarak antar card
                        child: _buildMoodCard(
                          emoji: emoji,
                          moodText: mood,
                          description: journal.isNotEmpty
                              ? journal
                              : 'Tidak ada catatan jurnal.', // Tampilkan placeholder jika jurnal kosong
                          date: dateString,
                          borderColor: borderColor,
                        ),
                      );
                    },
                  );
                },
              ),
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
