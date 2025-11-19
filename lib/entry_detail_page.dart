// lib/entry_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'update_entry_page.dart';

class EntryDetailPage extends StatefulWidget {
  final String entryId;
  const EntryDetailPage({super.key, required this.entryId});

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  // Palet Warna Utama Aplikasi
  final Color primaryBlue = const Color(0xFF3B82F6);
  final Color lightBlueOutline = const Color(0xFFDBEAFE);

  // Helper Warna Mood
  Color _getMoodColor(String mood) {
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
        return '❓';
    }
  }

  Future<void> _deleteEntry(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus entri ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('mood_entries')
            .doc(widget.entryId)
            .delete();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  const HomePage(newReflection: 'Entri berhasil dihapus.'),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _editEntry(
    BuildContext context,
    String mood,
    String journal,
    DateTime timestamp,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdateEntryPage(
          entryId: widget.entryId,
          currentMood: mood,
          currentJournal: journal,
          currentTimestamp: timestamp,
        ),
      ),
    );

    if (result is String && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mood_entries')
          .doc(widget.entryId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Entri tidak ditemukan.')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final mood = data['mood'] ?? 'Tidak diketahui';
        final journal = data['journal'] ?? '';
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final reflectionRaw = data['reflection'];
        final reflection =
            (reflectionRaw is String && reflectionRaw.trim().isNotEmpty)
            ? reflectionRaw
            : 'AI sedang membuat refleksi...';
        final isGenerating =
            reflectionRaw == null ||
            reflectionRaw is! String ||
            (reflectionRaw).trim().isEmpty;

        final moodColor = _getMoodColor(mood);

        final today = DateTime.now();
        final entryDate = DateTime(
          timestamp.year,
          timestamp.month,
          timestamp.day,
        );
        final isToday =
            entryDate.year == today.year &&
            entryDate.month == today.month &&
            entryDate.day == today.day;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Detail Entri',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isToday)
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: primaryBlue),
                  onPressed: () =>
                      _editEntry(context, mood, journal, timestamp),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteEntry(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === DATE HEADER ===
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat(
                        'EEEE, d MMMM yyyy • HH:mm',
                        'id_ID',
                      ).format(timestamp),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // === MOOD HERO (Emoji Besar) ===
                Center(
                  child: Column(
                    children: [
                      Text(
                        _getEmoji(mood),
                        style: const TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        mood,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: moodColor, // Warna Mood
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // === SECTION 1: CERITAMU (Nuansa Biru Aplikasi) ===
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: primaryBlue, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Ceritamu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue, // Konsisten tema biru
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    // Border biru tipis (tema aplikasi)
                    border: Border.all(color: lightBlueOutline, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    journal.isNotEmpty ? journal : 'Tidak ada catatan cerita.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // === SECTION 2: PESAN UNTUKMU (Nuansa Mood & Ikon Baru) ===
                if (reflectionRaw != null) ...[
                  Row(
                    children: [
                      // Ikon baru: Lampu Ide / Insight
                      Icon(
                        Icons.tips_and_updates_rounded,
                        color: moodColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pesan Untukmu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: moodColor, // Mengikuti warna mood
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      // Background soft mengikuti warna mood
                      color: moodColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      // Border mengikuti warna mood
                      border: Border.all(
                        color: moodColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: isGenerating
                        ? Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: moodColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Menganalisis perasaanmu...',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          )
                        : Text(
                            reflection,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors
                                  .black87, // Teks hitam agar terbaca jelas
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}
