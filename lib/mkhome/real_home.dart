// lib/mkhome/real_home.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:my_app/TopNav.dart';
import 'package:my_app/bottomNavigationBar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/mkhome/ChatDetailScreen.dart';

// ✅ 분리한 소켓 서비스 사용
import 'package:my_app/services/voice_socket_service.dart';

// ✅ Hive에 채팅 누적
import 'package:hive/hive.dart';
import 'package:my_app/models/message.dart';

final storage = FlutterSecureStorage();

class RealHomeScreen extends StatefulWidget {
  const RealHomeScreen({super.key});

  @override
  State<RealHomeScreen> createState() => _RealHomeScreenState();
}

class _RealHomeScreenState extends State<RealHomeScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;

  bool _isListening = false;
  String _text = '';
  String _username = '';
  bool _isLoggedIn = false;
  double _soundLevel = 0.0;

  late AnimationController _animationController;
  late Animation<double> _animation;

  // ✅ 싱글턴 서비스
  final voiceService = VoiceSocketService.instance;

  // ✅ Hive 박스 & 소켓 구독
  late Box<Message> _chatBox;
  StreamSubscription<String>? _assistantSub; // assistant_response
  StreamSubscription<String>? _transcriptSub; // (옵션) transcription

  @override
  void initState() {
    super.initState();
    _loadUsername();

    // 🔌 소켓 연결 (앱 생애주기에서 1회면 충분)
    // 보통 https:// 로 시도 (서버 설정에 따라 조정)
    voiceService.connect(url: 'https://llm.tassoo.uk');

    // 💾 Hive 박스 핸들
    _chatBox = Hive.box<Message>('chatBox');

    // 🤖 서버 응답 → 대화 누적
    _assistantSub = voiceService.assistantStream.listen((reply) {
      _addMessage('bot', reply);
    });

    // 🎙️ (서버가 STT 해줄 때만) 사용자 음성 텍스트도 누적하고 싶다면
    _transcriptSub = voiceService.transcriptionStream.listen((userText) {
      if (userText.trim().isNotEmpty) {
        _addMessage('user', userText);
        setState(() => _text = userText);
      }
    });

    _speech = stt.SpeechToText();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_animationController);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed && _isListening) {
        _animationController.forward();
      }
    });
  }

  Future<void> _loadUsername() async {
    final name = await storage.read(key: 'username') ?? '';
    setState(() {
      _username = name;
      _isLoggedIn = name.isNotEmpty;
      _text = '';
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _animationController.dispose();
    _assistantSub?.cancel();
    _transcriptSub?.cancel();
    super.dispose();
  }

  // ✅ 메시지 저장 + 상단 텍스트 갱신
  void _addMessage(String sender, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _chatBox.add(Message(sender: sender, text: trimmed));
    if (sender == 'user') {
      setState(() => _text = trimmed);
    }
  }

  void _listen() async {
    if (!_isListening) {
      final available = await _speech.initialize(
        onStatus: (status) {
          // STT 종료되면 서버로 전송
          if (status == "done") {
            final finalText = _text.trim();
            if (finalText.isNotEmpty) {
              _addMessage('user', finalText);
              voiceService.sendText(finalText); // ← LLM 서버로 텍스트 전송
            }
            _stopListening();
          }
        },
        onError: (err) => print('× STT 에러: $err'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _text = '🎙️ 듣고 있어요...';
        });

        _animationController.forward();
        _speech.listen(
          localeId: 'ko_KR',
          onResult: (val) => setState(() => _text = val.recognizedWords),
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(minutes: 1),
          cancelOnError: true,
          partialResults: true,
          onSoundLevelChange: (level) => setState(() => _soundLevel = level),
        );
      } else {
        setState(() => _text = '❌ 음성 인식 사용 불가');
      }
    } else {
      _speech.stop();
      _stopListening();
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _animationController.stop();
    _animationController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNav(
        isLoggedIn: _isLoggedIn,
        onLogin: () => Navigator.pushNamed(context, '/login'),
        onLogout: () async {
          await storage.delete(key: 'username');
          setState(() {
            _username = '';
            _isLoggedIn = false;
            _text = '';
          });
        },
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (_username.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'lib/assets/koala.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _username.isNotEmpty
                            ? '$_username님, 이야기를 들려주세요!'
                            : '이야기를 들려주세요!',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _text.isEmpty ? '🎤 여기에 인식된 텍스트가 표시됩니다' : _text,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      if (_text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ChatDetailScreen(userInput: _text),
                                ),
                              );
                            },
                            child: const Text("자세히 보기"),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // 🎤 녹음 버튼 + 반응 애니메이션
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('오늘 하루 어떻게 정리하는게 좋을까?'),
                  ),
                  GestureDetector(
                    onTap: _listen,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final scale =
                            _isListening
                                ? (_animation.value +
                                    (_soundLevel / 40).clamp(0.0, 1.0))
                                : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  _isListening
                                      ? Colors.red
                                      : const Color(0xFF8183D9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/real-home');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/sound');
          } else if (index == 3) {
            Navigator.pushReplacementNamed(context, '/setting');
          }
        },
      ),
    );
  }
}
