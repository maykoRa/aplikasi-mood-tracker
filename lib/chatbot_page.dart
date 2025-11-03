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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin mikrofon diperlukan untuk voice input')),
      );
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
      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
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
        _updateRefs();
      }

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoodBuddy'),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 2,
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
                      if (!snapshot.hasData) return const SizedBox();
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
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
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.blue),
                        ),
                      );
                    },
                  ),

                // === CHAT MESSAGES ===
                Expanded(
                  child: _currentChatId == null
                      ? const Center(child: Text('Mulai percakapan dengan MoodBuddy!'))
                      : StreamBuilder<QuerySnapshot>(
                          stream: _messagesRef.orderBy('timestamp').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text('Belum ada pesan.'));
                            }

                            final messages = snapshot.data!.docs;
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index].data() as Map<String, dynamic>;
                                final isUser = msg['role'] == 'user';

                                return Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isUser ? Colors.blue : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                    ),
                                    child: Text(
                                      msg['message'] ?? '',
                                      style: TextStyle(
                                        color: isUser ? Colors.white : Colors.black87,
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            // === ICON MIC DI KANAN DALAM ===
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // === TOMBOL MIC ===
                                IconButton(
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _isListening
                                        ? const Icon(Icons.stop, key: ValueKey('stop'), color: Colors.red)
                                        : const Icon(Icons.mic, key: ValueKey('mic'), color: Colors.grey),
                                  ),
                                  onPressed: _isListening ? _stopListening : _startListening,
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
                                      : const Icon(Icons.send, color: Color(0xFF3B82F6)),
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
