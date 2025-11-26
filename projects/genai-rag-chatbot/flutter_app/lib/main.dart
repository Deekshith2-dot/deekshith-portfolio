// lib/main.dart (patched: longer timeouts + /status check + snackbars)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

// <-- set this to your backend (keep your LAN IP or emulator mapping)
// const BACKEND_BASE = 'http://192.168.0.189:8000';
const BACKEND_BASE = 'https://vercel-deploy-opv8.onrender.com';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GenAI Chat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool fromUser;
  final DateTime time;
  final String? source; // 'rag' or 'llm_direct'
  ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    required this.time,
    this.source,
  });
}

class ChatModel extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool get isTyping => _isTyping;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(ChatMessage m) {
    _messages.add(m);
    notifyListeners();
  }

  void setTyping(bool v) {
    _isTyping = v;
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }

  Future<int> getStatus() async {
    try {
      final url = Uri.parse('$BACKEND_BASE/status');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final ntotal = data['ntotal'] as int? ?? 0;
        debugPrint('[STATUS] ntotal=$ntotal');
        return ntotal;
      }
    } catch (e) {
      debugPrint('[STATUS] error: $e');
    }
    return 0;
  }

  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;
    final now = DateTime.now();
    addMessage(ChatMessage(
        id: const Uuid().v4(), text: question, fromUser: true, time: now));

    // check if server has indexed document
    final ntotal = await getStatus();
    if (ntotal == 0) {
      // show a hint to the user that no doc indexed
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text:
          "No document is indexed on the server. The assistant will answer from general knowledge (llm). Upload a PDF to enable document-based answers.",
          fromUser: false,
          time: DateTime.now(),
          source: "system"));
    }

    setTyping(true);
    debugPrint('[ASK] question: $question');

    try {
      final url = Uri.parse('$BACKEND_BASE/ask');
      final body = jsonEncode({
        'question': question,
      });

      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final answer = data['answer'] as String? ?? 'No answer';
        final source = data['source'] as String?;
        addMessage(ChatMessage(
            id: const Uuid().v4(),
            text: answer,
            fromUser: false,
            time: DateTime.now(),
            source: source));
      } else {
        addMessage(ChatMessage(
            id: const Uuid().v4(),
            text: 'Server error: ${resp.statusCode}',
            fromUser: false,
            time: DateTime.now()));
      }
    } on TimeoutException catch (e) {
      debugPrint('[ASK] Timeout: $e');
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text: 'Request timed out. Try again later.',
          fromUser: false,
          time: DateTime.now()));
    } catch (e, st) {
      debugPrint('[ASK] Exception: $e\n$st');
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text: 'Error: $e',
          fromUser: false,
          time: DateTime.now()));
    } finally {
      setTyping(false);
    }
  }

  Future<void> uploadLocalPath(String localPath) async {
    setTyping(true);
    debugPrint('[UPLOAD_LOCAL] registering local_path: $localPath');
    try {
      final url = Uri.parse('$BACKEND_BASE/upload');
      var request = http.MultipartRequest('POST', url);
      request.fields['local_path'] = localPath;

      // increased timeout for heavy embedding first-run
      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final resp = await http.Response.fromStream(streamed);
      debugPrint('[UPLOAD_LOCAL] status: ${resp.statusCode}, body: ${resp.body}');
      if (resp.statusCode == 200) {
        addMessage(ChatMessage(
            id: const Uuid().v4(),
            text: 'Document registered.',
            fromUser: false,
            time: DateTime.now()));
      } else {
        addMessage(ChatMessage(
            id: const Uuid().v4(),
            text: 'Upload/register failed: ${resp.statusCode}',
            fromUser: false,
            time: DateTime.now()));
      }
    } on TimeoutException catch (e) {
      debugPrint('[UPLOAD_LOCAL] Timeout: $e');
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text: 'Upload timed out. Is the server busy? Try again later.',
          fromUser: false,
          time: DateTime.now()));
    } catch (e, st) {
      debugPrint('[UPLOAD_LOCAL] Exception: $e\n$st');
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text: 'Upload error: $e',
          fromUser: false,
          time: DateTime.now()));
    } finally {
      setTyping(false);
    }
  }

  Future<void> uploadFile(File file) async {
    setTyping(true);
    debugPrint('[UPLOAD_FILE] uploading file: ${file.path}');
    try {
      final url = Uri.parse('$BACKEND_BASE/upload');
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final resp = await http.Response.fromStream(streamed);
      debugPrint('[UPLOAD_FILE] status: ${resp.statusCode}, body: ${resp.body}');

      if (resp.statusCode == 200) {
        addMessage(ChatMessage(
            id: const Uuid().v4(),
            text: 'File uploaded and processed.',
            fromUser: false,
            time: DateTime.now()));
      } else {
        addMessage(ChatMessage(
            id: const Uuid().v4(),
            text: 'Upload failed: ${resp.statusCode}',
            fromUser: false,
            time: DateTime.now()));
      }
    } on TimeoutException catch (e) {
      debugPrint('[UPLOAD_FILE] Timeout: $e');
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text: 'Upload timed out. Try again later.',
          fromUser: false,
          time: DateTime.now()));
    } catch (e, st) {
      debugPrint('[UPLOAD_FILE] Exception: $e\n$st');
      addMessage(ChatMessage(
          id: const Uuid().v4(),
          text: 'Upload error: $e',
          fromUser: false,
          time: DateTime.now()));
    } finally {
      setTyping(false);
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<ChatModel>(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('GenAI Chat', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Upload PDF from device',
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom, allowedExtensions: ['pdf']);
                if (result != null && result.files.isNotEmpty) {
                  final path = result.files.single.path;
                  if (path != null) {
                    await model.uploadFile(File(path));
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'Register server-local demo file',
              onPressed: () async {
                // developer demo path (update if needed)
                const demoPath = '/mnt/data/eeb4c4c0-3f47-4a56-b2de-c5153971cf94.pdf';
                await model.uploadLocalPath(demoPath);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatArea(model)),
          _buildInputArea(model),
        ],
      ),
    );
  }

  Widget _buildChatArea(ChatModel model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.grey[50],
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: const PageStorageKey('chat_list'),
              reverse: true,
              itemCount: model.messages.length + (model.isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (model.isTyping && index == 0) {
                  return const _TypingIndicator();
                }
                final msg = model.messages.reversed.toList()[index - (model.isTyping ? 1 : 0)];
                return _ChatBubble(msg: msg);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatModel model) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_outlined),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom, allowedExtensions: ['pdf']);
                if (result != null && result.files.isNotEmpty) {
                  final path = result.files.single.path;
                  if (path != null) {
                    await model.uploadFile(File(path));
                  }
                }
              },
            ),
            Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) async {
                    final txt = _controller.text.trim();
                    if (txt.isEmpty) return;
                    _controller.clear();
                    await model.askQuestion(txt);
                  },
                  decoration: InputDecoration(
                    hintText: 'Ask about the uploaded docs or general question...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                )),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final txt = _controller.text.trim();
                if (txt.isEmpty) return;
                _controller.clear();
                await Provider.of<ChatModel>(context, listen: false).askQuestion(txt);
              },
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const _ChatBubble({required this.msg, super.key});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.fromUser;
    final bg = isUser ? Theme.of(context).colorScheme.primary : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(radius: 14, child: const Icon(Icons.person, size: 16)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 760),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  margin: EdgeInsets.only(left: isUser ? 60 : 0, right: isUser ? 0 : 60),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
                    ],
                  ),
                  child: SelectableText(
                    msg.text,
                    style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(radius: 14, backgroundColor: Colors.indigo, child: const Icon(Icons.person, size: 16, color: Colors.white)),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.source != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    msg.source ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(DateFormat.Hm().format(msg.time),
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          )
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({super.key});
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(int i) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut)),
      ),
      child: Container(width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.04), blurRadius: 8)]),
            child: Row(children: [ _dot(0), _dot(1), _dot(2) ]),
          ),
        ],
      ),
    );
  }
}
