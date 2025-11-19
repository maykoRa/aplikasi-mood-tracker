// lib/history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'entry_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<DocumentSnapshot>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Format tanggal untuk key (hanya tanggal, tanpa waktu)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Ambil entri dari Firestore
  Stream<QuerySnapshot> _getEntriesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('mood_entries')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    // Warna tema (konsisten dengan halaman lain)
    const Color primaryBlue = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'History Jurnal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getEntriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Jika data kosong, tetap tampilkan kalender (opsional),
          // atau tampilkan empty state. Di sini kita handle data events.
          final docs = snapshot.data?.docs ?? [];

          _events.clear();
          // Kelompokkan entri per tanggal
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            if (timestamp != null) {
              final dateKey = _normalizeDate(timestamp);
              _events.putIfAbsent(dateKey, () => []);
              _events[dateKey]!.add(doc);
            }
          }

          final selectedEvents = _selectedDay != null
              ? _events[_normalizeDate(_selectedDay!)] ?? []
              : <DocumentSnapshot>[];

          return Column(
            children: [
              // === KALENDER YANG SUDAH DIPERMANTAP ===
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ), // Border halus
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05), // Shadow tipis
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,

                  // --- PENGATURAN UKURAN (Compact) ---
                  rowHeight: 42, // Mengurangi tinggi baris (Standard ~52)
                  daysOfWeekHeight: 22, // Header hari lebih kecil

                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() => _calendarFormat = format);
                    }
                  },
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                  eventLoader: (day) {
                    final normalized = _normalizeDate(day);
                    return _events.containsKey(normalized) ? [1] : [];
                  },

                  // --- STYLE KALENDER ---
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    defaultTextStyle: const TextStyle(fontSize: 13),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    todayTextStyle: const TextStyle(
                      color: primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),

                    // Style Tanggal Terpilih (Lingkaran Biru Penuh)
                    selectedDecoration: const BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    // Style Hari Ini (Lingkaran Biru Transparan/Soft)
                    todayDecoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    // Penanda ada event (Titik kecil)
                    markerDecoration: const BoxDecoration(
                      color: Color(0xFF10B981), // Hijau soft
                      shape: BoxShape.circle,
                    ),
                    markerSize: 5,
                    cellMargin: const EdgeInsets.all(2), // Jarak antar tanggal
                  ),

                  // --- STYLE HEADER ---
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true, // Tampilkan tombol ganti format
                    formatButtonShowsNext: false,
                    titleCentered: true,
                    titleTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      size: 24,
                      color: primaryBlue,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: primaryBlue,
                    ),
                    headerPadding: const EdgeInsets.symmetric(
                      vertical: 4,
                    ), // Header lebih tipis
                    formatButtonTextStyle: const TextStyle(
                      fontSize: 12,
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      border: Border.all(color: primaryBlue),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),

              // === JUDUL HASIL SELEKSI ===
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedDay != null
                          ? DateFormat(
                              'EEEE, d MMMM yyyy',
                              'id_ID',
                            ).format(_selectedDay!)
                          : "Pilih tanggal",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    // Indikator jumlah entri (Opsional, pemanis)
                    if (selectedEvents.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${selectedEvents.length} Entri",
                          style: const TextStyle(
                            fontSize: 12,
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // === DAFTAR ENTRI (Expanded) ===
              Expanded(
                child: docs.isEmpty
                    ? _buildEmptyState() // Tampilan jika user belum pernah input sama sekali
                    : selectedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tidak ada catatan mood\npada tanggal ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: selectedEvents.length,
                        itemBuilder: (context, index) {
                          final doc = selectedEvents[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final mood =
                              data['mood'] as String? ?? 'Tidak Diketahui';
                          final journal = data['journal'] as String? ?? '';
                          final timestamp = (data['timestamp'] as Timestamp?)
                              ?.toDate();
                          final timeStr = timestamp != null
                              ? DateFormat('HH:mm', 'id_ID').format(
                                  timestamp,
                                ) // Tampilkan Jam
                              : '';

                          return _buildHistoryCard(
                            emoji: _getEmoji(mood),
                            moodText: mood,
                            description: journal.isNotEmpty
                                ? journal
                                : 'Tidak ada catatan.',
                            time: timeStr,
                            borderColor: _getBorderColor(mood),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EntryDetailPage(entryId: doc.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Belum ada riwayat jurnal.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor(String mood) {
    switch (mood) {
      case 'Sangat Baik':
        return const Color(0xFF10B981); // Green
      case 'Baik':
        return const Color(0xFF34D399); // Light Green
      case 'Biasa Saja':
        return const Color(0xFFFBBF24); // Amber/Orange
      case 'Buruk':
        return const Color(0xFFF87171); // Red Light
      case 'Sangat Buruk':
        return const Color(0xFFEF4444); // Red
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
        return '❓';
    }
  }

  Widget _buildHistoryCard({
    required String emoji,
    required String moodText,
    required String description,
    required String time,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          // Mengganti border tebal dengan border kiri (accent) agar lebih rapi
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indikator Warna Mood (Garis vertikal kecil)
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            // Emoji
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),

            // Konten Teks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        moodText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        time, // Menampilkan Jam
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
