// lib/update_entry_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

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
  late DateTime _selectedDateTime;
  bool _isLoading = false;

  // Speech to Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _localeId = 'id_ID';

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: widget.currentJournal);
    _selectedDateTime = widget.currentTimestamp;
    _initSpeech();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  // ===================== SPEECH TO TEXT =====================
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (_speechEnabled) {
      final locales = await _speechToText.locales();
      final indo = locales.firstWhere(
        (l) => l.localeId.contains('id'),
        orElse: () => locales.first,
      );
      _localeId = indo.localeId;
    }
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled || _isLoading) return;

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() {
            _journalController.text = result.recognizedWords;
            _journalController.selection = TextSelection.fromPosition(
              TextPosition(offset: _journalController.text.length),
            );
          });
        }
      },
      localeId: _localeId,
      listenFor: const Duration(minutes: 1),
    );
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  // ===================== DATE & TIME PICKER =====================
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      final newDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
      if (newDate.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa memilih tanggal di masa depan')),
        );
      } else {
        setState(() => _selectedDateTime = newDate);
      }
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      final newTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        picked.hour,
        picked.minute,
      );
      if (newTime.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa memilih waktu di masa depan')),
        );
      } else {
        setState(() => _selectedDateTime = newTime);
      }
    }
  }

  // ===================== UPDATE ENTRY =====================
  Future<void> _updateEntry() async {
    final newJournal = _journalController.text.trim();
    if (newJournal.isEmpty || newJournal.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jurnal tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bool journalChanged = newJournal != widget.currentJournal.trim();

      final Map<String, dynamic> updateData = {
        'journal': newJournal,
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
      };

      // Jika jurnal diubah → AI harus generate mood & refleksi ulang
      if (journalChanged) {
        updateData['mood'] = 'Menunggu AI...';
        updateData['reflection'] = null;
      }

      await FirebaseFirestore.instance
          .collection('mood_entries')
          .doc(widget.entryId)
          .update(updateData);

      if (mounted) {
        final message = journalChanged
            ? 'Entri diperbarui! AI sedang menganalisis mood & refleksi baru...'
            : 'Entri berhasil diperbarui.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        Navigator.pop(context, true); // true = berhasil update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    final String displayDateTime = DateFormat('EEEE, d MMM yyyy HH:mm', 'id_ID').format(_selectedDateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Entri'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _isLoading ? Colors.grey : Colors.black),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tanggal & Waktu
              InkWell(
                onTap: _isLoading ? null : () async {
                  await _selectDate(context);
                  if (mounted) await _selectTime(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.grey, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          displayDateTime,
                          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Icon(Icons.edit_calendar_outlined, color: Colors.grey, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              const Text('Bagaimana perasaanmu hari ini?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),

              // Info: AI yang menentukan mood
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "AI akan otomatis menentukan moodmu\njika kamu mengubah jurnal",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.currentMood == 'Menunggu AI...' ? 'Sedang dianalisis...' : 'Mood saat ini: ${widget.currentMood}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              const Text('Ceritakan ulang tentang harimu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // Text field + mic
              TextField(
                controller: _journalController,
                enabled: !_isLoading,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: 'Edit jurnalmu di sini...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: primaryBlue, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _speechToText.isListening ? Icons.mic : Icons.mic_none,
                      color: _speechToText.isListening ? Colors.red : primaryBlue,
                    ),
                    onPressed: _speechEnabled && !_isLoading
                        ? (_speechToText.isListening ? _stopListening : _startListening)
                        : null,
                  ),
                ),
              ),

              // Indikator mic aktif
              if (_speechToText.isListening)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Sedang mendengarkan...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Simpan Perubahan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}