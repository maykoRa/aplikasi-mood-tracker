// lib/update_entry_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// --- PERUBAHAN: Import STT ---
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

  // --- Variabel State STT ---
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _localeId = 'id_ID';
  String _textBeforeListening = '';

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
    _initSpeech(); // Panggil init STT
  }

  @override
  void dispose() {
    _journalController.dispose();
    _speechToText.stop(); // Hentikan STT
    super.dispose();
  }

  // --- Fungsi-fungsi STT (Copy dari add_entry_page) ---
  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (errorNotification) =>
            print('STT onError: $errorNotification'),
        onStatus: (status) => print('STT onStatus: $status'),
      );
      if (_speechEnabled) {
        var locales = await _speechToText.locales();
        var indonesianLocale = locales.firstWhere(
          (locale) => locale.localeId == 'id_ID',
          orElse: () => locales.first,
        );
        _localeId = indonesianLocale.localeId;
        print("Using locale: $_localeId");
      } else {
        print("Speech recognition not available");
      }
    } catch (e) {
      print("Error initializing speech recognition: $e");
      _speechEnabled = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur suara tidak tersedia saat ini.')),
      );
      return;
    }
    _textBeforeListening = _journalController.text;
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _localeId,
      listenFor: const Duration(minutes: 1),
      listenMode: ListenMode.confirmation,
    );
    if (mounted) setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    if (mounted) setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      final separator =
          _textBeforeListening.isEmpty || _textBeforeListening.endsWith(' ')
          ? ''
          : ' ';
      String recognized = result.recognizedWords;
      _journalController.text = _textBeforeListening + separator + recognized;
      _journalController.selection = TextSelection.fromPosition(
        TextPosition(offset: _journalController.text.length),
      );
      if (result.finalResult) {
        _textBeforeListening = _journalController.text;
      }
    });
  }
  // --- Akhir Fungsi STT ---

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
    setState(() => _isLoading = true);

    try {
      final newJournal = _journalController.text.trim();
      final mustRegenerateReflection = newJournal != widget.currentJournal;

      final Map<String, dynamic> updateData = {
        'mood': _selectedMood,
        'journal': newJournal,
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
      };

      if (mustRegenerateReflection) {
        updateData['reflection'] = null;
      }

      await FirebaseFirestore.instance
          .collection('mood_entries')
          .doc(widget.entryId)
          .update(updateData);

      if (mounted) {
        String successMessage = mustRegenerateReflection
            ? 'Entri berhasil diperbarui! Refleksi AI baru sedang dibuat.'
            : 'Entri berhasil diperbarui.';
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
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayDateTime,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                      padding: const EdgeInsets.all(8),
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
                        style: const TextStyle(fontSize: 28),
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _speechToText.isListening ? Icons.mic : Icons.mic_none,
                    ),
                    color: _speechToText.isListening ? Colors.red : primaryBlue,
                    tooltip: 'Tekan untuk bicara',
                    onPressed: _speechEnabled && !_isLoading
                        ? (_speechToText.isListening
                              ? _stopListening
                              : _startListening)
                        : null,
                  ),
                ),
              ),

              // Indikator "Pill" STT
              if (_speechToText.isListening)
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 8.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Mic aktif – sedang mendengarkan...',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: _speechToText.isListening ? 10 : 30),

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
                      // --- PERBAIKAN FONT: Menambahkan fontFamily ---
                      fontFamily: 'Poppins',
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
