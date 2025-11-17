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
  final DateTime _selectedDateTime = DateTime.now(); // Otomatis sekarang
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

  Future<void> _saveEntry() async {
    // Validasi
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

    setState(() => _isLoading = true);

    try {
      // 1. Simpan entri
      final newEntryRef = await FirebaseFirestore.instance
          .collection('mood_entries')
          .add({
            'userId': user.uid,
            'mood': _selectedMood!,
            'journal': _journalController.text.trim(),
            'timestamp': Timestamp.fromDate(_selectedDateTime),
            'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
            'reflection': null,
          });

      // 2. TUNGGU Refleksi AI (timeout 30 detik)
      String aiReflection =
          'Maaf, refleksi AI memakan waktu terlalu lama (>30 detik). Silakan cek detail entri Anda nanti.';
      const timeoutDuration = Duration(seconds: 30);

      try {
        final reflectionSnapshot = await Future.any([
          newEntryRef.snapshots().firstWhere((doc) {
            final data = doc.data();
            return data != null &&
                data.containsKey('reflection') &&
                data['reflection'] != null;
          }),
          Future.delayed(timeoutDuration).then((_) => null),
        ]);

        if (reflectionSnapshot != null) {
          aiReflection = reflectionSnapshot.data()!['reflection'] as String;
          if (aiReflection.startsWith('Error:') ||
              aiReflection.startsWith('Maaf,')) {
            aiReflection =
                'Entri berhasil disimpan, namun: \n\n**$aiReflection**';
          }
        }
      } catch (e) {
        print('Error waiting for reflection: $e');
        aiReflection =
            'Entri berhasil disimpan. Gagal memuat refleksi secara langsung.';
      }

      // 3. Navigasi ke HomePage
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(newReflection: aiReflection),
          ),
          (route) => false,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(Icons.access_time, color: Colors.grey, size: 18),
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
                      // --- PERUBAHAN 1: Padding Emoji ---
                      // Mengubah dari 10 menjadi 8
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
                        // --- PERUBAHAN 2: Ukuran Emoji ---
                        // Mengubah dari 32 menjadi 28
                        style: const TextStyle(fontSize: 28),
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

                  // --- PERUBAHAN 3: helperText DIHAPUS ---
                  // helperText: _speechToText.isListening ... (dihapus)
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
                    // --- PERUBAHAN 4: Logika Ikon Dikembalikan ---
                    icon: Icon(
                      _speechToText.isListening ? Icons.mic : Icons.mic_none,
                    ),
                    color: _speechToText.isListening ? Colors.red : primaryBlue,
                    // --- Akhir Perubahan 4 ---
                    tooltip: 'Tekan untuk bicara',
                    onPressed: _speechEnabled && !_isLoading
                        ? (_speechToText.isListening
                              ? _stopListening
                              : _startListening)
                        : null,
                  ),
                ),
              ),

              // --- PERUBAHAN 5: Indikator "Pill" yang Lebih Jelas ---
              // Mengganti Padding lama dengan Container "Chip"
              if (_speechToText.isListening)
                Container(
                  // Mengatur agar rata tengah
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 8.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50], // Latar belakang merah muda
                    borderRadius: BorderRadius.circular(20), // Rounded
                    border: Border.all(color: Colors.red[100]!), // Border tipis
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Agar container tidak full
                    children: [
                      const Icon(
                        Icons.mic, // Ikon mic di dalam chip
                        color: Colors.red,
                        size: 16,
                      ),
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
              // --- Akhir Perubahan 5 ---

              // Menyesuaikan space
              SizedBox(height: _speechToText.isListening ? 10 : 30),

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
