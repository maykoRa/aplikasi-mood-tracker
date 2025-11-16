import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_entry_page.dart';
import 'entry_detail_page.dart';
import 'profile_page.dart';
import 'history_page.dart';
import 'features_page.dart';

class HomePage extends StatefulWidget {
  final String? newReflection;
  const HomePage({super.key, this.newReflection});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // --- PERUBAHAN DI SINI ---
  // Halaman Stats dan Chatbot diganti dengan History dan Features
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreenContent(),
    const HistoryPage(), // <-- GANTI: Dulu StatisticsPage
    const Scaffold(body: Center(child: Text('Placeholder FAB'))),
    const FeaturesPage(), // <-- GANTI: Dulu ChatbotPage
    const ProfilePage(),
  ];
  // --- AKHIR PERUBAHAN ---

  void _onItemTapped(int index) {
    if (index != 2) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.newReflection != null) {
        _showReflectionDialog(widget.newReflection!);
      }
    });
  }

  void _showReflectionDialog(String reflection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✨ Info Refleksi Diri'),
        content: Text(reflection),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Properti ini (dari perbaikan kita sebelumnya) SANGAT PENTING
      // agar keyboard di ChatbotPage tidak merusak UI.
      resizeToAvoidBottomInset: false,

      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEntryPage()),
        ),
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
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBottomNavItem(Icons.home_outlined, 'Home', 0),
                  // --- PERUBAHAN DI SINI ---
                  _buildBottomNavItem(Icons.history, 'History', 1),
                  // --- AKHIR PERUBAHAN ---
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- PERUBAHAN DI SINI ---
                  _buildBottomNavItem(Icons.apps_outlined, 'Features', 3),
                  // --- AKHIR PERUBAHAN ---
                  _buildBottomNavItem(Icons.person_outline, 'Profile', 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? const Color(0xFF3B82F6) : Colors.grey;
    IconData displayIcon = icon;

    // --- PERUBAHAN DI SINI ---
    // Mengganti ikon yang 'terpilih'
    if (isSelected) {
      switch (index) {
        case 0:
          displayIcon = Icons.home; // Menjadi solid
          break;
        case 1:
          displayIcon = Icons.history; // Menjadi solid (sama)
          break;
        case 3:
          displayIcon = Icons.apps; // Menjadi solid
          break;
        case 4:
          displayIcon = Icons.person; // Menjadi solid
          break;
      }
    }
    // --- AKHIR PERUBAHAN ---

    return MaterialButton(
      minWidth: 40,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(displayIcon, color: color),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// =========================================================================
// HOMESCREENCONTENT (TIDAK BERUBAH, TETAP SAMA SEPERTI SEBELUMNYA)
// =========================================================================

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  String? _todayRecommendation;

  @override
  void initState() {
    super.initState();
    _loadTodayRecommendation();
  }

  Future<void> _loadTodayRecommendation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final summaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('summary')
          .doc('daily')
          .get();

      if (summaryDoc.exists) {
        setState(() {
          _todayRecommendation =
              summaryDoc.data()?['recommendation'] ??
              'Coba luangkan waktu istirahat sejenak dan nikmati hal kecil hari ini';
        });
      }
    } catch (e) {
      print('Error loading summary: $e');
    }
  }

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
        return 'Tidak Diketahui';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getTodayEntriesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day),
    );
    final endOfDay = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    return FirebaseFirestore.instance
        .collection('mood_entries')
        .where('userId', isEqualTo: user.uid)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThanOrEqualTo: endOfDay)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    final user = FirebaseAuth.instance.currentUser;
    final String userName =
        user?.displayName ?? user?.email?.split('@').first ?? "Pengguna";
    final DateFormat cardDateTimeFormat = DateFormat(
      'd MMMM yyyy, HH:mm',
      'id_ID',
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
          children: [
            Text(
              'Halo, ${userName.split(' ').first}!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            const Text(
              'Rekomendasi hari ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(15.0),
                border: Border.all(color: const Color(0xFFE0F2FE), width: 1.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _todayRecommendation ??
                          'Coba luangkan waktu istirahat sejenak dan nikmati hal kecil hari ini',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // Entri Mood & Jurnal
            const Text(
              'Entri Mood & Jurnal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryBlue, // USAGE: primaryBlue
              ),
            ),
            const SizedBox(height: 15),

            // StreamBuilder
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getTodayEntriesStream(),
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
                        'Belum ada entri hari ini.\nYuk, tambahkan mood kamu!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }

                final entries = snapshot.data!.docs;
                return Column(
                  children: entries.map((doc) {
                    final entry = doc.data();
                    final mood = entry['mood'] as String? ?? 'Tidak Diketahui';
                    final journal = entry['journal'] as String? ?? '';
                    final timestamp = entry['timestamp'] as Timestamp?;
                    final reflection = entry['reflection'] as String?;
                    final dateTimeString = timestamp != null
                        ? cardDateTimeFormat.format(timestamp.toDate())
                        : 'Waktu tidak valid';
                    final borderColor = _getBorderColor(mood);
                    final emoji = _getEmoji(mood);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: _buildMoodCard(
                        emoji: emoji,
                        moodText: mood,
                        description: journal.isNotEmpty
                            ? journal
                            : 'Tidak ada catatan jurnal.',
                        date: dateTimeString,
                        borderColor: borderColor,
                        reflection: reflection,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EntryDetailPage(entryId: doc.id),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodCard({
    required String emoji,
    required String moodText,
    required String description,
    required String date,
    required Color borderColor,
    String? reflection,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      if (description.isNotEmpty &&
                          description != 'Tidak ada catatan jurnal.')
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0, bottom: 8.0),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
