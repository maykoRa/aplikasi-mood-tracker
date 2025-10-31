import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_entry_page.dart';
import 'entry_detail_page.dart'; // TAMBAHAN
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    const HomeScreenContent(),
    Scaffold(body: Center(child: Text('Halaman Stats'))),
    Scaffold(body: Center(child: Text('Placeholder FAB'))),
    Scaffold(body: Center(child: Text('Halaman Chatbot'))),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (index != 2) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _buildBottomNavItem(Icons.home, 'Home', 0),
                  _buildBottomNavItem(Icons.bar_chart, 'Stats', 1),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBottomNavItem(Icons.chat_bubble, 'Chatbot', 3),
                  _buildBottomNavItem(Icons.person, 'Profile', 4),
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
    if (isSelected) {
      switch (index) {
        case 0:
          displayIcon = Icons.home_filled;
          break;
        case 1:
          displayIcon = Icons.bar_chart;
          break;
        case 3:
          displayIcon = Icons.chat_bubble;
          break;
        case 4:
          displayIcon = Icons.person;
          break;
      }
    }

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
        return 'Sangat Baik';
      case 'Baik':
        return 'Baik';
      case 'Biasa Saja':
        return 'Biasa Saja';
      case 'Buruk':
        return 'Buruk';
      case 'Sangat Buruk':
        return 'Sangat Buruk';
      default:
        return 'Tidak Diketahui';
    }
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

            // Rekomendasi Hari Ini (Dynamic)
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Pen', style: TextStyle(fontSize: 20)),
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
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 15),

            // StreamBuilder
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

                final entries = snapshot.data!.docs;
                return Column(
                  children: entries.map((doc) {
                    final entry = doc.data() as Map<String, dynamic>;
                    final mood = entry['mood'] as String? ?? 'Tidak Diketahui';
                    final journal = entry['journal'] as String? ?? '';
                    final timestamp = entry['timestamp'] as Timestamp?;
                    final recommendation = entry['recommendation'] as String?;
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
                        recommendation: recommendation,
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

  // CARD DENGAN REKOMENDASI + LOADING + TAP
  Widget _buildMoodCard({
    required String emoji,
    required String moodText,
    required String description,
    required String date,
    required Color borderColor,
    String? recommendation,
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

            // REKOMENDASI DARI AI
            if (recommendation != null && recommendation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  recommendation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(255, 66, 132, 197),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI sedang menganalisis...',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
