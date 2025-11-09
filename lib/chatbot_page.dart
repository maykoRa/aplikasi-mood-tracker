import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final User? user = FirebaseAuth.instance.currentUser;
  String? _currentChatId;

  late DocumentReference _chatSessionRef;
  late CollectionReference _messagesRef;

  bool _isLoading = false;

  // === VOICE INPUT ===
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadOrCreateChatSession();
  }

  void _initSpeech() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechEnabled = await _speechToText.initialize();
      if (mounted) setState(() {});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin mikrofon diperlukan untuk voice input'),
          ),
        );
      }
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _isListening) return;

    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      localeId: 'id_ID',
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);

    if (_lastWords.isNotEmpty) {
      _controller.text = _lastWords;
      _lastWords = '';
      _scrollToBottom();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _controller.text = _lastWords; // Update langsung di input
    });
  }

  void _loadOrCreateChatSession() async {
    if (user == null) return;

    final sessionsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('chats')
        .orderBy('lastMessage', descending: true)
        .limit(1)
        .get();

    if (sessionsSnap.docs.isNotEmpty) {
      setState(() {
        _currentChatId = sessionsSnap.docs.first.id;
      });
    }

    _updateRefs();
  }

  void _updateRefs() {
    // Hanya update ref jika user dan chat ID ada
    if (user != null && _currentChatId != null) {
      _chatSessionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('chats')
          .doc(_currentChatId);

      _messagesRef = _chatSessionRef.collection('messages');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty || user == null || _isLoading) return;

    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instanceFor(
        region: 'asia-southeast2',
      );
      final callable = functions.httpsCallable('sendChatMessage');

      final response = await callable.call({
        'userId': user!.uid,
        'message': message,
        'chatId': _currentChatId,
      });

      final newChatId = response.data['chatId'] as String?;
      if (newChatId != null && newChatId != _currentChatId) {
        setState(() {
          _currentChatId = newChatId;
        });
        _updateRefs(); // Pastikan referensi diperbarui ke chat ID baru
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI BARU UNTUK HAPUS CHAT ---
  Future<void> _handleDeleteChat() async {
    if (_currentChatId == null || user == null) return;

    // 1. Tampilkan dialog konfirmasi
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Riwayat'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus percakapan ini? Konteks akan di-reset dan Anda akan memulai percakapan baru.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // 2. Jika dikonfirmasi, lakukan penghapusan
    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        // Hapus dokumen chat session
        // Catatan: Ini tidak menghapus subkoleksi 'messages' secara otomatis
        // tapi akan membuatnya tidak bisa diakses & memulai sesi baru.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('chats')
            .doc(_currentChatId)
            .delete();

        // Reset state di frontend
        setState(() {
          _currentChatId = null;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Riwayat percakapan telah dihapus.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus riwayat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  // --- AKHIR FUNGSI BARU ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoodBuddy'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2,
        // --- PERUBAHAN: Tambahkan actions di AppBar ---
        actions: [
          // Tampilkan tombol hanya jika ada chat aktif dan tidak sedang loading
          if (_currentChatId != null && !_isLoading)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus Riwayat',
              onPressed: _handleDeleteChat,
            ),
        ],
        // --- AKHIR PERUBAHAN ---
      ),
      body: user == null
          ? const Center(child: Text('Silakan login terlebih dahulu'))
          : Column(
              children: [
                // === SUMMARY ===
                if (_currentChatId != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: _chatSessionRef.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const SizedBox();
                      }
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final summary = data?['summary'] as String?;
                      if (summary == null || summary == 'Percakapan dimulai.') {
                        return const SizedBox();
                      }
                      return Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          'Konteks: $summary',
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                      );
                    },
                  ),

                // === CHAT MESSAGES ===
                Expanded(
                  child: _currentChatId == null
                      ? const Center(
                          child: Text('Mulai percakapan dengan MoodBuddy!'),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: _messagesRef.orderBy('timestamp').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            // Jika snapshot tidak ada data ATAU
                            // snapshot.data!.docs kosong, tampilkan pesan
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              // Ini akan muncul sesaat setelah chat dihapus
                              return const Center(
                                child: Text('Belum ada pesan.'),
                              );
                            }

                            final messages = snapshot.data!.docs;
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg =
                                    messages[index].data()
                                        as Map<String, dynamic>;
                                final isUser = msg['role'] == 'user';

                                return Align(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? Colors.blue
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.75,
                                    ),
                                    child: Text(
                                      msg['message'] ?? '',
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // === INPUT FIELD DENGAN ICON MIC DI DALAM ===
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[50],
                  child: Row(
                    children: [
                      // === KOTAK INPUT + MIC + SEND ===
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? 'Mendengarkan...'
                                : _isLoading
                                ? 'Mengirim...'
                                : 'Ceritakan perasaanmu...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            // === ICON MIC DI KANAN DALAM ===
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // === TOMBOL MIC ===
                                IconButton(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _isListening
                                        ? const Icon(
                                            Icons.stop,
                                            key: ValueKey('stop'),
                                            color: Colors.red,
                                          )
                                        : const Icon(
                                            Icons.mic,
                                            key: ValueKey('mic'),
                                            color: Colors.grey,
                                          ),
                                  ),
                                  onPressed: _isListening
                                      ? _stopListening
                                      : _startListening,
                                ),
                                // === TOMBOL KIRIM ===
                                IconButton(
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.blue,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
                                          color: Color(0xFF3B82F6),
                                        ),
                                  onPressed: _isLoading ? null : _sendMessage,
                                ),
                              ],
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    super.dispose();
  }
}
