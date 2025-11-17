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
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: Colors.red,
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Entri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteEntry(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mood_entries')
            .doc(widget.entryId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Entri tidak ditemukan.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final mood = data['mood'] ?? 'Tidak diketahui';
          final journal = data['journal'] ?? '';
          final timestamp = (data['timestamp'] as Timestamp).toDate();

          // PERBAIKAN: Reflection lebih aman
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

          // PERBAIKAN: Hanya edit jika hari ini
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat(
                        'EEEE, d MMM yyyy HH:mm',
                        'id_ID',
                      ).format(timestamp),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    // TOMBOL EDIT HANYA UNTUK HARI INI
                    if (isToday)
                      TextButton.icon(
                        onPressed: () =>
                            _editEntry(context, mood, journal, timestamp),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Mood: $mood',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: moodColor,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Jurnal:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(journal, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 30),
                const Text(
                  'Refleksi Diri:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: moodColor.withOpacity(0.4)),
                  ),
                  child: isGenerating
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
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
                            const Text(
                              'AI sedang membuat refleksi...',
                              style: TextStyle(fontSize: 15),
                            ),
                          ],
                        )
                      : Text(
                          reflection,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                ),
                const SizedBox(height: 20),
                if (isGenerating)
                  const Text(
                    'Refleksi akan muncul otomatis setelah AI selesai.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
