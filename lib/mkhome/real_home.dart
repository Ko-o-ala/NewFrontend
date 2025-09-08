// lib/mkhome/real_home.dart
import 'dart:async';
import 'dart:io'; // ← 임시파일 폴백용
import 'dart:math'; // sin 함수 사용을 위해
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/Top_Nav.dart';
import 'package:my_app/services/voice_socket_service.dart';
import 'dart:convert'; // base64Decode
import 'package:my_app/services/api_client.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/message.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/sound/sound.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:shared_preferences/shared_preferences.dart';

final storage = FlutterSecureStorage();
final apiClient = ApiClient(
  baseUrl: 'https://llm.tassoo.uk',
  storage: storage, // 선택: 같은 storage 공유
);

class RealHomeScreen extends StatefulWidget {
  const RealHomeScreen({super.key});

  @override
  State<RealHomeScreen> createState() => _RealHomeScreenState();
}

class _RealHomeScreenState extends State<RealHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── 자동 재생을 위한 조립 타이머 & 큐 ──────────────────────────────
  Timer? _silentLoginRetryTimer; // ← 자동 재시도 타이머
  bool _silentLoginRetried = false; // ← 1회만 수행하기 위한 가드
  bool _disposed = false;
  // 즉시 화면 표시를 위해 false로 초기화

  Timer? _assembleTimer;
  final Duration _assembleGap = const Duration(milliseconds: 350);
  final List<Uint8List> _pendingQueue = [];
  bool _isPreparing = false; // 파일 쓰기 중 재진입 방지
  bool _autoResumeMic = true; // 말 끝나면 자동 재시작할지
  DateTime _lastTtsAt = DateTime.fromMillisecondsSinceEpoch(0); // 마지막 TTS 수신 시각

  // 필드 추가
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _playerCompleteSub;

  // ===== Speech & UI =====
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  String _username = '';
  double _soundLevel = 0.0;
  bool _isConversationBlocked = false; // 10회 초과 시 대화 차단 플래그
  Timer? _autoSendTimer; // 5초 후 자동 전송을 위한 타이머
  bool _isMicDisabled = false; // 알라가 말하는 동안 마이크 비활성화 플래그

  // ===== Audio (audioplayers) =====
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  // ===== Socket & DB =====
  final voiceService = VoiceSocketService.instance;
  late Box<Message> _chatBox;
  StreamSubscription<String>? _assistantSub;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<dynamic>? _pcmSub; // MP3 청크 구독
  StreamSubscription<bool>? _connSub;
  StreamSubscription<ServerDisconnectEvent>? _serverDiscSub;

  // MP3 버퍼 (WebSocket에서 받은 8KB 청크를 모았다가 한 번에 재생)
  final List<Uint8List> _audioBuffer = [];
  bool _audioAvailable = false;

  // ===== Animation =====
  late AnimationController _animationController;
  late Animation<double> _animation;
  // === 상태값 추가 ===
  bool _isThinking = false;

  // === 안내 배너: LLM 생각 중 ===
  Widget _thinkingBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child:
          (_isThinking && !_isListening)
              ? Container(
                key: const ValueKey('thinking_on'),
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 상단 아이콘과 텍스트
                    Row(
                      children: [
                        // 생각하는 코알라 아이콘
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '알라가 생각하고 있어요',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 하단 설명 텍스트와 애니메이션
                    Row(
                      children: [
                        // 말풍선 아이콘
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '여러분의 답변을 듣고 분석하고 있어요...',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 로딩 애니메이션
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(seconds: 2),
                            builder: (context, value, child) {
                              return Transform.rotate(
                                angle: value * 2 * 3.14159,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 진행 바 애니메이션
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(seconds: 3),
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.white, Colors.white70],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
              : const SizedBox.shrink(),
    );
  }

  // GlobalSoundService 상태 변화 처리
  void _onGlobalSoundChanged() {
    if (mounted) {
      // 디버그 로그 추가
      debugPrint(
        '[GLOBAL_SOUND] 상태 변화 감지 - userStoppedAutoPlay: ${GlobalSoundService().userStoppedAutoPlay}, currentPlaying: ${GlobalSoundService().currentPlaying}',
      );
      setState(() {
        // UI 업데이트를 위해 setState 호출
      });
    }
  }

  // === 안내 배너: 마이크 자동 종료 힌트 ===
  Widget _micAutoStopHint() {
    if (!_isListening) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '빨간 불일 때 5초간 말이 없으면 자동으로 꺼져요',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initAudioPlayer();

    // WebSocket 연결을 먼저 설정
    _initializeConnection();

    // real_home.dart 진입 시 사운드 중지
    _stopAllAudio();
    // 대화 횟수 로드 및 차단 상태 확인
    _checkConversationLimit();
    _chatBox = Hive.box<Message>('chatBox');

    // 프로필 업데이트 감지
    _checkProfileUpdate();

    // 앱 생명주기 관찰자 추가
    WidgetsBinding.instance.addObserver(this);

    // GlobalSoundService 상태 변화 감지
    GlobalSoundService().addListener(_onGlobalSoundChanged);

    // 🔌 소켓 연결 상태 반영
    _connSub = voiceService.connectionStream.listen((connected) async {
      if (!connected) {
        await _gracefulStopAll('서버 연결이 끊어졌습니다');
      } else {
        _autoResumeMic = true;
      }
    });

    // ② 서버가 의도적으로 끊을 때(이유 포함) 처리
    _serverDiscSub = voiceService.serverDisconnectStream.listen((evt) async {
      // 공통 정리
      await _gracefulStopAll(evt.message);

      // reason 분기
      if (evt.reason == 'sound') {
        // 사운드 페이지로 이동 + 추천 자동재생 플래그 전달
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/sound',
            arguments: {
              'autoplayRecommended': true,
            }, // ← 사운드 페이지에서 이 값을 보고 3개 자동재생
          );
        }
      } else {
        // 'silent' 또는 기타: 추가 동작 없이 종료만
      }
    });

    Uint8List _toMp3Bytes(dynamic evt) {
      try {
        // 1) 이미 바이트
        if (evt is Uint8List) return evt;
        if (evt is List<int>) return Uint8List.fromList(evt);

        // 2) data URL 또는 순수 base64 문자열
        if (evt is String) {
          final s = evt.startsWith('data:') ? evt.split(',').last : evt;
          return base64Decode(s);
        }

        // 3) JSON/Map 형태: 흔한 키들 대응
        if (evt is Map) {
          final a = evt['audio'] ?? evt['chunk'] ?? evt['data'] ?? evt['bytes'];
          if (a == null) return Uint8List(0);
          if (a is Uint8List) return a;
          if (a is List<int>) return Uint8List.fromList(a);
          if (a is String) {
            final s = a.startsWith('data:') ? a.split(',').last : a;
            return base64Decode(s);
          }
        }
      } catch (e) {
        debugPrint('toMp3Bytes error: $e (${evt.runtimeType})');
      }
      return Uint8List(0);
    }

    // 서버 오디오(MP3 청크) 수신 → 버퍼에 저장
    _pcmSub = voiceService.audioStream.listen(
      (event) {
        final bytes = _toMp3Bytes(event);
        _lastTtsAt = DateTime.now();
        _audioAvailable = true;

        if (bytes.isEmpty) {
          debugPrint('⏩ skip non-audio or empty: ${event.runtimeType}');
          return;
        }

        _audioBuffer.add(bytes);
        _audioAvailable = true;

        if (_isThinking) setState(() => _isThinking = false);

        // (선택) 프리뷰 로그
        final preview = bytes
            .take(8)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        debugPrint(
          '🎵 chunk in: ${bytes.length} bytes [$preview]  total=${_audioBuffer.length}',
        );

        _scheduleAssemble(); // ← 마지막에 호출
        if (mounted) setState(() {});
      },
      onError: (e, st) {
        debugPrint('audioStream error: $e');
      },
    );

    String extractTextFromFormattedString(String input) {
      final regex = RegExp(r'\{text:\s*((.|\n)*?)\s*\}$');

      final match = regex.firstMatch(input);
      if (match != null) {
        return match.group(1) ?? input;
      }
      return input;
    }

    // 어시스턴트 텍스트 수신 → 채팅에 기록
    _assistantSub = voiceService.assistantStream.listen((reply) {
      if (reply.trim().isEmpty) return;

      final textOnly = extractTextFromFormattedString(reply.trim());

      _chatBox.add(Message(sender: 'bot', text: textOnly));

      if (mounted) {
        setState(() {
          _isThinking = false;
          _text = textOnly; // ✅ 이제 깔끔한 텍스트만 들어감
        });
      }
    });

    // STT
    _speech = stt.SpeechToText();

    // 마이크 애니메이션x
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

  void _scheduleAssemble() {
    _assembleTimer?.cancel();
    _assembleTimer = Timer(_assembleGap, () async {
      if (!mounted || _disposed) return;
      if (_audioBuffer.isEmpty) return;

      // 1) 버퍼 합치기
      final all = Uint8List.fromList(_audioBuffer.expand((e) => e).toList());
      _audioBuffer.clear();
      _audioAvailable = false;

      // 2) MP3 프레임 경계 정리
      final trimmed = _stripToFirstMp3Frame(all);
      if (trimmed.isEmpty) {
        debugPrint('⚠️ trimmed mp3 is empty');
        return;
      }

      // 3) 큐에 넣고, 재생 중이 아니면 바로 재생
      _pendingQueue.add(trimmed);
      if (!_isPlaying && !_isPreparing) {
        _playNextFromQueue();
      }
    });
  }

  Future<void> _connectVoice() async {
    final jwt = await storage.read(key: 'jwt') ?? ''; // 🔑 저장키가 'jwt'인지 확인!
    final wsUri = Uri(
      scheme: 'wss',
      host: 'llm.tassoo.uk',
      // path: '/ws', // 서버가 경로 요구하면 설정
      queryParameters: jwt.isNotEmpty ? {'jwt': jwt} : null,
    );

    debugPrint('WS connect: $wsUri'); // 예: wss://llm.tassoo.uk?jwt=...
    voiceService.connect(url: wsUri.toString());

    // 연결 완료를 기다림 (최대 3초)
    int attempts = 0;
    while (!voiceService.isConnected && attempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (voiceService.isConnected) {
      debugPrint('[CONNECTION] WebSocket 연결 성공');
    } else {
      debugPrint('[CONNECTION] WebSocket 연결 타임아웃');
    }
  }

  Future<void> _incConversationCount() async {
    try {
      final raw = await storage.read(key: 'talk_count');
      final current = int.tryParse(raw ?? '0') ?? 0;
      final next = current + 1;
      await storage.write(key: 'talk_count', value: '$next');

      debugPrint('[CONVERSATION] 대화 횟수 증가: $current → $next');

      // 10회 도달 시 1번만 알림
      if (next > 10) {
        debugPrint('[CONVERSATION] 10회 도달 - 유료 결제 안내 표시');
        _showPaywallHint();
      }

      // 10회 초과 시 대화 차단
      if (next > 10) {
        debugPrint('[CONVERSATION] 10회 초과 - 대화 기능 차단');
        setState(() {
          _isConversationBlocked = true;
        });
      }
    } catch (e) {
      debugPrint('[PAYWALL] failed to inc: $e');
    }
  }

  Future<void> _checkConversationLimit() async {
    try {
      final raw = await storage.read(key: 'talk_count');
      final current = int.tryParse(raw ?? '0') ?? 0;

      debugPrint('[CONVERSATION] 현재 대화 횟수: $current');

      if (current > 10) {
        debugPrint('[CONVERSATION] 10회 초과 감지 - 대화 기능 차단 상태로 설정');
        setState(() {
          _isConversationBlocked = true;
        });
      } else {
        debugPrint('[CONVERSATION] 대화 가능 상태 (${10 - current}회 남음)');
      }
    } catch (e) {
      debugPrint('[CONVERSATION_LIMIT] failed to check: $e');
    }
  }

  // 로컬 스토리지 초기화 함수
  Future<void> _resetLocalStorage() async {
    try {
      // 대화 횟수 초기화
      await storage.delete(key: 'talk_count');

      // 상태 초기화
      setState(() {
        _isConversationBlocked = false;
        _isMicDisabled = false;
        _isListening = false;
        _isThinking = false;
        _isPlaying = false;
        _text = '';
        _soundLevel = 0.0;
      });

      // 오디오 정리
      _audioBuffer.clear();
      _audioAvailable = false;
      _pendingQueue.clear();

      // 타이머 취소
      _autoSendTimer?.cancel();
      _autoSendTimer = null;

      // 애니메이션 정지
      _animationController.stop();
      _animationController.reset();

      debugPrint('[RESET] 로컬 스토리지 초기화 완료');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 로컬 스토리지가 초기화되었습니다'),
            backgroundColor: Color(0xFF6C63FF),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RESET] 초기화 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ 초기화 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 현재 텍스트 전송 함수
  void _sendCurrentText() {
    final finalText = _text.trim();
    if (finalText.isNotEmpty && !_isConversationBlocked) {
      // 사용자 말이 끝나면 마이크 비활성화
      setState(() => _isMicDisabled = true);

      // WebSocket 연결 상태 재확인
      if (!voiceService.isConnected) {
        debugPrint('[SEND] WebSocket 연결 끊어짐 - 재연결 시도');
        _connectVoice().then((_) {
          if (voiceService.isConnected) {
            setState(() => _isThinking = true);
            voiceService.sendText(finalText);
            _addMessage('user', finalText);
            _stopListening();
          } else {
            setState(() => _text = '❌ 서버 연결 실패');
            _stopListening();
            // 연결 실패 시 마이크 다시 활성화
            setState(() => _isMicDisabled = false);
          }
        });
      } else {
        setState(() => _isThinking = true);
        voiceService.sendText(finalText);
        _addMessage('user', finalText);
        _stopListening();
      }
    } else {
      _stopListening();
    }
  }

  // 초기 연결 설정
  Future<void> _initializeConnection() async {
    try {
      await _connectVoice();
      debugPrint('[INIT] 초기 WebSocket 연결 완료');
    } catch (e) {
      debugPrint('[INIT] 초기 연결 실패: $e');
    }
  }

  // 대화 중단 함수
  void _stopConversation() {
    try {
      // 음성 인식 중단
      if (_isListening) {
        _speech.stop();
        setState(() {
          _isListening = false;
        });
      }

      // TTS 재생 중단
      if (_isPlaying) {
        _player.stop();
        setState(() {
          _isPlaying = false;
        });
      }

      // WebSocket 연결 종료
      voiceService.disconnect();

      // 상태 초기화
      setState(() {
        _isThinking = false;
        _isMicDisabled = false; // 마이크 비활성화 상태 초기화
        _text = '';
        _soundLevel = 0.0;
      });

      // 오디오 버퍼 클리어
      _audioBuffer.clear();
      _audioAvailable = false;

      // 애니메이션 정지
      _animationController.stop();
      _animationController.reset();

      // 자동 전송 타이머 취소
      _autoSendTimer?.cancel();
      _autoSendTimer = null;

      debugPrint('[CONVERSATION] 대화가 중단되었습니다');
    } catch (e) {
      debugPrint('[CONVERSATION] 중단 중 오류: $e');
    }
  }

  void _showPaywallHint() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  '알림',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '알라와 더 대화를 하기 위해서는\n추후 유료 결제가 필요한 서비스입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConversationBlockedDialog() {
    if (!mounted) return;
    debugPrint('[CONVERSATION] 대화 차단 다이얼로그 표시');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.block, color: Colors.red, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  '대화 제한',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '무료 대화 횟수를 모두 사용했습니다.\n알라와의 대화를 계속하려면\n유료 결제가 필요합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _gracefulStopAll(String uiMessage) async {
    _autoResumeMic = false;

    if (_isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      _stopListening();
    }
    try {
      await _player.stop();
    } catch (_) {}

    _pendingQueue.clear();
    _audioBuffer.clear();
    _audioAvailable = false;

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isThinking = false;
        _isMicDisabled = false; // 마이크 비활성화 상태 초기화
        _text = uiMessage; // 화면에 사유/안내 표시
      });
    }
  }

  Future<void> _playNextFromQueue() async {
    if (_pendingQueue.isEmpty) return;
    _isPreparing = true;

    try {
      // STT 중이면 끄고 재생 모드 전환
      if (_isListening) {
        _speech.stop();
        _stopListening();
      }
      await _enterPlaybackMode();

      final bytes = _pendingQueue.removeAt(0);

      // iOS 호환을 위해 파일로 저장 후 재생
      final path = await _writeTemp(bytes, ext: 'mp3');
      debugPrint('🎧 auto play: $path');

      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('auto play error: $e');
    } finally {
      _isPreparing = false;
    }
  }

  Future<void> _resumeMicIfQuiet({
    Duration minSilence = const Duration(milliseconds: 700),
  }) async {
    if (!_autoResumeMic) return;
    if (!mounted) return;

    // 대화 차단 상태면 자동 재시작하지 않음
    if (_isConversationBlocked) return;

    // 마이크가 비활성화된 상태면 자동 재시작하지 않음
    if (_isMicDisabled) return;

    // 재생/준비/청취 중이면 패스
    if (_isPlaying || _isPreparing || _isListening) return;
    // 큐/버퍼에 남은 오디오가 있으면 패스
    if (_pendingQueue.isNotEmpty || _audioAvailable || _audioBuffer.isNotEmpty)
      return;

    // 혹시 막판 청크가 더 오나 700ms 기다렸다가…
    await Future.delayed(minSilence);
    if (!mounted) return;

    final sinceLast = DateTime.now().difference(_lastTtsAt);
    final reallyQuiet =
        _pendingQueue.isEmpty &&
        !_audioAvailable &&
        _audioBuffer.isEmpty &&
        sinceLast >= minSilence;

    if (reallyQuiet && !_isListening && !_isConversationBlocked) {
      debugPrint('[MIC] 조용함 감지 - 자동 마이크 재시작');
      await _enterMicMode(); // 녹음 세션으로 전환(iOS 필수)
      await Future.delayed(const Duration(milliseconds: 80)); // 세션 전환 여유
      if (mounted && !_isListening) _listen();
    }
  }

  Future<void> _stopAllAudio() async {
    try {
      // 모든 오디오 플레이어 중지
      await _player.stop();

      // GlobalSoundService의 오디오도 중지
      final globalSoundService = GlobalSoundService();
      await globalSoundService.stop();
    } catch (e) {
      print('오디오 중지 중 오류: $e');
    }
  }

  Future<void> _initAudioPlayer() async {
    // iOS 무음 스위치/스피커 라우팅, Android 스피커포스
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            // AVAudioSessionOptions.defaultToSpeaker, // OK
            // AVAudioSessionOptions.allowBluetoothA2DP, // OK (헤드폰/스피커 재생용)
          },
        ),

        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    await _player.setReleaseMode(ReleaseMode.stop);

    _playerStateSub?.cancel();
    _playerCompleteSub?.cancel();

    _playerStateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted || _disposed) return;
      setState(() {
        _isPlaying = s == PlayerState.playing;
        if (_isPlaying) {
          _isThinking = false;
          // 알라가 말하기 시작하면 마이크 비활성화 유지
          _isMicDisabled = true;
        }
      });
    });

    _playerCompleteSub = _player.onPlayerComplete.listen((_) async {
      if (!mounted || _disposed) return;
      setState(() => _isPlaying = false);
      if (_pendingQueue.isNotEmpty) {
        _playNextFromQueue();
      } else {
        // 알라의 말이 끝나면 마이크 다시 활성화
        setState(() => _isMicDisabled = false);
        await _resumeMicIfQuiet();
      }
    });
  }

  /// MP3 헤더(ID3) 또는 첫 MPEG 오디오 프레임 동기를 찾아 그 지점부터 잘라냅니다.
  Uint8List _stripToFirstMp3Frame(Uint8List b) {
    // ID3 태그면 그대로 두어도 되지만, 곧바로 오디오 프레임부터 시작하고 싶으면
    // ID3 사이즈를 계산해 건너뛰는 로직을 넣을 수 있습니다.
    if (b.length >= 3 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) {
      // 'ID3' – 여기서는 자르지 않고 그대로 사용 (대부분 플레이어가 처리 가능)
      return b;
    }
    // MPEG 오디오 프레임 동기 0xFFE? 탐색
    final off = _findFirstMpegSync(b);
    if (off <= 0) return b; // 0이면 이미 프레임 시작, -1이면 못 찾음 → 그대로
    return b.sublist(off);
  }

  int _findFirstMpegSync(Uint8List b) {
    for (int i = 0; i + 1 < b.length; i++) {
      if (b[i] == 0xFF && (b[i + 1] & 0xE0) == 0xE0) {
        // 1111 1111 1110 xxxx (MPEG frame sync)
        return i;
      }
    }
    return -1;
  }

  Future<String> _writeTemp(Uint8List bytes, {required String ext}) async {
    final f = File(
      '${Directory.systemTemp.path}/llm_audio_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  Future<void> _loadUsername() async {
    try {
      // 백그라운드에서 로그인 체크 수행 (UI 블로킹 없음)

      final token = await storage.read(key: 'jwt');
      if (token == null || token.isEmpty) {
        setState(() {
          _username = '';
          _text = '';
        });
        _scheduleSilentLoginRetry(); // 2초 뒤 재확인
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse('https://kooala.tassoo.uk/users/profile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (userData['success'] == true && userData['data'] != null) {
          final name = userData['data']['name'] ?? '';
          // 값이 실제로 변경되었을 때만 setState 호출
          if (_username != name) {
            setState(() {
              _username = name;
              _text = '';
            });
          }
          return;
        }
      }

      // 실패 → 한 번만 무음 재시도
      setState(() {
        _username = '';
        _text = '';
      });
      _scheduleSilentLoginRetry();
    } catch (e) {
      debugPrint('[USERNAME] Error fetching username: $e');
      setState(() {
        _username = '';
        _text = '';
      });
      _scheduleSilentLoginRetry();
    }
  }

  Future<void> _enterMicMode() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth, // ✅ 여기서는 허용
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.voiceCommunication,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
  }

  Future<void> _enterPlaybackMode() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            //  AVAudioSessionOptions.defaultToSpeaker,
            // AVAudioSessionOptions.allowBluetoothA2DP, // ✅ 재생 모드에서는 이걸 사용
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
  }

  // ===== 기존 함수들 =====

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // SharedPreferences에서 프로필 업데이트 플래그 확인
    _checkProfileUpdate();
  }

  Future<void> _loadUsernameFromLocal() async {
    try {
      final updatedName = await storage.read(key: 'username');
      if (updatedName != null && updatedName.isNotEmpty) {
        if (mounted && !_disposed) {
          setState(() {
            _username = updatedName;
          });
        }
        debugPrint('[RealHome] 로컬 저장소에서 이름 새로고침: $updatedName');
      }
    } catch (e) {
      debugPrint('[RealHome] 로컬 저장소에서 이름 로드 실패: $e');
    }
  }

  Future<void> _checkProfileUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileUpdated = prefs.getBool('profileUpdated') ?? false;

      if (profileUpdated) {
        // 프로필이 업데이트된 경우 로컬 저장소에서 사용자 이름 다시 로드
        await _loadUsernameFromLocal();
        // 플래그 제거
        await prefs.remove('profileUpdated');
      } else {
        // 일반적인 경우 debounce 처리
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_disposed) {
            _loadUsername();
          }
        });
      }
    } catch (e) {
      debugPrint('[RealHome] 프로필 업데이트 체크 실패: $e');
      // 오류 발생 시에도 일반적인 로드 수행
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_disposed) {
          _loadUsername();
        }
      });
    }
  }

  void dispose() {
    _serverDiscSub?.cancel();
    _connSub?.cancel();
    _disposed = true; // ✅ 가드 온
    _assembleTimer?.cancel(); // ✅ 타이머 취소
    _playerStateSub?.cancel(); // ✅ 구독 취소
    _playerCompleteSub?.cancel();
    _silentLoginRetryTimer?.cancel();
    _autoSendTimer?.cancel(); // 자동 전송 타이머 취소
    _speech.cancel();
    _animationController.dispose();

    _assistantSub?.cancel();
    _transcriptSub?.cancel();
    _pcmSub?.cancel();

    _player.dispose();

    // GlobalSoundService 리스너 제거
    GlobalSoundService().removeListener(_onGlobalSoundChanged);

    // 앱 생명주기 관찰자 제거
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('[LIFECYCLE] 앱이 다시 활성화됨 - WebSocket 연결 확인');
        // 앱이 다시 활성화될 때 WebSocket 연결 상태 확인
        if (!voiceService.isConnected) {
          debugPrint('[LIFECYCLE] WebSocket 연결 끊어짐 - 재연결 시도');
          _connectVoice();
        }
        // GlobalSoundService 상태도 체크
        _onGlobalSoundChanged();
        break;
      case AppLifecycleState.paused:
        debugPrint('[LIFECYCLE] 앱이 일시정지됨');
        // 앱이 일시정지될 때는 연결을 유지 (대화 중단하지 않음)
        break;
      case AppLifecycleState.detached:
        debugPrint('[LIFECYCLE] 앱이 종료됨');
        break;
      case AppLifecycleState.inactive:
        debugPrint('[LIFECYCLE] 앱이 비활성화됨');
        break;
      case AppLifecycleState.hidden:
        debugPrint('[LIFECYCLE] 앱이 숨겨짐');
        break;
    }
  }

  // 메시지 저장 + 상단 텍스트 갱신
  void _addMessage(String sender, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _chatBox.add(Message(sender: sender, text: trimmed));
    if (sender == 'user') {
      setState(() => _text = trimmed);
      _incConversationCount(); // ⬅️ 추가
    }
  }

  void _scheduleSilentLoginRetry() {
    if (_silentLoginRetried || _disposed) return;
    _silentLoginRetried = true;

    _silentLoginRetryTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _disposed) return;
      final jwt = await storage.read(key: 'jwt');
      if (jwt != null && jwt.isNotEmpty) {
        debugPrint('[LOGIN] silent retry: token 발견 → 프로필 재요청');
        await _loadUsername(); // 백그라운드에서 사용자 정보 로드
      } else {
        debugPrint('[LOGIN] silent retry: 여전히 토큰 없음');
        // 로그인 재시도 완료 (UI 변경 없음)
      }
    });
  }

  void _listen() async {
    // 10회 초과 시 대화 차단
    if (_isConversationBlocked) {
      debugPrint('[CONVERSATION] 대화 차단 상태 - 마이크 버튼 클릭 무시');
      _showConversationBlockedDialog();
      return;
    }

    // 알라가 말하는 중이면 마이크 버튼 클릭 무시
    if (_isMicDisabled) {
      debugPrint('[MIC] 알라가 말하는 중 - 마이크 버튼 클릭 무시');
      return;
    }

    if (!_isListening) {
      // WebSocket 연결 상태 확인 및 재연결
      if (!voiceService.isConnected) {
        debugPrint('[CONVERSATION] WebSocket 연결 끊어짐 - 재연결 시도');
        await _connectVoice();

        if (!voiceService.isConnected) {
          setState(() => _text = '❌ 서버 연결 실패');
          return;
        }
      }

      await _enterMicMode();
      await Future.delayed(const Duration(milliseconds: 80));

      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[MIC] 음성 인식 상태: $status');
          if (status == "done") {
            // 타이머 취소하고 즉시 전송
            _autoSendTimer?.cancel();
            _autoSendTimer = null;
            _sendCurrentText();
          } else if (status == "notListening") {
            _stopListening();
          }
        },
        onError: (err) => debugPrint('× STT 에러: $err'),
      );

      if (available) {
        _audioBuffer.clear();
        _audioAvailable = false;

        setState(() {
          _isListening = true;
          _isThinking = false;
          _text = '🎙️ 듣고 있어요...';
        });

        debugPrint('[MIC] 마이크 시작 - 5초 조용함 후 자동 종료 설정');
        _animationController.forward();

        // 5초 후 자동 전송 타이머 시작
        _autoSendTimer?.cancel();
        _autoSendTimer = Timer(const Duration(seconds: 5), () {
          if (_isListening && _text.trim().isNotEmpty) {
            debugPrint('[MIC] 5초 타이머 - 자동 전송 실행');
            _sendCurrentText();
          }
        });
        _speech.listen(
          localeId: 'ko_KR',
          onResult: (val) {
            if (val.finalResult) {
              setState(() => _text = val.recognizedWords);
            }
          },
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(minutes: 1),
          cancelOnError: true,
          partialResults: true,
          onSoundLevelChange: (level) {
            setState(() => _soundLevel = level);
            debugPrint('[MIC] 음성 레벨: ${level.toStringAsFixed(2)}');
          },
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
    debugPrint('[MIC] 마이크 종료');
    setState(() => _isListening = false);
    _animationController.stop();
    _animationController.reset();

    // 자동 전송 타이머 취소
    _autoSendTimer?.cancel();
    _autoSendTimer = null;
  }

  Widget _buildGlobalMiniPlayer() {
    final service = GlobalSoundService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, child) {
        // 디버그 로그 추가
        debugPrint(
          '[MINI_PLAYER] 체크 - userStoppedAutoPlay: ${service.userStoppedAutoPlay}, currentPlaying: ${service.currentPlaying}, isPlaying: ${service.isPlaying}',
        );

        // 재생 중인 음악이 없으면 플레이어 숨김
        if (service.currentPlaying == null || service.currentPlaying!.isEmpty) {
          return const SizedBox.shrink();
        }

        debugPrint('[MINI_PLAYER] 플레이어 표시');

        final title = service.currentPlaying!
            .replaceAll('.mp3', '')
            .replaceAll('_', ' ');

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 진행바 (터치 가능한 슬라이더) - 스트림 기반으로 부드럽게
                Container(
                  height: 8,
                  margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
                  child: _MiniSeekBar(player: service.player),
                ),
                // 메인 컨텐츠
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // 시간 표시 - 스트림으로 자연스럽게 갱신
                            StreamBuilder<Duration>(
                              stream: service.player.positionStream,
                              initialData: service.player.position,
                              builder: (_, snap) {
                                final current = snap.data ?? Duration.zero;
                                final total = service.player.duration;
                                return Text(
                                  _formatTime(current, total),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          service.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          if (service.isPlaying) {
                            service.pause();
                          } else {
                            service.player.play();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.stop_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: service.stopFromMiniPlayer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(Duration? current, Duration? total) {
    String f(Duration d) {
      final m = d.inMinutes;
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    if (current == null || total == null) return '0:00 / 0:00';
    return '${f(current)} / ${f(total)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopNav(
        title: '알라와 코잘라',
        showBackButton: false, // 홈은 루트이므로 숨김
        // gradient: LinearGradient( // 필요시 그라디언트 켜기
        //   colors: [Color(0xFF1D1E33), Color(0xFF141527)],
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        // ),
      ),

      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // 상단에 고정된 thinking banner (alert 형태)
                _thinkingBanner(),

                // 메인 콘텐츠
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // 인사말 (보라색 배경)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6C63FF,
                                ).withOpacity(0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 인사말
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.waving_hand,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _username.isNotEmpty
                                        ? '$_username님, 안녕하세요!'
                                        : '안녕하세요!',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '오늘 하루는 어땠나요?\n코알라와 대화해보세요!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 대화 안내 카드
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  _isConversationBlocked
                                      ? Colors.red.withOpacity(0.3)
                                      : const Color(
                                        0xFF6C63FF,
                                      ).withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      _isConversationBlocked
                                          ? Colors.red.withOpacity(0.2)
                                          : const Color(
                                            0xFF6C63FF,
                                          ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _isConversationBlocked
                                      ? Icons.block
                                      : Icons.info_outline,
                                  color:
                                      _isConversationBlocked
                                          ? Colors.red
                                          : const Color(0xFF6C63FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isConversationBlocked
                                          ? '🚫 대화 제한'
                                          : '💡 대화 안내',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isConversationBlocked
                                          ? '무료 대화 횟수(10회)를 모두 사용했습니다.\n알라와의 대화를 계속하려면 유료 결제가 필요합니다.'
                                          : '대화가 끝나면 자동으로 마이크가 활성화되니, 눈을 감고 편하게 대화해보세요.\n\n졸리다고 말하면 추천사운드를 들을 수 있습니다.\n 말을 하지 않을 경우 알라는 사용자분이 잠에 들었다고 판단하고 자동으로 대화를 종료합니다.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 코알라 이미지 (보라색 배경에서 분리)
                        Center(
                          child: Image.asset(
                            'lib/assets/koala.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 항상 메인 화면 표시 (로그인 체크는 백그라운드에서)
                        ...[
                          const SizedBox(height: 24),

                          // 음성 인식 텍스트 표시 영역
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.mic,
                                        color: Color(0xFF6C63FF),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      '음성 인식 결과',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A0E21),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF6C63FF,
                                      ).withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    child: Text(
                                      _text.isEmpty
                                          ? '🎤 여기에 인식된 텍스트가 표시됩니다'
                                          : _text,
                                      key: ValueKey(_text),
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.6,
                                        color:
                                            _text.isEmpty
                                                ? Colors.white54
                                                : Colors.white,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      textAlign: TextAlign.justify,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 대화 제안 카드
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline,
                                    color: Color(0xFFFFD700),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    '오늘 하루 어떻게 정리하는게 좋을까?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // 마이크 버튼 섹션
                          Column(
                            children: [
                              // 마이크 버튼
                              GestureDetector(
                                onTap:
                                    (_isConversationBlocked || _isMicDisabled)
                                        ? null
                                        : _listen,
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    final scale =
                                        _isListening
                                            ? (_animation.value +
                                                (_soundLevel / 40).clamp(
                                                  0.0,
                                                  1.0,
                                                ))
                                            : 1.0;
                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        padding: const EdgeInsets.all(28),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors:
                                                (_isConversationBlocked ||
                                                        _isMicDisabled)
                                                    ? [
                                                      Colors.grey,
                                                      Colors.grey.shade700,
                                                    ]
                                                    : _isListening
                                                    ? [
                                                      Colors.red,
                                                      Colors.red.shade700,
                                                    ]
                                                    : [
                                                      const Color(0xFF6C63FF),
                                                      const Color(0xFF4B47BD),
                                                    ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: ((_isConversationBlocked ||
                                                          _isMicDisabled)
                                                      ? Colors.grey
                                                      : _isListening
                                                      ? Colors.red
                                                      : const Color(0xFF6C63FF))
                                                  .withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          (_isConversationBlocked ||
                                                  _isMicDisabled)
                                              ? Icons.block
                                              : _isListening
                                              ? Icons.stop
                                              : Icons.mic,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              // 상태 표시 텍스트
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D1E33),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        (_isConversationBlocked ||
                                                _isMicDisabled)
                                            ? Colors.red.withOpacity(0.3)
                                            : _isListening
                                            ? const Color(
                                              0xFF6C63FF,
                                            ).withOpacity(0.3)
                                            : Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _isConversationBlocked
                                      ? '🚫 대화 횟수 초과 - 유료 결제 필요'
                                      : _isMicDisabled
                                      ? '🔇 알라가 말하는 중...'
                                      : _isListening
                                      ? '🎙️ 듣고 있어요...'
                                      : '🎤 마이크를 탭해서 대화 시작',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        (_isConversationBlocked ||
                                                _isMicDisabled)
                                            ? Colors.red
                                            : _isListening
                                            ? const Color(0xFF6C63FF)
                                            : Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 대화 중단 버튼 (음성 인식 중이거나 알라가 말하는 중일 때 표시)
                          if (_isListening ||
                              _isThinking ||
                              _isPlaying ||
                              _isMicDisabled)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: ElevatedButton(
                                onPressed: _stopConversation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.8),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  '🛑 대화 그만할래요',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                          if (_isListening ||
                              _isThinking ||
                              _isPlaying ||
                              _isMicDisabled)
                            const SizedBox(height: 16),

                          const SizedBox(height: 24),

                          // 테스트용 로컬 스토리지 초기화 버튼
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            child: ElevatedButton(
                              onPressed: _resetLocalStorage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withOpacity(0.8),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    '🔄 로컬 스토리지 초기화 (테스트용)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          _micAutoStopHint(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 전역 미니 플레이어
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGlobalMiniPlayer(),
          ),
        ],
      ),
    );
  }
}

class _MiniSeekBar extends StatefulWidget {
  final just_audio.AudioPlayer player;
  const _MiniSeekBar({required this.player});

  @override
  State<_MiniSeekBar> createState() => _MiniSeekBarState();
}

class _MiniSeekBarState extends State<_MiniSeekBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  double _ratio(Duration pos, Duration? dur) {
    if (dur == null || dur.inMilliseconds <= 0) return 0.0;
    final r = pos.inMilliseconds / dur.inMilliseconds;
    if (r.isNaN || r.isInfinite) return 0.0;
    return r.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      initialData: widget.player.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = widget.player.duration;
        final value = _isDragging ? _dragValue : _ratio(pos, dur);

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            onChangeStart: (_) => setState(() => _isDragging = true),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) async {
              setState(() => _isDragging = false);
              if (dur != null) {
                final target = Duration(
                  milliseconds: (v * dur.inMilliseconds).round(),
                );
                await widget.player.seek(target);
              }
            },
          ),
        );
      },
    );
  }
}
