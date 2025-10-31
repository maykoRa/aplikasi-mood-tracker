import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EntryDetailPage extends StatelessWidget {
  final String entryId;
  const EntryDetailPage({super.key, required this.entryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Entri')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('mood_entries')
            .doc(entryId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final mood = data['mood'] ?? '';
          final journal = data['journal'] ?? '';
          final timestamp = (data['timestamp'] as Timestamp).toDate();
          final recommendation = data['recommendation'] ?? 'Menghasilkan rekomendasi...';
          final isGenerating = !data.containsKey('recommendation') || data['recommendation'] == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM yyyy HH:mm', 'id_ID').format(timestamp),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Text('Mood: $mood', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text('Jurnal:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(journal, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 30),
                const Text('Rekomendasi AI:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: isGenerating
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('AI sedang menganalisis...', style: TextStyle(fontSize: 15)),
                          ],
                        )
                      : Text(
                          recommendation,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                ),
                const SizedBox(height: 20),
                if (isGenerating)
                  const Text(
                    'Tunggu sebentar, rekomendasi akan muncul otomatis.',
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