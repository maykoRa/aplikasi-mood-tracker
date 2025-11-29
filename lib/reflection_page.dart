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

  // Warna Tema
  final Color _primaryBlue = const Color(0xFF3B82F6);
  final Color _lightBlueBg = const Color(0xFFEFF6FF);

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

  // --- POP UP DATE PICKER MODERN ---
  void _selectDate(BuildContext context) async {
    DateTime tempPickedDate = _selectedDate;

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Header Pop Up
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _lightBlueBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: _primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Pilih Tanggal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. Preview Tanggal
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(tempPickedDate),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. Kalender
                    Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: ColorScheme.light(
                          primary: _primaryBlue,
                          onPrimary: Colors.white,
                          onSurface: Colors.black87,
                        ),
                        textTheme: const TextTheme(
                          bodyMedium: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: tempPickedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                        onDateChanged: (newDate) {
                          setStateDialog(() {
                            tempPickedDate = newDate;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 4. Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(context, tempPickedDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Pilih',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      _fetchDailyReflection(picked);
    }
  }

  // --- WIDGET DATE SELECTOR ---
  Widget _buildDateSelector() {
    String formattedDate = DateFormat(
      'EEEE, dd MMMM yyyy',
    ).format(_selectedDate);

    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _lightBlueBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: _primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refleksi Tanggal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_circle_outlined,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET MOTIVASI ---
  Widget _buildMotivationCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryBlue, const Color(0xFF60A5FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.format_quote_rounded,
              size: 140,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lightbulb,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Insight Hari Ini',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _reflectionData?.motivation ?? 'Memuat motivasi...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET SUMMARY ---
  Widget _buildSummaryCard() {
    final summary = _reflectionData?.summary ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize_outlined, color: _primaryBlue, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Rangkuman Kegiatan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (summary.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Belum ada entri jurnal pada tanggal ini.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: summary.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                itemBuilder: (ctx, i) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _lightBlueBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: _primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          summary[i],
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Refleksi Harian'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        // --- TOMBOL KEMBALI HITAM & TEGAS ---
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
          ), // Panah standar yang lebih tegas
          color: Colors.black, // Warna hitam sesuai permintaan
          iconSize: 24, // Ukuran proporsional dengan judul
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        child: Column(
          children: [
            _buildDateSelector(),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: _primaryBlue),
                      const SizedBox(height: 16),
                      Text(
                        "Sedang menganalisis harimu...",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red[300],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _fetchDailyReflection(_selectedDate),
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Coba Lagi',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isLoading && _reflectionData != null && _error == null)
              Column(children: [_buildMotivationCard(), _buildSummaryCard()]),
          ],
        ),
      ),
    );
  }
}
