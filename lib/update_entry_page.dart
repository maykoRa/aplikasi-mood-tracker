import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

class _UpdateEntryPageState extends State<UpdateEntryPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _journalController;
  final ScrollController _scrollController = ScrollController();

  late DateTime _selectedDateTime;

  bool _isLoading = false;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _localeId = 'id_ID';

  String _textBeforeListening = '';
  bool _isListeningSheetOpen = false;
  Timer? _micWatchdog;

  final Color _primaryBlue = const Color(0xFF3B82F6);
  final Color _bgPage = const Color(0xFFF1F5F9);
  final Color _bgPaper = const Color(0xFFFFFFFF);
  final Color _textTitle = const Color(0xFF1E293B);
  final Color _textBody = const Color(0xFF334155);

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
    _scrollController.dispose();
    _micWatchdog?.cancel();
    _speechToText.cancel();
    super.dispose();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) {
          debugPrint('Speech Error: $val');
          _closeSheetSafe();
        },
        onStatus: (status) => debugPrint('Speech Status: $status'),
      );

      if (_speechEnabled) {
        var locales = await _speechToText.locales();
        var indo = locales.firstWhere(
          (l) => l.localeId.toLowerCase().contains('id'),
          orElse: () => locales.first,
        );
        _localeId = indo.localeId;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Init Error: $e");
    }
  }

  void _closeSheetSafe() {
    if (_isListeningSheetOpen && mounted) {
      _isListeningSheetOpen = false;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _startListening(BuildContext context) async {
    if (!_speechEnabled || _isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mic tidak siap. Coba keluar & masuk lagi.'),
        ),
      );
      return;
    }

    setState(() {
      _textBeforeListening = _journalController.text;
      if (_textBeforeListening.isNotEmpty &&
          !_textBeforeListening.endsWith(' ')) {
        _textBeforeListening += ' ';
      }
    });

    _isListeningSheetOpen = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ListeningSheet(),
    ).whenComplete(() {
      _isListeningSheetOpen = false;
      _stopListening();
    });

    try {
      await _speechToText.listen(
        localeId: _localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 30),
        onResult: (result) {
          setState(() {
            _journalController.text =
                _textBeforeListening + result.recognizedWords;
            _journalController.selection = TextSelection.fromPosition(
              TextPosition(offset: _journalController.text.length),
            );
          });

          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
      );

      _micWatchdog?.cancel();
      Future.delayed(const Duration(seconds: 1), () {
        _micWatchdog = Timer.periodic(const Duration(milliseconds: 500), (
          timer,
        ) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (!_speechToText.isListening && _isListeningSheetOpen) {
            timer.cancel();
            _closeSheetSafe();
          }
        });
      });
    } catch (e) {
      _closeSheetSafe();
    }
  }

  void _stopListening() async {
    _micWatchdog?.cancel();
    await _speechToText.stop();
  }

  Future<void> _updateEntry() async {
    final newJournal = _journalController.text.trim();
    if (newJournal.isEmpty || newJournal.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jurnal tidak boleh kosong',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bool journalChanged = newJournal != widget.currentJournal.trim();

      final Map<String, dynamic> updateData = {'journal': newJournal};

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
            ? 'Entri diperbarui! AI akan menganalisis ulang...'
            : 'Entri berhasil diperbarui.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dayNum = DateFormat('d').format(_selectedDateTime);
    final String monthYear = DateFormat(
      'MMM yyyy',
      'id_ID',
    ).format(_selectedDateTime);
    final String dayName = DateFormat(
      'EEEE',
      'id_ID',
    ).format(_selectedDateTime);
    final String timeStr = DateFormat('HH:mm').format(_selectedDateTime);

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _bgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: _textTitle,
          iconSize: 26,
          tooltip: 'Batal',
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Edit Entri",
          style: TextStyle(
            color: _textTitle,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    color: _textTitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              decoration: BoxDecoration(
                color: _bgPaper,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  dayNum,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryBlue,
                                    height: 1,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  monthYear,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryBlue,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _textTitle,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          controller: _journalController,
                          enabled: !_isLoading,
                          maxLines: null,
                          minLines: 5,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.8,
                            color: _textBody,
                            fontFamily: 'Poppins',
                          ),
                          decoration: InputDecoration(
                            hintText: "Tuliskan perubahan jurnalmu di sini...",
                            hintStyle: TextStyle(
                              fontSize: 16,
                              height: 1.8,
                              color: Colors.grey.withOpacity(0.5),
                              fontFamily: 'Poppins',
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _speechEnabled && !_isLoading
                        ? () => _startListening(context)
                        : null,
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _primaryBlue.withOpacity(0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: _primaryBlue,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.check_circle_rounded, size: 22),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ListeningSheet extends StatefulWidget {
  const ListeningSheet({super.key});

  @override
  State<ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<ListeningSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _animation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Saya Mendengarkan...",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Jeda hingga 30 detik. Pop-up tertutup\notomatis saat mic mati.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'Poppins',
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Selesai Bicara",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
