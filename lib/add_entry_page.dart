// lib/add_entry_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'home_page.dart';

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key});

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  final TextEditingController _journalController = TextEditingController();

  bool _isLoading = false;
  final DateTime _selectedDateTime = DateTime.now();

  // Speech to Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _localeId = 'id_ID';

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
          _journalController.text = result.recognizedWords;
          _journalController.selection = TextSelection.fromPosition(
            TextPosition(offset: _journalController.text.length),
          );
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

  // ===================== SIMPAN ENTRY + TUNGGU REFLEKSI =====================
  Future<void> _saveEntry() async {
    final journal = _journalController.text.trim();
    if (journal.isEmpty || journal.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ceritakan lebih banyak yuk')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User tidak ditemukan')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Simpan entri dengan placeholder
      final docRef = await FirebaseFirestore.instance.collection('mood_entries').add({
        'userId': user.uid,
        'mood': 'Menunggu AI...',
        'journal': journal,
        'timestamp': Timestamp.fromDate(_selectedDateTime),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDateTime),
        'reflection': null,
      });

      // 2. Tunggu refleksi AI (maks 30 detik)
      String reflection = "Entri berhasil disimpan!\nRefleksi AI akan muncul sebentar lagi.";

      try {
        final snapshot = await docRef.snapshots().skipWhile((doc) {
          final data = doc.data();
          final refl = data?['reflection'] as String?;
          return refl == null || refl.trim().isEmpty;
        }).first.timeout(const Duration(seconds: 30));

        reflection = snapshot.get('reflection') as String;
      } on TimeoutException catch (_) {
        // Timeout → tetap lanjut
      } catch (e) {
        debugPrint('Error waiting for reflection: $e');
      }

      // 3. Navigasi ke Home
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(newReflection: reflection)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
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
        title: const Text('Entri Baru'),
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
              const SizedBox(height: 25),

              const Text(
                'Bagaimana perasaanmu hari ini?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 25),

              // Info: AI akan tentukan mood otomatis
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      "AI akan otomatis menentukan moodmu\nsetelah kamu simpan",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Berdasarkan isi jurnalmu",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                'Ceritakan sedikit tentang harimu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Text field + mic
              TextField(
                controller: _journalController,
                enabled: !_isLoading,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: 'Tulis atau bicara di sini...',
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
                      Text(
                        'Sedang mendengarkan...',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Simpan Entri',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}