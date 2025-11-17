import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyReflection {
  final List<String> summary;
  final String motivation;

  DailyReflection({required this.summary, required this.motivation});

  factory DailyReflection.fromJson(Map<String, dynamic> json) {
    return DailyReflection(
      summary: List<String>.from(json['summary'] ?? []),
      motivation: json['motivation'] ?? 'Teruslah semangat!',
    );
  }
}

class ReflectionPage extends StatefulWidget {
  const ReflectionPage({super.key});

  @override
  State<ReflectionPage> createState() => _ReflectionPageState();
}

class _ReflectionPageState extends State<ReflectionPage> {
  DailyReflection? _reflectionData;
  bool _isLoading = true;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  final Color _themeColor = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';
    _fetchDailyReflection(_selectedDate);
  }

  Future<DailyReflection> _callGetDailyReflection(String dateString) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Login diperlukan untuk melihat refleksi.');
      }

      final functions = FirebaseFunctions.instanceFor(
        region: 'asia-southeast2',
      );
      final callable = functions.httpsCallable('getDailyReflection');

      final result = await callable.call(<String, dynamic>{'date': dateString});

      return DailyReflection.fromJson(result.data as Map<String, dynamic>);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw Exception(
          'Fungsi getDailyReflection tidak ditemukan. Cek nama & region.',
        );
      }
      throw Exception('AI Error: ${e.message}');
    } catch (e) {
      throw Exception('Koneksi gagal: $e');
    }
  }

  void _fetchDailyReflection(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);

    setState(() {
      _isLoading = true;
      _error = null;
      _reflectionData = null;
      _selectedDate = dateOnly;
    });

    try {
      final dateString = DateFormat('yyyy-MM-dd').format(dateOnly);
      final data = await _callGetDailyReflection(dateString);
      setState(() {
        _reflectionData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _themeColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      _fetchDailyReflection(picked);
    }
  }

  // --- WIDGET YANG DIPERBARUI ---
  // --- Kartu ini sekarang di-highlight dengan warna tema ---

  Widget _buildMotivationCard() {
    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      // --- PERUBAHAN: Latar belakang kartu diubah jadi warna tema ---
      color: _themeColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          // --- PERUBAHAN: Dibuat crossAxisAlignment.center agar teks motivasi
          // --- yang di-align center terlihat pas
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              // --- PERUBAHAN: MainAxisAlignment.center agar ikon & judul di tengah ---
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  // --- PERUBAHAN: Warna ikon jadi putih ---
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Motivasi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    // --- PERUBAHAN: Warna teks jadi putih ---
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _reflectionData?.motivation ?? 'Memuat motivasi...',
              style: TextStyle(
                fontSize: 16,
                // --- PERUBAHAN: Warna teks jadi putih (sedikit transparan) ---
                color: Colors.white.withOpacity(0.9),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              // --- PERUBAHAN: Sesuai permintaan Anda ---
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET INI TETAP (KARTU PUTIH) ---
  // --- Ini menciptakan kontras yang bagus dengan kartu motivasi ---

  Widget _buildSummaryCard() {
    final summary = _reflectionData?.summary ?? [];

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize_outlined, color: _themeColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Rangkuman Kegiatanmu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            if (summary.isEmpty)
              const Text(
                'Belum ada entri jurnal pada tanggal ini.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              )
            else
              ...summary.asMap().entries.map((entry) {
                int index = entry.key + 1;
                String text = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$index. ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _themeColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refleksi'),
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _selectDate(context),
            tooltip: 'Pilih Tanggal Refleksi',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _themeColor,
                ),
              ),
            ),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: _themeColor),
                      const SizedBox(height: 16),
                      const Text(
                        "AI sedang merenung sejenak...",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_isLoading && _reflectionData != null)
              Column(children: [_buildMotivationCard(), _buildSummaryCard()]),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
