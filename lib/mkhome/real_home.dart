// lib/mkhome/real_home.dart
import 'dart:async';
import 'dart:io'; // ← 임시파일 폴백용
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
    with SingleTickerProviderStateMixin {
  // ── 자동 재생을 위한 조립 타이머 & 큐 ──────────────────────────────
  Timer? _assembleTimer;
  final Duration _assembleGap = const Duration(milliseconds: 350);
  final List<Uint8List> _pendingQueue = [];
  bool _isPreparing = false; // 파일 쓰기 중 재진입 방지
  bool _autoResumeMic = true; // 말 끝나면 자동 재시작할지
  DateTime _lastTtsAt = DateTime.fromMillisecondsSinceEpoch(0); // 마지막 TTS 수신 시각

  // 필드 추가
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _playerCompleteSub;
  bool _disposed = false;

  // ===== Speech & UI =====
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  String _username = '';
  bool _isLoggedIn = false;
  double _soundLevel = 0.0;

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
              '빨간 불일 때 3초간 말이 없으면 자동으로 꺼져요',
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
    _connectVoice();

    _chatBox = Hive.box<Message>('chatBox');

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
  }

  Future<void> _callUserProfile() async {
    try {
      final response = await apiClient.getJson('');
      print('👤 사용자 정보: $response');

      // 예: 이름 갱신
      if (mounted) {
        setState(() {
          _username = response['name'] ?? _username;
        });
      }
    } catch (e, stack) {
      print('❌ 사용자 정보 요청 실패: $e');
      print(stack);
    }
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

    if (reallyQuiet && !_isListening) {
      await _enterMicMode(); // 녹음 세션으로 전환(iOS 필수)
      await Future.delayed(const Duration(milliseconds: 80)); // 세션 전환 여유
      if (mounted && !_isListening) _listen();
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
        if (_isPlaying) _isThinking = false;
      });
    });

    _playerCompleteSub = _player.onPlayerComplete.listen((_) async {
      if (!mounted || _disposed) return;
      setState(() => _isPlaying = false);
      if (_pendingQueue.isNotEmpty) {
        _playNextFromQueue();
      } else {
        await _resumeMicIfQuiet();
      }
    });
  }

  // ===== 버퍼에 쌓인 MP3를 하나로 합쳐 재생 =====
  Future<void> _playBufferedAudio() async {
    if (_isListening) {
      _speech.stop();
      _stopListening();
    } // 마이크 중지
    // (선택) 필요하면 재생 세션 재적용:
    await _enterPlaybackMode();

    if (!_audioAvailable || _audioBuffer.isEmpty) {
      debugPrint('⚠️ 재생할 오디오가 없음');
      return;
    }

    try {
      // 1) 청크들을 하나로 합치기
      final chunks = _audioBuffer.length;
      final all = Uint8List.fromList(_audioBuffer.expand((c) => c).toList());
      debugPrint('▶️ 합친 MP3 크기: ${all.length} bytes');

      // 2) 재생 시작을 프레임 경계로 맞추기 (첫 청크가 프레임 중간일 수 있음)
      final start = _findFirstMpegSync(all);

      final trimmed = _stripToFirstMp3Frame(all);
      if (trimmed.isEmpty) {
        debugPrint('⚠️ MP3 프레임 동기를 찾지 못했습니다.');
        return;
      }

      // 3) 버퍼는 비우고 플래그 초기화
      _audioBuffer.clear();
      setState(() => _audioAvailable = false);

      // 4) 항상 임시파일로 저장 후 파일 소스로 재생 (iOS에서 가장 안정적)
      final path = await _writeTemp(trimmed, ext: 'mp3');
      debugPrint('🎧 play file: $path');
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('오디오 재생 실패: $e');
    }
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
      final token = await storage.read(key: 'jwt');
      if (token == null) {
        setState(() {
          _username = '';
          _isLoggedIn = false;
          _text = '';
        });
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
          setState(() {
            _username = name;
            _isLoggedIn = name.isNotEmpty;
            _text = '';
          });
        } else {
          setState(() {
            _username = '';
            _isLoggedIn = false;
            _text = '';
          });
        }
      } else {
        setState(() {
          _username = '';
          _isLoggedIn = false;
          _text = '';
        });
      }
    } catch (e) {
      debugPrint('[USERNAME] Error fetching username: $e');
      setState(() {
        _username = '';
        _isLoggedIn = false;
        _text = '';
      });
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

  // ===== 수면데이터 서버 전송 관련 함수들 =====

  // 수면데이터 서버 전송 시도
  Future<void> _tryUploadPendingSleepData() async {
    // 수면데이터 전송 관련 로직 제거
  }

  // 서버에서 수면데이터 가져오기
  Future<Map<String, dynamic>?> _getSleepDataFromServer({
    required String userId,
    required String token,
    required String date,
  }) async {
    // 수면데이터 전송 관련 로직 제거
    return null;
  }

  // ===== 기존 함수들 =====

  @override
  void dispose() {
    _serverDiscSub?.cancel();
    _connSub?.cancel();
    _disposed = true; // ✅ 가드 온
    _assembleTimer?.cancel(); // ✅ 타이머 취소
    _playerStateSub?.cancel(); // ✅ 구독 취소
    _playerCompleteSub?.cancel();

    _speech.cancel();
    _animationController.dispose();

    _assistantSub?.cancel();
    _transcriptSub?.cancel();
    _pcmSub?.cancel();

    _player.dispose();
    super.dispose();
  }

  // 메시지 저장 + 상단 텍스트 갱신
  void _addMessage(String sender, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _chatBox.add(Message(sender: sender, text: trimmed));
    if (sender == 'user') setState(() => _text = trimmed);
  }

  void _listen() async {
    if (!_isListening) {
      await _enterMicMode();
      await Future.delayed(const Duration(milliseconds: 80));

      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == "done") {
            final finalText = _text.trim();
            if (finalText.isNotEmpty) {
              setState(() => _isThinking = true); // ← 추가: 배너 켜기
              voiceService.sendText(finalText);
              _addMessage('user', finalText);
            }

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
      body: SafeArea(
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
                    if (_username.isNotEmpty) ...[
                      // 코알라 캐릭터 이미지
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 코알라 이미지
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(80),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'lib/assets/koala.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 24),
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
                                  '$_username님, 안녕하세요!',
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
                                color: const Color(0xFFFFD700).withOpacity(0.2),
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
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors:
                                            _isListening
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
                                          color: (_isListening
                                                  ? Colors.red
                                                  : const Color(0xFF6C63FF))
                                              .withOpacity(0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isListening ? Icons.stop : Icons.mic,
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
                                    _isListening
                                        ? const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _isListening
                                  ? '🎙️ 듣고 있어요...'
                                  : '🎤 마이크를 탭해서 대화 시작',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    _isListening
                                        ? const Color(0xFF6C63FF)
                                        : Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _micAutoStopHint(),
                    ] else ...[
                      // 로그인하지 않은 경우
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.login,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              '로그인이 필요합니다',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '코알라와 대화하려면\n먼저 로그인해주세요',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed:
                                  () => Navigator.pushNamed(context, '/login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '로그인하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
