// lib/add_entry_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart'; // Import result
import 'package:speech_to_text/speech_to_text.dart'; // Import utama

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key});

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final TextEditingController _journalController = TextEditingController();
  String? _selectedMood;
  bool _isLoading = false;

  // Variabel Speech-to-Text (mengikuti contohmu)
  final SpeechToText _speechToText = SpeechToText(); // Instance STT
  bool _speechEnabled = false; // Status inisialisasi
  String _localeId = 'id_ID'; // Default ke Bahasa Indonesia
  String _textBeforeListening = ''; // Untuk menyimpan teks sebelum mulai listen

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
    _initSpeech(); // Panggil inisialisasi STT
  }

  @override
  void dispose() {
    _journalController.dispose();
    _speechToText.stop(); // Pastikan berhenti saat dispose
    super.dispose();
  }

  /// Inisialisasi plugin speech_to_text
  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        // Tambahkan onError dan onStatus untuk debugging jika perlu
        onError: (errorNotification) =>
            print('STT onError: $errorNotification'),
        onStatus: (status) => print('STT onStatus: $status'),
      );

      // Logika tambahan untuk memastikan bahasa Indonesia tersedia (opsional)
      if (_speechEnabled) {
        var locales = await _speechToText.locales();
        var indonesianLocale = locales.firstWhere(
          (locale) => locale.localeId == 'id_ID',
          orElse: () =>
              locales.first, // Fallback ke locale pertama jika id_ID tidak ada
        );
        _localeId = indonesianLocale.localeId;
        print("Using locale: $_localeId");
      } else {
        print("Speech recognition not available");
        // Mungkin tampilkan pesan ke user bahwa fitur tidak tersedia
      }
    } catch (e) {
      print("Error initializing speech recognition: $e");
      _speechEnabled = false; // Set ke false jika init gagal
    }

    // Pastikan UI diupdate setelah inisialisasi (terutama jika async)
    if (mounted) {
      setState(() {});
    }
  }

  /// Memulai sesi rekaman suara
  void _startListening() async {
    if (!_speechEnabled) {
      print("Speech recognition not initialized or available.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur suara tidak tersedia saat ini.')),
      );
      return;
    }
    _textBeforeListening =
        _journalController.text; // Simpan teks yang sudah ada
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: _localeId,
      // Opsi tambahan dari contohmu (sesuaikan jika perlu)
      pauseFor: const Duration(
        seconds: 5,
      ), // Jeda otomatis setelah 5 detik hening
      listenFor: const Duration(minutes: 1), // Batas maksimal rekaman
      listenMode: ListenMode.confirmation, // Mode dengar
    );
    // Update UI untuk menunjukkan sedang mendengarkan
    if (mounted) setState(() {});
  }

  /// Menghentikan sesi rekaman suara secara manual
  void _stopListening() async {
    await _speechToText.stop();
    // Update UI untuk menunjukkan sudah berhenti
    if (mounted) setState(() {});
  }

  /// Callback yang dipanggil saat ada hasil dari rekaman suara
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      // Gabungkan teks sebelumnya dengan hasil baru
      // Tambahkan spasi hanya jika teks sebelumnya tidak kosong dan tidak diakhiri spasi
      final separator =
          _textBeforeListening.isEmpty || _textBeforeListening.endsWith(' ')
          ? ''
          : ' ';
      String recognized = result.recognizedWords;

      // Update controller dan posisi kursor
      _journalController.text = _textBeforeListening + separator + recognized;
      _journalController.selection = TextSelection.fromPosition(
        TextPosition(offset: _journalController.text.length),
      );

      // Jika hasil sudah final, update _textBeforeListening agar rekaman berikutnya
      // menambahkan teks baru, bukan mengganti dari awal lagi
      if (result.finalResult) {
        _textBeforeListening = _journalController.text;
      }
    });
  }

  // --- Fungsi Simpan Entri (Tetap Sama) ---
  Future<void> _saveEntry() async {
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

    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance.collection('mood_entries').add({
        'userId': user.uid,
        'mood': _selectedMood!,
        'journal': _journalController.text.trim(),
        'timestamp': Timestamp.now(),
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan entri: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- Akhir Fungsi Simpan Entri ---

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3B82F6);
    final String todayDate = DateFormat(
      'EEEE, d MMM yyyy',
      'id_ID',
    ).format(DateTime.now());
    const Color lightOutlineColor = Color(0xFFE0E0E0); // Warna border
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
              Text(
                todayDate, // Tampilkan tanggal hari ini
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Bagaimana perasaanmu hari ini?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Pilihan Mood (Emoji)
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 10.0,
                runSpacing: 10.0,
                children: _moods.map((mood) {
                  final bool isSelected = _selectedMood == mood['text'];
                  return GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedMood = mood['text'];
                            });
                          },
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

              // Jurnal Title (tanpa Row sekarang, mic ada di TextField)
              const Text(
                'Ceritakan sedikit tentang harimu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              // Jurnal TextField dengan Suffix Icon Mic
              TextField(
                controller: _journalController,
                enabled: !_isLoading,
                maxLines: 5, // Beberapa baris
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
                  // Tambahkan Suffix Icon
                  suffixIcon: IconButton(
                    // Gunakan state dari _speechToText
                    icon: Icon(
                      _speechToText.isListening ? Icons.mic : Icons.mic_none,
                    ),
                    color: _speechToText.isListening
                        ? Colors.red
                        : primaryBlue, // Warna berubah
                    tooltip: 'Tekan untuk bicara',
                    // Logika onPressed dari contohmu
                    onPressed: _speechEnabled && !_isLoading
                        ? (_speechToText.isListening
                              ? _stopListening
                              : _startListening)
                        : null, // Nonaktifkan jika STT tidak enable atau sedang loading simpan
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Tombol Simpan
              SizedBox(
                // Bungkus dengan SizedBox agar bisa atur lebar
                width: double.infinity, // Lebar penuh
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14.0,
                    ), // Sesuaikan tinggi tombol
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
