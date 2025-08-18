import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/message.dart'; // Hive 모델 (Message 클래스) import
import '../services/llm_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userInput;
  const ChatDetailScreen({super.key, required this.userInput});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late Box<Message> _chatBox;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _chatBox = Hive.box<Message>('chatBox');

    // 초기 유저 입력 저장 + 응답 요청
    _addMessage('user', widget.userInput);
    _fetchLLMResponse(widget.userInput);
  }

  void _addMessage(String sender, String text) {
    _chatBox.add(Message(sender: sender, text: text));
    setState(() {});
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _fetchLLMResponse(String input) async {
    try {
      final response = await http.post(
        Uri.parse('https://your-llm-server.com/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': input}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] ?? '응답이 없습니다.';
        _addMessage('bot', reply);
      } else {
        _addMessage('bot', '서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _addMessage('bot', '에러 발생: $e');
    }
  }

  void _handleSendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    _addMessage('user', message);
    _fetchLLMResponse(message);
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.sender == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFEDE7F6) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _chatBox.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅 화면'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await _chatBox.clear();
              setState(() {});
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(messages[index]);
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
