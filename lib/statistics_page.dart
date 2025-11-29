import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Model Mood Data ---
class MoodEntry {
  final String mood;
  final DateTime date;

  MoodEntry.fromFirestore(Map<String, dynamic> data)
    : mood = data['mood'] ?? 'Tidak Diketahui',
      date = (data['timestamp'] as Timestamp).toDate();
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MoodEntry> _moodData = [];
  bool _isLoading = true;
  String _currentFilter = '7 Hari Terakhir'; // Filter default

  late List<PieChartSectionData> _pieChartSections;
  int _touchedIndex = -1;

  // Style konstan
  final Color primaryBlue = const Color(0xFF3B82F6);
  final TextStyle headerStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF3B82F6), // primaryBlue
    fontFamily: 'Poppins', // Tambahkan Poppins juga di sub-header
  );

  @override
  void initState() {
    super.initState();
    _fetchMoodData(_currentFilter);
  }

  // Fungsi untuk mendapatkan warna berdasarkan mood
  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Sangat Baik':
        return Colors.green;
      case 'Baik':
        return Colors.lightGreen;
      case 'Biasa Saja':
        return Colors.orange;
      case 'Buruk':
        return Colors.deepOrange;
      case 'Sangat Buruk':
        return Colors.red;
      default:
        return Colors.grey.shade400;
    }
  }

  // Dekorasi Card
  BoxDecoration _cardDecoration(Color borderColor) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15.0),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  // --- Fungsi Mengambil Data dari Firestore ---
  Future<void> _fetchMoodData(String filter) async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    DateTime startDate;
    if (filter == '30 Hari Terakhir') {
      startDate = DateTime.now().subtract(const Duration(days: 30));
    } else {
      startDate = DateTime.now().subtract(const Duration(days: 7));
    }
    startDate = DateTime(startDate.year, startDate.month, startDate.day);
    final startDateTimestamp = Timestamp.fromDate(startDate);

    try {
      final snapshot = await _firestore
          .collection('mood_entries')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isGreaterThanOrEqualTo: startDateTimestamp)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _moodData = snapshot.docs
            .map((doc) => MoodEntry.fromFirestore(doc.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching mood data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil data statistik.')),
        );
      }
    }
  }

  // --- FUNGSI HELPER: Untuk menyingkat label bar chart ---
  String _getShortMoodLabel(String mood) {
    switch (mood) {
      case 'Sangat Baik':
        return 'S. Baik';
      case 'Sangat Buruk':
        return 'S. Buruk';
      case 'Biasa Saja':
        return 'Biasa';
      default:
        return mood; // 'Baik', 'Buruk'
    }
  }

  // --- Fungsi untuk Mengolah Data Grafik Bar ---
  BarChartData _mainBarData() {
    final Map<String, int> moodCounts = _getMoodSummary()['moodCounts'];
    const List<String> moodOrder = [
      'Sangat Buruk',
      'Buruk',
      'Biasa Saja',
      'Baik',
      'Sangat Baik',
    ];
    final List<String> moods = moodCounts.keys
        .toList()
        .where((mood) => moodOrder.contains(mood))
        .toList();
    moods.sort((a, b) => moodOrder.indexOf(a).compareTo(moodOrder.indexOf(b)));

    final List<BarChartGroupData> barGroups = [];
    final int maxCount = moodCounts.values.fold(
      1,
      (max, count) => count > max ? count : max,
    );

    for (int i = 0; i < moods.length; i++) {
      final mood = moods[i];
      final count = moodCounts[mood] ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: _getMoodColor(mood),
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: (maxCount + 1).toDouble(),
                color: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: (maxCount + 1).toDouble(),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              moods[group.x],
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              children: <TextSpan>[
                const TextSpan(text: '\n', style: TextStyle(fontSize: 0)),
                TextSpan(
                  text: rod.toY.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < moods.length) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    _getShortMoodLabel(moods[value.toInt()]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontFamily: 'Poppins',
                    ),
                  ),
                );
              }
              return const Text('');
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: maxCount > 5 ? (maxCount / 5).ceil().toDouble() : 1,
            getTitlesWidget: (value, meta) {
              if (value == 0 || value > maxCount + 0.5) return Container();
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.left,
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 1.0),
          left: BorderSide(color: Colors.grey, width: 1.0),
        ),
      ),
      barGroups: barGroups.isEmpty
          ? [
              BarChartGroupData(
                x: 0,
                barRods: [BarChartRodData(toY: 0.0, color: Colors.transparent)],
              ),
            ]
          : barGroups,
    );
  }

  // --- Fungsi untuk Ringkasan Mood ---
  Map<String, dynamic> _getMoodSummary() {
    final Map<String, int> moodCounts = {};
    for (var entry in _moodData) {
      if (entry.mood != 'Tidak Diketahui') {
        moodCounts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'moodCounts': moodCounts,
      'mostFrequent': sortedMoods.isNotEmpty ? sortedMoods.first : null,
      'leastFrequent': sortedMoods.isNotEmpty ? sortedMoods.last : null,
    };
  }

  // --- Helper untuk Statistik Umum ---
  int _getMoodNumericValue(String mood) {
    switch (mood) {
      case 'Sangat Baik':
        return 5;
      case 'Baik':
        return 4;
      case 'Biasa Saja':
        return 3;
      case 'Buruk':
        return 2;
      case 'Sangat Buruk':
        return 1;
      default:
        return 0;
    }
  }

  String _getAverageMood() {
    if (_moodData.isEmpty) return 'N/A';
    double total = 0;
    int validEntries = 0;
    for (var entry in _moodData) {
      int val = _getMoodNumericValue(entry.mood);
      if (val > 0) {
        total += val;
        validEntries++;
      }
    }
    if (validEntries == 0) return 'N/A';
    double avg = total / validEntries;

    if (avg >= 4.5) return 'Sangat Baik';
    if (avg >= 3.5) return 'Baik';
    if (avg >= 2.5) return 'Biasa Saja';
    if (avg >= 1.5) return 'Buruk';
    return 'Sangat Buruk';
  }

  // --- Helper Widget untuk Statistik Umum ---
  Widget _buildOverallStats() {
    String avgMood = _getAverageMood();
    int totalEntries = _moodData.length;
    Color avgMoodColor = _getMoodColor(avgMood);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Entri',
            totalEntries.toString(),
            Icons.list_alt_rounded,
            Colors.blue.shade600,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Rata-rata Mood',
            avgMood,
            Icons.insights_rounded,
            avgMoodColor,
          ),
        ),
      ],
    );
  }

  // Widget Card Statistik Umum
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: _cardDecoration(iconColor.withOpacity(0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontFamily: 'Poppins',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- Helper Widget untuk Distribusi Pie Chart ---
  Widget _buildPieChartSection(Map<String, int> moodCounts) {
    if (moodCounts.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Tidak ada data distribusi.',
            style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
          ),
        ),
      );
    }

    double total = moodCounts.values.fold(0, (sum, item) => sum + item);

    _pieChartSections = moodCounts.entries.map((entry) {
      final isTouched =
          (moodCounts.keys.toList().indexOf(entry.key) == _touchedIndex);
      final double radius = isTouched ? 60.0 : 50.0;
      final double percentage = (entry.value / total) * 100;

      return PieChartSectionData(
        color: _getMoodColor(entry.key),
        value: entry.value.toDouble(),
        title: (percentage < 10) ? '' : '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Poppins',
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    }).toList();

    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sections: _pieChartSections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  // --- Legenda ---
  Widget _buildLegend(Map<String, int> moodCounts) {
    if (moodCounts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.start,
      children: moodCounts.entries.map((entry) {
        return _buildLegendItem(_getMoodColor(entry.key), entry.key);
      }).toList(),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // --- Widget Card Ringkasan ---
  Widget _buildSummaryCard(
    String title,
    MapEntry<String, int>? entry,
    IconData defaultIcon,
  ) {
    final String mood = entry?.key ?? 'N/A';
    final int count = entry?.value ?? 0;
    final Color color = _getMoodColor(mood);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: _cardDecoration(color),
      child: Row(
        children: [
          Icon(defaultIcon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '$title: $mood (${count}x)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Filter ---
  Widget _buildFilterToggle() {
    final List<bool> isSelected = [
      _currentFilter == '7 Hari Terakhir',
      _currentFilter == '30 Hari Terakhir',
    ];

    return ToggleButtons(
      isSelected: isSelected,
      onPressed: (int index) {
        if (index == 0 && _currentFilter != '7 Hari Terakhir') {
          setState(() {
            _currentFilter = '7 Hari Terakhir';
          });
          _fetchMoodData('7 Hari Terakhir');
        } else if (index == 1 && _currentFilter != '30 Hari Terakhir') {
          setState(() {
            _currentFilter = '30 Hari Terakhir';
          });
          _fetchMoodData('30 Hari Terakhir');
        }
      },
      color: Colors.grey[700],
      selectedColor: primaryBlue,
      fillColor: primaryBlue.withOpacity(0.1),
      selectedBorderColor: primaryBlue,
      borderRadius: BorderRadius.circular(10.0),
      borderColor: Colors.grey.shade300,
      borderWidth: 1.5,
      constraints: const BoxConstraints(minHeight: 40.0),
      children: const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '7 Hari Terakhir',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '30 Hari Terakhir',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _getMoodSummary();
    final mostFrequent = summary['mostFrequent'] as MapEntry<String, int>?;
    final leastFrequent =
        summary.containsKey('moodCounts') &&
            (summary['moodCounts'] as Map).isNotEmpty
        ? summary['leastFrequent'] as MapEntry<String, int>?
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Statistik'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0, // Mencegah perubahan warna saat scroll
        // --- TOMBOL KEMBALI CUSTOM ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.black,
          iconSize: 24,
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins', // Menggunakan font Poppins
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(child: _buildFilterToggle()),
            const SizedBox(height: 25),

            Text('Statistik Umum', style: headerStyle),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildOverallStats(),
            const SizedBox(height: 25),

            Text('Frekuensi Mood', style: headerStyle),
            const SizedBox(height: 15),
            Container(
              decoration: _cardDecoration(Colors.grey.shade200),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: SizedBox(
                height: 300,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _moodData.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada data mood dalam ${_currentFilter.toLowerCase()}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    : BarChart(_mainBarData()),
              ),
            ),
            const SizedBox(height: 25),

            Text('Distribusi Mood', style: headerStyle),
            const SizedBox(height: 15),
            Container(
              decoration: _cardDecoration(Colors.grey.shade200),
              padding: const EdgeInsets.all(16.0),
              child: _isLoading
                  ? const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildPieChartSection(
                            summary['moodCounts'] as Map<String, int>,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 2,
                          child: _buildLegend(
                            summary['moodCounts'] as Map<String, int>,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 25),

            Text('Ringkasan', style: headerStyle),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _moodData.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: Text(
                      'Tidak ada data untuk diringkas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildSummaryCard(
                        'Mood Terbanyak',
                        mostFrequent,
                        Icons.mood_rounded,
                      ),
                      _buildSummaryCard(
                        'Mood Terdikit',
                        leastFrequent,
                        Icons.mood_bad_rounded,
                      ),
                    ],
                  ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
