// lib/add_entry_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'home_page.dart';

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key});
  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final TextEditingController _journalController = TextEditingController();
  String? _selectedMood;
  bool _isLoading = false;
  DateTime _selectedDateTime = DateTime.now();
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
    _initSpeech();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _speechToText.stop();
    super.dispose();
  }

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

  // MODIFIKASI: FUNGSI INI AKAN MENUNGGU REFLEKSI DARI CLOUD FUNCTION
  Future<void> _saveEntry() async {
    // Validasi (tidak berubah)
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih mood Anda hari ini'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User tidak ditemukan, silakan login ulang'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedDateTime.isAfter(DateTime.now())) {
      setState(() => _selectedDateTime = DateTime.now());
    }

    setState(() => _isLoading = true);

    try {
      // 1. Simpan entri dan Dapatkan Reference dokumen
      final newEntryRef = await FirebaseFirestore.instance
          .collection('mood_entries')
          .add({
            'userId': user.uid,
            'mood': _selectedMood!,
            'journal': _journalController.text.trim(),
            'timestamp': Timestamp.fromDate(_selectedDateTime),
            'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
            'reflection': null, // Inisialisasi field untuk dipantau
          });

      // 2. TUNGGU Refleksi AI terisi dengan timeout 30 detik
      String aiReflection =
          'Maaf, refleksi AI memakan waktu terlalu lama (>30 detik). Silakan cek detail entri Anda nanti.';
      const timeoutDuration = Duration(seconds: 30);

      try {
        final reflectionSnapshot = await Future.any([
          // Tunggu hingga field 'reflection' terisi
          newEntryRef.snapshots().firstWhere((doc) {
            final data = doc.data();
            return data != null &&
                data.containsKey('reflection') &&
                data['reflection'] != null;
          }),
          // Timeout
          Future.delayed(timeoutDuration).then((_) => null),
        ]);

        if (reflectionSnapshot != null) {
          aiReflection = reflectionSnapshot.data()!['reflection'] as String;
          // Pesan khusus jika AI gagal (Error/Maaf)
          if (aiReflection.startsWith('Error:') ||
              aiReflection.startsWith('Maaf,')) {
            aiReflection =
                'Entri berhasil disimpan, namun: \n\n**' + aiReflection + '**';
          }
        }
      } catch (e) {
        print('Error waiting for reflection: $e');
        aiReflection =
            'Entri berhasil disimpan. Gagal memuat refleksi secara langsung.';
      }

      // 3. Navigasi ke HomePage dan kirim HASIL refleksi
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            // Mengirim HASIL refleksi AI
            builder: (context) => HomePage(newReflection: aiReflection),
          ),
          (route) => false, // Hapus semua rute di bawahnya
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
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
    // ... (widget build tetap sama)
    const Color primaryBlue = Color(0xFF3B82F6);
    final String displayDateTime = DateFormat(
      'EEEE, d MMM yyyy HH:mm',
      'id_ID',
    ).format(_selectedDateTime);
    const Color lightOutlineColor = Color(0xFFE0E0E0);
    const Color hintTextColor = Colors.grey;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entri Baru'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _isLoading ? Colors.grey : Colors.black,
          ),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
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
                'Bagaimana perasaanmu hari ini?',
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
                        : () => setState(() => _selectedMood = mood['text']),
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
                'Ceritakan sedikit tentang harimu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              // Jurnal + Mic
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
              const SizedBox(height: 30),
              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEntry,
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
                      : const Text('Simpan Entri'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
