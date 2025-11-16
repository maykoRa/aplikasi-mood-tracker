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

    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
    final callable = functions.httpsCallable('getDailyReflection');

    final result = await callable.call(<String, dynamic>{
      'date': dateString,
    });

    return DailyReflection.fromJson(result.data as Map<String, dynamic>);
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'not-found') {
      throw Exception('Fungsi getDailyReflection tidak ditemukan. Cek nama & region.');
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
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

  Widget _buildMotivationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF14B8A6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Motivasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14B8A6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _reflectionData?.motivation ?? 'Memuat motivasi...',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _reflectionData?.summary ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rangkuman Kegiatanmu hari ini:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (summary.isEmpty)
            const Text(
              'Belum ada entri jurnal pada tanggal ini.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            )
          else
            ...summary.asMap().entries.map((entry) {
              int index = entry.key + 1;
              String text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index. ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refleksi'),
        backgroundColor: const Color(0xFF3B82F6),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF3B82F6)),
                      SizedBox(height: 16),
                      Text(
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
              Column(
                children: [
                  _buildMotivationCard(),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                ],
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}