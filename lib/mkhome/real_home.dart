// lib/mkhome/real_home.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:typed_data';
import 'package:my_app/TopNav.dart';
import 'package:my_app/bottomNavigationBar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/mkhome/ChatDetailScreen.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';
import 'dart:convert';
// ✅ 분리한 소켓 서비스 사용
import 'package:my_app/services/voice_socket_service.dart';
import 'package:audio_session/audio_session.dart';

// ✅ Hive에 채팅 누적
import 'package:hive/hive.dart';
import 'package:my_app/models/message.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io' show Platform;
import 'package:flutter_sound/flutter_sound.dart';

final storage = FlutterSecureStorage();
final _player = FlutterSoundPlayer();

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
  bool _isPlaying = false;
  StreamSubscription<Uint8List>? _audioSub;

  late AnimationController _animationController;
  late Animation<double> _animation;

  // ✅ 싱글턴 서비스
  final voiceService = VoiceSocketService.instance;

  // ✅ Hive 박스 & 소켓 구독
  late Box<Message> _chatBox;
  StreamSubscription<String>? _assistantSub; // assistant_response
  StreamSubscription<String>? _transcriptSub; // (옵션) transcription
  StreamSubscription<Uint8List>? _pcmSub; // ← 오디오 스트림 구독 1개만
  // List<Uint8List> _audioBuffer = [];      // ← 버퍼링 제거

  @override
  void initState() {
    super.initState();
    _loadUsername();

    _initPlayer(); // 🎧 오디오 플레이어 초기화

    _chatBox = Hive.box<Message>('chatBox');
    if (!voiceService.isConnected) {
      voiceService.connect(url: 'https://llm.tassoo.uk/');
    }

    /*
    _transcriptSub = voiceService.transcriptionStream.listen((userText) {
      if (userText.trim().isNotEmpty) {
        _addMessage('user', userText);
        setState(() => _text = userText);
      }
    });
    */
    _audioSub = voiceService.audioStream.listen((pcmData) {
      debugPrint('Received PCM chunk, length: ${pcmData.length}');
      _audioBuffer.add(pcmData);
      setState(() {
        _audioAvailable = true;
      });
    });
    _assistantSub = voiceService.assistantStream.listen((reply) {
      print("🤖 LLM 응답 수신: $reply");

      if (reply.trim().isEmpty) return;

      _chatBox.add(Message(sender: 'bot', text: reply.trim()));

      if (mounted) {
        setState(() {});
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

  final List<Uint8List> _audioBuffer = []; // PCM 청크들 저장

  bool _audioAvailable = false;

  Future<void> _initPlayer() async {
    if (!voiceService.isConnected) {
      voiceService.connect(url: 'https://llm.tassoo.uk/');
    }
    await _player.openPlayer();
    // (버전마다 다를 수 있음) iOS 스피커로 강제 라우팅
    /* try {
      if (Platform.isIOS) {
        await _player.setAudioCategory(
          SessionCategory.playAndRecord,
          options: [
            SessionCategoryOptions.defaultToSpeaker,
            SessionCategoryOptions.allowBluetooth,
          ],
        );
      }
    } catch (_) {
      // 구버전: 카테고리 API 다르면 무시
    } */

    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
      interleaved: true,
      bufferSize: 2048,
    );

    // 들어오는 PCM을 즉시 먹이기
    _pcmSub = voiceService.audioStream.listen((Uint8List pcm) {
      // 중요: 서버 PCM이 16kHz, 16-bit LE, mono인지 반드시 맞춰야 함
      if (_player.foodSink != null) {
        _player.foodSink!.add(FoodData(pcm));
        if (!_isPlaying) setState(() => _isPlaying = true);
      }
    });
  }

  void _playBufferedAudio() async {
    if (!_audioAvailable || _audioBuffer.isEmpty) return;

    for (final chunk in _audioBuffer) {
      _player.uint8ListSink?.add(chunk);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() => _audioAvailable = false);
    _audioBuffer.clear();
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

    _audioSub?.cancel();
    _player.closePlayer();
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
              voiceService.sendText(finalText); // ✅ 여기에 추가!
              _addMessage('user', finalText);
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
          onResult: (val) {
            if (val.finalResult) {
              setState(() => _text = val.recognizedWords);
            }
          },
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

                  //여기가 스피커
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.volume_up : Icons.volume_mute,
                      color: Colors.black87,
                      size: 28,
                    ),
                    onPressed: () async {
                      if (_audioBuffer.isEmpty) return;

                      final copiedBuffer = List<Uint8List>.from(
                        _audioBuffer,
                      ); // 복사본 생성

                      for (final chunk in copiedBuffer) {
                        _player.uint8ListSink?.add(chunk);
                        await Future.delayed(const Duration(milliseconds: 100));
                      }

                      setState(() {
                        _isPlaying = true;
                        _audioBuffer.clear(); // 순회 이후 클리어
                      });
                    },
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
