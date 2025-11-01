// lib/update_entry_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UpdateEntryPage extends StatefulWidget {
  final String entryId;
  final String currentMood;
  final String currentJournal;
  final DateTime currentTimestamp;

  const UpdateEntryPage({
    super.key,
    required this.entryId,
    required this.currentMood,
    required this.currentJournal,
    required this.currentTimestamp,
  });

  @override
  State<UpdateEntryPage> createState() => _UpdateEntryPageState();
}

class _UpdateEntryPageState extends State<UpdateEntryPage> {
  late TextEditingController _journalController;
  late String _selectedMood;
  late DateTime _selectedDateTime;
  bool _isLoading = false;

  final List<Map<String, String>> _moods = [
    {'emoji': '😄', 'text': 'Sangat Baik'},
    {'emoji': '😊', 'text': 'Baik'},
    {'emoji': '😐', 'text': 'Biasa Saja'},
    {'emoji': '😟', 'text': 'Buruk'},
    {'emoji': '😠', 'text': 'Sangat Buruk'},
  ];

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: widget.currentJournal);
    _selectedMood = widget.currentMood;
    _selectedDateTime = widget.currentTimestamp;
  }

  @override
  void dispose() {
    _journalController.dispose();
    super.dispose();
  }

  // Pilih Tanggal (Sama seperti AddEntryPage)
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && picked != _selectedDateTime) {
      final newDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
      if (newDateTime.isAfter(DateTime.now())) {
        setState(() => _selectedDateTime = DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa memilih waktu di masa depan.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        setState(() => _selectedDateTime = newDateTime);
      }
    }
  }

  // Pilih Waktu (Sama seperti AddEntryPage)
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      final newDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
      if (newDateTime.isAfter(DateTime.now())) {
        setState(() => _selectedDateTime = DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa memilih waktu di masa depan.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        setState(() => _selectedDateTime = newDateTime);
      }
    }
  }

  Future<void> _updateEntry() async {
    // --- PERBAIKAN: Kondisi if (_selectedMood == null) dihapus karena _selectedMood
    //              dijamin non-nullable (String) setelah initState. ---

    setState(() => _isLoading = true);

    try {
      final newJournal = _journalController.text.trim();
      final mustRegenerateReflection = newJournal != widget.currentJournal;

      // Perbaikan dari error sebelumnya: Deklarasi eksplisit Map<String, dynamic>
      final Map<String, dynamic> updateData = {
        'mood': _selectedMood,
        'journal': newJournal,
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
      };

      // Jika jurnal berubah, set 'reflection' menjadi null untuk memicu Cloud Function
      if (mustRegenerateReflection) {
        updateData['reflection'] = null;
      }

      // Update entri di Firestore
      await FirebaseFirestore.instance
          .collection('mood_entries')
          .doc(widget.entryId)
          .update(updateData);

      if (mounted) {
        String successMessage = mustRegenerateReflection
            ? 'Entri berhasil diperbarui! Refleksi AI baru sedang dibuat.'
            : 'Entri berhasil diperbarui.';

        // Kembali ke halaman detail
        Navigator.pop(context, successMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    final String displayDateTime = DateFormat(
      'EEEE, d MMM yyyy HH:mm',
      'id_ID',
    ).format(_selectedDateTime);
    const Color lightOutlineColor = Color(0xFFE0E0E0);
    const Color hintTextColor = Colors.grey;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Entri')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tanggal & Waktu
              InkWell(
                onTap: _isLoading
                    ? null
                    : () async {
                        await _selectDate(context);
                        if (mounted) await _selectTime(context);
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayDateTime,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Bagaimana perasaanmu?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Pilihan Mood
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 10.0,
                runSpacing: 10.0,
                children: _moods.map((mood) {
                  final bool isSelected = _selectedMood == mood['text'];
                  return GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => setState(() => _selectedMood = mood['text']!),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryBlue.withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primaryBlue
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        mood['emoji']!,
                        style: const TextStyle(fontSize: 35),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              const Text(
                'Jurnal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              // Jurnal
              TextField(
                controller: _journalController,
                enabled: !_isLoading,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Tulis ceritamu di sini...',
                  hintStyle: const TextStyle(color: hintTextColor),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 20.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: const BorderSide(
                      color: lightOutlineColor,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: const BorderSide(
                      color: lightOutlineColor,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: const BorderSide(
                      color: primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Tombol Simpan Perubahan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
