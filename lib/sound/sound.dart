// 파일명: SoundScreen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/sound/why_recommended_page.dart';
import 'package:my_app/services/jwt_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// ==============================
/// 전역 사운드 서비스 (화면 이동해도 유지)
/// ==============================
class GlobalSoundService extends ChangeNotifier {
  static final GlobalSoundService _instance = GlobalSoundService._internal();
  factory GlobalSoundService() => _instance;

  final AudioPlayer player = AudioPlayer();

  // 자동 재생 콜백 함수 (이전 방식 유지하되, playlist 사용시 미사용)
  VoidCallback? _onSongFinished;
  // NEW: 미니플레이어에서 stop 눌렀다는 신호
  bool _autoplayStopRequested = false;

  // 자동재생 정지 상태 (사운드 화면에서 설정)
  bool _userStoppedAutoPlay = false;

  /// NEW: 미니플레이어에서 호출 — 재생 정지 + 자동재생도 중지 요청 브로드캐스트
  Future<void> stopFromMiniPlayer() async {
    await stop(); // 기존 stop() 호출로 플레이어 멈춤
    _autoplayStopRequested = true;
    notifyListeners(); // 화면들에게 알림
  }

  /// NEW: 화면에서 이 신호를 1회성으로 소비
  bool consumeAutoplayStopRequest() {
    if (_autoplayStopRequested) {
      _autoplayStopRequested = false;
      return true;
    }
    return false;
  }

  /// 자동재생 정지 상태 설정
  void setUserStoppedAutoPlay(bool stopped) {
    _userStoppedAutoPlay = stopped;
    // 정지 상태 설정 시에만 플레이어 정리
    if (stopped && _currentPlaying != null) {
      debugPrint('[GLOBAL_SOUND] 자동재생 정지 - 플레이어 정리');
      _currentPlaying = null;
      _isPlaying = false;
    }
    // 정지 해제 시에는 마지막 플레이리스트 복원
    else if (!stopped &&
        _lastPlaylistFiles != null &&
        _lastPlaylistFiles!.isNotEmpty) {
      debugPrint('[GLOBAL_SOUND] 자동재생 재개 - 플레이어 복원');
      _currentPlaying = _lastPlaylistFiles!.first;
      _isPlaying = false; // 재생은 하지 않고 표시만
    }
    notifyListeners();
  }

  /// 자동재생 정지 상태 확인
  bool get userStoppedAutoPlay => _userStoppedAutoPlay;

  // 노래 종료 감지를 위한 변수들
  Timer? _positionCheckTimer;
  Duration? _currentDuration;
  bool _callbackExecuted = false; // 중복 콜백 실행 방지

  // 재생 상태 변수들
  String? _currentPlaying;
  bool _isPlaying = false;

  // 플레이리스트 보조 상태
  ConcatenatingAudioSource? _playlistSource; // NEW: 현재 플레이리스트
  int? _currentIndex; // NEW: 현재 인덱스 캐시

  List<String>? _lastPlaylistFiles;

  // NEW: 현재 플레이리스트가 활성인지
  bool get hasActivePlaylist => _playlistSource != null;

  // NEW: 외부에서 비교할 때 씀 (읽기 전용)
  List<String> get lastPlaylistFiles =>
      List.unmodifiable(_lastPlaylistFiles ?? const <String>[]);

  // NEW: 동일 플레이리스트인지 비교
  bool isSamePlaylistAs(List<String> files) {
    final a = _lastPlaylistFiles;
    if (a == null || a.length != files.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != files[i]) return false;
    }
    return true;
  }

  // 플레이리스트 시작 시 마지막 리스트 저장
  Future<void> setPlaylistAndPlay(List<String> files) async {
    try {
      await player.stop();
      _playlistSource = ConcatenatingAudioSource(
        children:
            files.map((f) => AudioSource.asset('assets/sounds/$f')).toList(),
      );
      await player.setAudioSource(_playlistSource!, initialIndex: 0);
      await player.play();

      _isPlaying = true;
      _currentPlaying = files.isNotEmpty ? files.first : null;
      _callbackExecuted = false;

      // NEW: 마지막 플레이리스트 기록
      _lastPlaylistFiles = List.of(files);

      notifyListeners();
    } catch (e) {
      debugPrint('[GLOBAL_SOUND] setPlaylistAndPlay 오류: $e');
      rethrow;
    }
  }

  String? get currentPlaying => _currentPlaying;
  bool get isPlaying => _isPlaying;
  int? get currentIndex => _currentIndex;

  GlobalSoundService._internal() {
    // 상태 변화 구독
    player.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;

      // completed 상태에서 콜백 방식 사용 중이라면 보호적으로 호출
      if (state.processingState == ProcessingState.completed &&
          state.playing == false &&
          _currentPlaying != null &&
          !_callbackExecuted) {
        _callbackExecuted = true;
        _onSongFinished?.call();
      }

      // 노티
      if (wasPlaying != _isPlaying) {
        notifyListeners();
      }
    });

    // NEW: 현재 인덱스 추적 (플레이리스트용)
    // GlobalSoundService._internal() 안의 currentIndexStream 리스너 교체
    player.currentIndexStream.listen((i) {
      _currentIndex = i;
      if (i != null &&
          i >= 0 &&
          _lastPlaylistFiles != null &&
          i < _lastPlaylistFiles!.length) {
        _currentPlaying = _lastPlaylistFiles![i];
      }
      notifyListeners();
    });

    _startPositionCheck();
  }

  // 자동 재생 콜백 설정 (이전 방식과 호환)
  void setAutoPlayCallback(VoidCallback callback) {
    _onSongFinished = callback;
  }

  void clearAutoPlayCallback() {
    _onSongFinished = null;
  }

  void _startPositionCheck() {
    _positionCheckTimer?.cancel();
    // 더이상 사용 안 함
  }

  /// 단일 Asset 재생 (수동 재생용)
  Future<void> playAsset(String file) async {
    try {
      // NEW: playlist 모드에서 수동 재생 시 충돌 방지
      _playlistSource = null;

      // UI 업데이트를 위해 먼저 _currentPlaying 설정
      _currentPlaying = file;
      _isPlaying = true;
      _callbackExecuted = false;
      notifyListeners(); // 즉시 UI 업데이트

      await player.stop(); // pause 대신 stop으로 초기화가 안전
      await player.setAsset('assets/sounds/$file');
      await player.play();

      _currentDuration = player.duration;
      // 재생 시작 후 한 번 더 UI 업데이트
      notifyListeners();
    } catch (e) {
      debugPrint('[GLOBAL_SOUND] playAsset 실행 중 오류: $e');
      // 오류 발생 시 상태 초기화
      _currentPlaying = null;
      _isPlaying = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause() async {
    await player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await player.stop();
    _isPlaying = false;
    _currentPlaying = null; // 플레이어 숨기기 위해 null로 설정
    _currentDuration = null;
    _callbackExecuted = false;
    _playlistSource = null; // NEW
    // _lastPlaylistFiles는 유지 (플레이어 복원을 위해)
    notifyListeners();
  }

  @override
  void dispose() {
    _positionCheckTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  // 현재 재생 시간
  Duration? get currentPosition => player.position;

  // 총 재생 시간
  Duration? get duration => player.duration;

  // 특정 위치로 이동
  Future<void> seekTo(Duration position) async {
    try {
      await player.seek(position);
    } catch (e) {
      debugPrint('[GLOBAL_SOUND] 위치 이동 실패: $e');
    }
  }

  // 진행률 (0.0 ~ 1.0)
  double get progress {
    final current = currentPosition;
    final total = duration;
    if (current == null || total == null || total.inMilliseconds == 0) {
      return 0.0;
    }
    return (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// ==============================
/// 전역 미니 플레이어 (하단 고정)
/// ==============================
class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({super.key});

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  final GlobalSoundService service = GlobalSoundService();

  @override
  Widget build(BuildContext context) {
    if (service.currentPlaying == null || service.currentPlaying!.isEmpty) {
      return const SizedBox.shrink();
    }
    final title = service.currentPlaying!
        .replaceAll('.mp3', '')
        .replaceAll('_', ' ');
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
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
                      child: const Icon(Icons.music_note, color: Colors.white),
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
      ),
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
}

/// ==============================
/// 사운드 메인 화면
/// ==============================
Timer? _prefDebounce; // 슬라이더 PATCH 디바운스

class SoundScreen extends StatefulWidget {
  const SoundScreen({Key? key}) : super(key: key);

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  final GlobalSoundService sound = GlobalSoundService();
  // NEW: 서비스 변경 리스너
  void _onSoundServiceChanged() {
    if (!mounted) return;

    // 미니 플레이어에서 stop 누른 신호가 오면 자동재생도 끔
    if (sound.consumeAutoplayStopRequest()) {
      setState(() {
        _isAutoPlaying = false;
        _userStoppedAutoPlay = true;
      });
    }
    // 기존처럼 UI도 갱신
    setState(() {});
  }

  Timer? _execDebounce;
  bool executing = false;

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  double preferenceRatio = 0.75;

  String? recommendationText; // 서버가 내려주는 recommendation_text
  List<String> topRecommended = [];
  bool _isLoadingRecommendations = false;
  String? userId;
  bool authReady = false;
  DateTime recDate = DateTime(2025, 8, 12);
  bool _argsApplied = false;

  List<String> soundFiles = [
    "NATURE_1_WATER.mp3",
    "NATURE_2_MORNINGBIRDS.mp3",
    "NATURE_3_CRICKETS.mp3",
    "NATURE_4_CAVE_DROPLETS.mp3",
    "PINK_1_WIND.mp3",
    "PINK_2_RAIN.mp3",
    "PINK_3_RAIN_THUNDER.mp3",
    "PINK_4_WAVE.mp3",
    "WHITE_1.mp3",
    "WHITE_2_UNDERWATER.mp3",
    "ASMR_1_BOOK.mp3",
    "ASMR_2_HAIR.mp3",
    "ASMR_3_TAPPING.mp3",
    "ALPHA_1.mp3",
    "ALPHA_2.mp3",
    "FIRE_1.mp3",
    "FIRE_2.mp3",
    "LOFI_1.mp3",
    "LOFI_2.mp3",
    "MEDIT_1_TEMPLE.mp3",
    "MEDIT_2_MUSIC.mp3",
  ];

  final Map<String, Map<String, String>> metadata = {
    "NATURE_1_WATER.mp3": {
      "feature": "계곡물 흐름",
      "effect": "청량감, 이완 효과",
      "target": "긴장 완화가 필요한 사용자",
      "tags": "stream, water, nature, calm",
    },
    "NATURE_2_MORNINGBIRDS.mp3": {
      "feature": "아침 숲과 새소리",
      "effect": "긍정 감정 유도, 기분 전환",
      "target": "불안감 해소가 필요한 사용자",
      "tags": "birds, morning, forest, fresh",
    },
    "NATURE_3_CRICKETS.mp3": {
      "feature": "밤의 벌레소리",
      "effect": "정서적 고요함",
      "target": "정적인 소리를 선호하는 사용자",
      "tags": "crickets, night, nature, insects",
    },
    "NATURE_4_CAVE_DROPLETS.mp3": {
      "feature": "동굴 속 물방울",
      "effect": "미세 반복 소리로 집중 분산",
      "target": "자극에 민감한 사용자",
      "tags": "water, droplet, cave, minimal",
    },
    "PINK_1_WIND.mp3": {
      "feature": "나뭇잎 바람소리",
      "effect": "저주파 반복으로 뇌파 안정",
      "target": "스트레스 해소가 필요한 사용자",
      "tags": "wind, leaves, pink noise, soothing",
    },
    "PINK_2_RAIN.mp3": {
      "feature": "창문 밖 잔잔한 비",
      "effect": "수면 유도 저주파",
      "target": "수면 유도/귀 민감한 사용자",
      "tags": "rain, window, pink noise, gentle",
    },
    "PINK_3_RAIN_THUNDER.mp3": {
      "feature": "천둥 동반한 비소리",
      "effect": "몰입감 있는 리듬, 소음 차단",
      "target": "강한 자극으로 안정을 원하는 사용자",
      "tags": "rain, thunder, pink noise, deep",
    },
    "PINK_4_WAVE.mp3": {
      "feature": "잔잔한 파도",
      "effect": "정서적 안정감, 시각적 심상 자극",
      "target": "감정 진정이 필요한 사용자",
      "tags": "wave, ocean, natural, relaxing",
    },
    "WHITE_1.mp3": {
      "feature": "기본 백색소음",
      "effect": "외부 소음 마스킹",
      "target": "소리에 쉽게 깨는 사용자",
      "tags": "white noise, masking, neutral, steady",
    },
    "WHITE_2_UNDERWATER.mp3": {
      "feature": "수중 백색소음",
      "effect": "저음 중심 마스킹",
      "target": "도시소음 차단 목적 사용자",
      "tags": "white noise, underwater, subtle, ambient",
    },
    "ASMR_1_BOOK.mp3": {
      "feature": "책장 넘기는 소리",
      "effect": "촉각적 안정감",
      "target": "ASMR 감각에 민감한 사용자",
      "tags": "page, turning, paper, repetitive",
    },
    "ASMR_2_HAIR.mp3": {
      "feature": "머리카락 빗는 소리",
      "effect": "두피 자극 연상, 안정감 유도",
      "target": "촉각 감각 민감한 사용자",
      "tags": "brushing, hair, gentle, tingling",
    },
    "ASMR_3_TAPPING.mp3": {
      "feature": "손가락 두드림",
      "effect": "리드미컬한 감각 자극",
      "target": "짧은 자극성 소리 선호 사용자",
      "tags": "tapping, fingers, rhythm, soothing",
    },
    "ALPHA_1.mp3": {
      "feature": "432Hz 알파파 음악 1",
      "effect": "뇌파 안정, 깊은 수면 유도",
      "target": "스트레스/수면 장애 있는 사용자",
      "tags": "432hz, alpha wave, binaural, healing",
    },
    "ALPHA_2.mp3": {
      "feature": "432Hz 알파파 음악 2",
      "effect": "심신 이완, 정신적 안정",
      "target": "이완 명상 선호 사용자",
      "tags": "432hz, alpha, calming, meditation",
    },
    "FIRE_1.mp3": {
      "feature": "모닥불 소리",
      "effect": "심리적 따뜻함 제공",
      "target": "공간적 안정감 원하는 사용자",
      "tags": "fire, campfire, crackling, warmth",
    },
    "FIRE_2.mp3": {
      "feature": "자작나무 타는 소리",
      "effect": "부드러운 리듬과 따뜻함",
      "target": "정서 안정에 민감한 사용자",
      "tags": "fire, birch, soothing, crackling",
    },
    "LOFI_1.mp3": {
      "feature": "굿나잇 로파이",
      "effect": "감정 안정, 수면 전 진정",
      "target": "생각이 많아 잠들기 어려운 사용자",
      "tags": "lofi, chill, sleep, night",
    },
    "LOFI_2.mp3": {
      "feature": "비 오는 도시 로파이",
      "effect": "차분한 분위기 조성",
      "target": "혼자 있는 듯한 고요한 느낌 원하는 사용자",
      "tags": "lofi, rain, city, calm",
    },
    "MEDIT_1_TEMPLE.mp3": {
      "feature": "사찰 풍경소리",
      "effect": "영적 안정감, 고요함",
      "target": "명상 선호 사용자",
      "tags": "temple, bell, meditation, calming",
    },
    "MEDIT_2_MUSIC.mp3": {
      "feature": "명상 배경음",
      "effect": "뇌파 진정 및 깊은 이완",
      "target": "명상과 수면 전 루틴 필요한 사용자",
      "tags": "meditation, ambient, healing, sleep",
    },
  };

  // 자동 재생 관련 변수들
  Timer? _autoPlayTimer;
  int _currentAutoPlayIndex = 0;
  List<String> _autoPlayQueue = [];
  bool _isAutoPlaying = false;
  bool _userStoppedAutoPlay = false;
  bool _autoplayStopRequested = false;

  StreamSubscription<int?>? _indexSub; // NEW: 현재 인덱스 구독

  @override
  void initState() {
    super.initState();
    sound.addListener(_onSoundServiceChanged);

    // NEW: 플레이리스트 인덱스 구독 → UI 업데이트
    _indexSub = sound.player.currentIndexStream.listen((i) {
      if (!mounted) return;
      if (i == null) return;
      setState(() {
        _currentAutoPlayIndex = i;
        // 현재 재생 파일명도 동기화
        if (_autoPlayQueue.isNotEmpty && i >= 0 && i < _autoPlayQueue.length) {
          sound._currentPlaying = _autoPlayQueue[i]; // 표시용
        }
      });
    });

    // 화면 진입 시 상태 초기화 (재생 중인 사운드가 없을 때만)
    _resetAutoPlayState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    _argsApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    Future.microtask(() async {
      try {
        // 날짜 반영
        if (args is Map) {
          final d = args['date'];
          if (d is String && d.isNotEmpty) {
            final parsed = DateTime.tryParse(d);
            if (parsed != null) recDate = parsed;
          } else if (d is DateTime) {
            recDate = d;
          }
        } else {
          recDate = DateTime.now();
        }

        // userId 확정
        final ensured = await _ensureUserId();
        var finalId = ensured;

        if (args is Map &&
            args['userId'] is String &&
            (args['userId'] as String).isNotEmpty) {
          final fromArgs = (args['userId'] as String).trim();
          if (fromArgs == ensured) {
            finalId = fromArgs;
          }
        }

        setState(() {
          userId = finalId;
          authReady = true;
        });

        // 페이지 접속 시 자동으로 서버에서 추천 사운드 가져오기
        _loadRecommendations();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다. 다시 로그인해주세요.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _prefDebounce?.cancel();
    _execDebounce?.cancel();
    _autoPlayTimer?.cancel();

    sound.clearAutoPlayCallback();
    _indexSub?.cancel(); // NEW

    // 화면 종료 시에는 자동재생 상태만 정리하고 재생 중인 사운드는 유지
    _isAutoPlaying = false;
    // _userStoppedAutoPlay는 유지 (사용자가 정지한 상태라면 유지)
    // _autoPlayQueue는 유지 (재생 중인 플레이리스트 정보 유지)
    // _currentAutoPlayIndex는 유지 (현재 재생 위치 유지)
    // sound.setUserStoppedAutoPlay()는 호출하지 않음 (기존 상태 유지)

    sound.removeListener(_onSoundServiceChanged);

    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    try {
      final isLoggedIn = await JwtUtils.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('JWT 토큰이 유효하지 않습니다. 다시 로그인해주세요.');
      }

      String? raw = await storage.read(key: 'jwt');
      if (raw == null || raw.trim().isEmpty) {
        throw Exception('JWT가 없습니다. 다시 로그인해주세요.');
      }

      final tokenOnly =
          raw.startsWith(RegExp(r'Bearer\s', caseSensitive: false))
              ? raw.split(' ').last
              : raw;
      final bearer = 'Bearer $tokenOnly';

      return {
        'Authorization': bearer,
        HttpHeaders.authorizationHeader: bearer,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
    } catch (e) {
      throw Exception('인증 헤더 생성 실패: $e');
    }
  }

  // 추천 실행
  Future<void> _executeRecommendation() async {
    if (userId == null) return;

    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://kooala.tassoo.uk/recommend-sound/execute'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
        },
        body: jsonEncode({
          'userID': userId,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'soundRecommendationRequested',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        await Future.delayed(const Duration(seconds: 3));
        try {
          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final resultsResponse = await http.get(
            Uri.parse(
              'https://kooala.tassoo.uk/recommend-sound/$userId/$dateStr/results',
            ),
            headers: {
              'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
            },
          );

          if (resultsResponse.statusCode == 200) {
            final data = jsonDecode(resultsResponse.body);
            if (data['recommended_sounds'] != null) {
              final recommendations = data['recommended_sounds'] as List;
              setState(() {
                topRecommended =
                    recommendations
                        .where(
                          (item) =>
                              item is Map<String, dynamic> &&
                              item['filename'] != null &&
                              item['filename'].toString().isNotEmpty,
                        )
                        .map((item) => item['filename'].toString())
                        .toList();
                _isLoadingRecommendations = false;
              });

              // 추천 실행 완료 후 자동재생 시작 (정지 상태 무시)
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  debugPrint('[AUTOPLAY] 추천 실행 완료 - 자동재생 시작 시도');
                  // 이미 재생 중인 사운드가 없을 때만 자동재생 시작
                  if (!sound.isPlaying || sound.currentPlaying == null) {
                    _startAutoPlay();
                  } else {
                    debugPrint('[AUTOPLAY] 이미 재생 중인 사운드가 있어서 자동재생 시작 안함');
                  }
                }
              });
            } else {
              setState(() {
                _isLoadingRecommendations = false;
              });
            }
          } else {
            setState(() {
              _isLoadingRecommendations = false;
            });
          }
        } catch (e) {
          setState(() {
            _isLoadingRecommendations = false;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('추천이 성공적으로 실행되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('추천 실행 실패: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추천 실행 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  // 추천 사운드 로드
  Future<void> _loadRecommendations() async {
    try {
      setState(() {
        _isLoadingRecommendations = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final recommendationRequested = prefs.getString(
        'soundRecommendationRequested',
      );
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (recommendationRequested == today) {
        final savedRecommendations = prefs.getString('soundRecommendations');
        final savedDate = prefs.getString('soundRecommendationsDate');

        if (savedRecommendations != null && savedDate == today) {
          try {
            final recommendations = jsonDecode(savedRecommendations) as List;

            // 랭킹순으로 정렬 (rank 필드가 있으면 사용, 없으면 순서대로)
            final sortedRecommendations =
                recommendations
                    .where(
                      (item) =>
                          item is Map<String, dynamic> &&
                          item['filename'] != null &&
                          item['filename'].toString().isNotEmpty,
                    )
                    .toList();

            // rank 필드가 있으면 랭킹순으로 정렬, 없으면 기존 순서 유지
            if (sortedRecommendations.isNotEmpty &&
                sortedRecommendations.first.containsKey('rank')) {
              sortedRecommendations.sort((a, b) {
                final rankA = a['rank'] as int? ?? 999;
                final rankB = b['rank'] as int? ?? 999;
                return rankA.compareTo(rankB);
              });
            }

            setState(() {
              topRecommended =
                  sortedRecommendations
                      .map((item) => item['filename'].toString())
                      .toList();
              // soundFiles도 추천 순서로 업데이트
              soundFiles.clear();
              soundFiles.addAll(topRecommended);
              _isLoadingRecommendations = false;
            });

            // 추천 로드 완료 후 자동재생 시작 (정지 상태 무시)
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                debugPrint('[AUTOPLAY] 추천 로드 완료 - 자동재생 시작 시도');
                // 이미 재생 중인 사운드가 없을 때만 자동재생 시작
                if (!sound.isPlaying || sound.currentPlaying == null) {
                  _startAutoPlay();
                } else {
                  debugPrint('[AUTOPLAY] 이미 재생 중인 사운드가 있어서 자동재생 시작 안함');
                }
              }
            });
            return;
          } catch (_) {}
        }
      }

      // 새 요청
      await _requestNewRecommendation();
    } catch (e) {
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  // 새로운 추천 요청
  Future<void> _requestNewRecommendation() async {
    try {
      final response = await http.post(
        Uri.parse('https://kooala.tassoo.uk/recommend-sound/execute'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
        },
        body: jsonEncode({
          'userID': userId,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'soundRecommendationRequested',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );

        await Future.delayed(const Duration(seconds: 3));

        try {
          final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final resultsResponse = await http.get(
            Uri.parse(
              'https://kooala.tassoo.uk/recommend-sound/$userId/$dateStr/results',
            ),
            headers: {
              'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
            },
          );

          if (resultsResponse.statusCode == 200) {
            final data = jsonDecode(resultsResponse.body);
            if (data['recommended_sounds'] != null) {
              final recommendations = data['recommended_sounds'] as List;

              // 랭킹순으로 정렬 (rank 필드가 있으면 사용, 없으면 순서대로)
              final sortedRecommendations =
                  recommendations
                      .where(
                        (item) =>
                            item is Map<String, dynamic> &&
                            item['filename'] != null &&
                            item['filename'].toString().isNotEmpty,
                      )
                      .toList();

              // rank 필드가 있으면 랭킹순으로 정렬, 없으면 기존 순서 유지
              if (sortedRecommendations.isNotEmpty &&
                  sortedRecommendations.first.containsKey('rank')) {
                sortedRecommendations.sort((a, b) {
                  final rankA = a['rank'] as int? ?? 999;
                  final rankB = b['rank'] as int? ?? 999;
                  return rankA.compareTo(rankB);
                });
              }

              setState(() {
                topRecommended =
                    sortedRecommendations
                        .map((item) => item['filename'].toString())
                        .toList();
                // soundFiles도 추천 순서로 업데이트
                soundFiles.clear();
                soundFiles.addAll(topRecommended);
                _isLoadingRecommendations = false;
              });

              // 추천 사운드를 랭킹 정보와 함께 저장
              await prefs.setString(
                'soundRecommendations',
                jsonEncode(sortedRecommendations),
              );
              await prefs.setString(
                'soundRecommendationsDate',
                DateFormat('yyyy-MM-dd').format(DateTime.now()),
              );

              // 새 추천 로드 완료 후 자동재생 시작 (정지 상태 무시)
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  debugPrint('[AUTOPLAY] 새 추천 로드 완료 - 자동재생 시작 시도');
                  // 이미 재생 중인 사운드가 없을 때만 자동재생 시작
                  if (!sound.isPlaying || sound.currentPlaying == null) {
                    _startAutoPlay();
                  } else {
                    debugPrint('[AUTOPLAY] 이미 재생 중인 사운드가 있어서 자동재생 시작 안함');
                  }
                }
              });
            } else {
              setState(() {
                _isLoadingRecommendations = false;
              });
            }
          } else {
            setState(() {
              _isLoadingRecommendations = false;
            });
          }
        } catch (e) {
          setState(() {
            _isLoadingRecommendations = false;
          });
        }
      } else {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  Future<void> _patchPreferenceBalance(double balance) async {
    if (userId == null) return;
    try {
      final url = Uri.parse('https://kooala.tassoo.uk/users/survey/modify');
      final headers = await _authHeaders();
      final payload = {
        "userID": userId,
        "preferenceBalance": double.parse(balance.toStringAsFixed(2)),
      };

      final resp = await http.patch(
        url,
        headers: headers,
        body: json.encode(payload),
      );

      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('설정 저장 중 오류: $e')));
      }
    }
  }

  void _debouncedPrefUpdate() {
    _prefDebounce?.cancel();
    final value = preferenceRatio;
    _prefDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _patchPreferenceBalance(value);
      await _executeRecommendation();
    });
  }

  // 자동재생 상태 초기화
  void _resetAutoPlayState() {
    // 이미 재생 중인 사운드가 있으면 상태 초기화하지 않음
    if (sound.isPlaying && sound.currentPlaying != null) {
      debugPrint(
        '[AUTOPLAY] 이미 재생 중인 사운드가 있어서 상태 초기화 안함: ${sound.currentPlaying}',
      );
      return;
    }

    _userStoppedAutoPlay = false;
    _isAutoPlaying = false;
    _autoPlayQueue.clear();
    _currentAutoPlayIndex = 0;
    sound.setUserStoppedAutoPlay(false);
    debugPrint('[AUTOPLAY] 상태 초기화 완료 - 자동재생 가능 상태로 복원');
  }

  List<String> _buildAutoQueue() {
    final top3 = topRecommended.take(3).toList();
    return [...top3, ...top3]; // TOP3 × 2바퀴
  }

  /// ==============================
  /// 자동 재생 시작 (정지 상태 무시)
  /// ==============================
  void _startAutoPlay() async {
    if (!mounted) return;
    if (topRecommended.isEmpty) {
      debugPrint('[AUTOPLAY] 추천 사운드가 없어서 자동재생 시작 안함');
      return;
    }

    // 이미 자동재생 중이면 중복 시작 방지
    if (_isAutoPlaying) {
      debugPrint('[AUTOPLAY] 이미 자동재생 중이므로 시작 안함');
      return;
    }

    // 이미 재생 중인 사운드가 있으면 새로 시작하지 않음
    if (sound.isPlaying && sound.currentPlaying != null) {
      debugPrint(
        '[AUTOPLAY] 이미 재생 중인 사운드가 있어서 새로 시작하지 않음: ${sound.currentPlaying}',
      );
      // 기존 재생 상태를 그대로 유지하고 아무것도 하지 않음
      return;
    }

    debugPrint('[AUTOPLAY] 자동재생 시작 (정지 상태 무시)');

    final queue = _buildAutoQueue();
    _isAutoPlaying = true;
    _autoPlayQueue = queue;
    _currentAutoPlayIndex = 0;

    sound.clearAutoPlayCallback();
    await sound.setPlaylistAndPlay(_autoPlayQueue);

    // 정지 상태 강제 해제 (플레이어 설정 후)
    _userStoppedAutoPlay = false;
    sound.setUserStoppedAutoPlay(false);

    // 상태 변경이 완전히 반영되도록 약간의 지연
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      setState(() {});
    }
  }

  // 자동 재생 중지
  void _stopAutoPlay() {
    debugPrint('[AUTOPLAY] 자동재생 중지');

    _isAutoPlaying = false;
    _userStoppedAutoPlay = true;
    _autoPlayTimer?.cancel();
    sound.clearAutoPlayCallback();

    // 플레이어 완전 정지 (플레이어도 사라지게)
    sound.stop();

    // GlobalSoundService에 자동재생 정지 상태 전달
    sound.setUserStoppedAutoPlay(true);

    // UI 즉시 업데이트
    setState(() {});
  }

  // 사용자가 수동으로 사운드 재생
  Future<void> _playSound(String file) async {
    debugPrint('[AUTOPLAY] 수동 재생: $file');

    // 자동재생 중지
    _isAutoPlaying = false;
    _userStoppedAutoPlay = true;
    sound.setUserStoppedAutoPlay(true);

    // 수동 재생
    await sound.playAsset(file);

    if (mounted) {
      setState(() {});
    }
  }

  void _debouncedExecute() {
    _execDebounce?.cancel();
    _execDebounce = Timer(const Duration(milliseconds: 350), () {
      _executeRecommendation();
    });
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<String> _ensureUserId() async {
    try {
      final isLoggedIn = await JwtUtils.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('JWT 토큰이 유효하지 않습니다. 다시 로그인해주세요.');
      }

      final fromJwt = await JwtUtils.getCurrentUserId();
      if (fromJwt != null && fromJwt.isNotEmpty) {
        await storage.write(key: 'userID', value: fromJwt);
        await storage.write(key: 'userId', value: fromJwt);
        return fromJwt.trim();
      }

      String? fromStorage =
          await storage.read(key: 'userID') ??
          await storage.read(key: 'userId');

      if (fromStorage != null && fromStorage.trim().isNotEmpty) {
        return fromStorage.trim();
      }

      throw Exception('userID를 찾을 수 없습니다. 다시 로그인해주세요.');
    } catch (e) {
      throw Exception('사용자 인증에 실패했습니다: $e');
    }
  }

  Future<void> _savePreferredSoundsRank() async {
    try {
      final url = Uri.parse(
        'https://kooala.tassoo.uk/users/modify/preferred/sounds/rank',
      );
      final headers = await _authHeaders();

      final preferred = <Map<String, dynamic>>[
        for (int i = 0; i < soundFiles.length; i++)
          {"filename": soundFiles[i], "rank": i + 1},
      ];

      final body = json.encode({"preferredSounds": preferred});

      debugPrint('[SOUND_RANK] 사운드 순서 변경 중...');
      debugPrint(
        '[SOUND_RANK] 새로운 순서: ${preferred.map((e) => '${e['rank']}: ${e['filename']}').join(', ')}',
      );

      final resp = await http.patch(url, headers: headers, body: body);

      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint(
          '[SOUND_RANK] ❌ 서버 응답 오류: HTTP ${resp.statusCode}: ${resp.body}',
        );
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
      debugPrint('[SOUND_RANK] ✅ 사운드 순서 저장 성공');
    } catch (e) {
      debugPrint('[SOUND_RANK] ❌ 사운드 순서 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('정렬 저장 실패: $e')));
      }
    }
  }

  // 현재 재생 중인 노래의 순위 계산
  int _getCurrentSongRank() {
    if (_autoPlayQueue.isEmpty ||
        _currentAutoPlayIndex >= _autoPlayQueue.length) {
      return 0;
    }
    final actualIndex = _currentAutoPlayIndex % 3; // TOP3 기준
    return actualIndex + 1;
  }

  // 현재 재생 중인 노래의 바퀴 수 계산
  int _getCurrentRound() {
    if (_autoPlayQueue.isEmpty ||
        _currentAutoPlayIndex >= _autoPlayQueue.length) {
      return 0;
    }
    return (_currentAutoPlayIndex ~/ 3) + 1;
  }

  @override
  Widget build(BuildContext context) {
    if (!authReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '수면 사운드',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 섹션
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
                          color: const Color(0xFF6C63FF).withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.music_note, color: Colors.white, size: 32),
                        SizedBox(height: 16),
                        Text(
                          '수면을 위한 완벽한 사운드',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'AI가 추천하는 맞춤형 수면 사운드로\n편안한 잠을 경험해보세요',
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

                  // AI 추천 비율 슬라이더
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
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFF6C63FF),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "AI 추천 비율 조정",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF6C63FF),
                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                            thumbColor: const Color(0xFF6C63FF),
                            overlayColor: const Color(
                              0xFF6C63FF,
                            ).withOpacity(0.2),
                            valueIndicatorColor: const Color(0xFF6C63FF),
                            valueIndicatorTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Slider(
                            value: preferenceRatio,
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label: "${(preferenceRatio * 100).toInt()}%",
                            onChanged: (value) {
                              setState(() => preferenceRatio = value);
                              _debouncedPrefUpdate();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "내가 좋아하는 소리를\n더 추천해주세요",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                            Text(
                              "수면 데이터에 맞춰\n추천해주세요",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 추천 결과 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isLoadingRecommendations
                                    ? "추천 불러오는 중..."
                                    : "오늘의 추천 사운드를 받아보세요",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 🎵 자동 재생 상태 표시 및 제어
                        if (!_userStoppedAutoPlay) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  _isAutoPlaying
                                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                                      : const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    _isAutoPlaying
                                        ? const Color(0xFF4CAF50)
                                        : const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isAutoPlaying
                                          ? Icons.play_circle
                                          : Icons.pause_circle,
                                      color:
                                          _isAutoPlaying
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFF6C63FF),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isAutoPlaying
                                            ? '자동 재생 중... (${_currentAutoPlayIndex + 1}/${_autoPlayQueue.length})'
                                            : '자동 재생 준비 완료',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              _isAutoPlaying
                                                  ? const Color(0xFF4CAF50)
                                                  : Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!_isAutoPlaying) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    '추천사운드 TOP3 2바퀴 자동 재생',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                                if (_isAutoPlaying) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '추천사운드 ${_getCurrentSongRank()}위 재생 중 (${_getCurrentRound()}바퀴)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '현재: ${_autoPlayQueue.isNotEmpty && _currentAutoPlayIndex < _autoPlayQueue.length ? _autoPlayQueue[_currentAutoPlayIndex].replaceAll('.mp3', '').replaceAll('_', ' ') : ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (_isAutoPlaying) ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _stopAutoPlay,
                                          icon: const Icon(
                                            Icons.stop,
                                            size: 16,
                                          ),
                                          label: const Text('자동 재생 중지'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFE57373,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _startAutoPlay,
                                          icon: const Icon(
                                            Icons.play_arrow,
                                            size: 16,
                                          ),
                                          label: const Text('자동 재생 시작'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF4CAF50,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ✅ "왜 사운드를 추천하나요?" 버튼
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final uid = userId;
                              if (uid == null) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => WhyRecommendedPage(
                                        userId: userId!,
                                        date: recDate,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.help_outline,
                              color: Colors.white,
                            ),
                            label: const Text(
                              '왜 사운드를 추천하나요?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 6,
                              shadowColor: const Color(
                                0xFF6C63FF,
                              ).withOpacity(0.3),
                            ),
                          ),
                        ),

                        if (topRecommended.isNotEmpty) ...[
                          const SizedBox(height: 16),

                          // 추천 사운드 상위 3개 표시
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C63FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      '오늘의 추천 사운드 TOP 3',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // 상위 3개 사운드 카드
                                ...topRecommended.take(3).map((filename) {
                                  final index =
                                      topRecommended.indexOf(filename) + 1;
                                  final name = filename
                                      .replaceAll('.mp3', '')
                                      .replaceAll('_', ' ');
                                  final data = metadata[filename];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors:
                                            index == 1
                                                ? [
                                                  Color(0xFFFFD700),
                                                  Color(0xFFFFA500),
                                                ]
                                                : index == 2
                                                ? [
                                                  Color(0xFFC0C0C0),
                                                  Color(0xFFA0A0A0),
                                                ]
                                                : [
                                                  Color(0xFFCD7F32),
                                                  Color(0xFFB8860B),
                                                ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (index == 1
                                                  ? const Color(0xFFFFD700)
                                                  : index == 2
                                                  ? const Color(0xFFC0C0C0)
                                                  : const Color(0xFFCD7F32))
                                              .withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // 순위 배지
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color:
                                                index == 1
                                                    ? const Color(
                                                      0xFFFFD700,
                                                    ).withOpacity(0.9)
                                                    : index == 2
                                                    ? const Color(
                                                      0xFFC0C0C0,
                                                    ).withOpacity(0.9)
                                                    : const Color(
                                                      0xFFCD7F32,
                                                    ).withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$index',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              if (data != null) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  "• ${data["feature"]}",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                Text(
                                                  "• ${data["effect"]}",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            sound.currentPlaying == filename &&
                                                    sound.isPlaying
                                                ? Icons.pause_circle
                                                : Icons.play_circle,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          onPressed: () => _playSound(filename),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ] else ...[
                          // 추천 사운드가 로드되기 전까지 안내 메시지
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1E33).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.hourglass_empty,
                                        color: Color(0xFF6C63FF),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '오늘의 추천사운드 TOP3가 준비중입니다! 조금만 기다려주세요:)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        const Color(0xFF6C63FF),
                                      ),
                                      backgroundColor: const Color(
                                        0xFF6C63FF,
                                      ).withOpacity(0.2),
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

                  const SizedBox(height: 24),

                  // 사운드 목록
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
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.library_music,
                                color: Color(0xFF4CAF50),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "사운드 목록",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 드래그 앤 드롭 안내
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.drag_handle,
                                color: const Color(0xFF6C63FF),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '사운드를 2초동안 꾹 누르면 드래그해서 순서를 변경할 수 있습니다. 변경된 순서는 자동으로 사용자 선호도 데이터로 사용됩니다.',
                                  style: TextStyle(
                                    color: const Color(0xFF6C63FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 사운드 카드들
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: soundFiles.length,
                          onReorder: (oldIndex, newIndex) {
                            debugPrint(
                              '[SOUND_REORDER] ReorderableListView 순서 변경: $oldIndex → $newIndex',
                            );
                            setState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = soundFiles.removeAt(oldIndex);
                              soundFiles.insert(newIndex, item);
                            });

                            _savePreferredSoundsRank();
                          },
                          itemBuilder: (context, i) {
                            final file = soundFiles[i];
                            final name = file
                                .replaceAll('.mp3', '')
                                .replaceAll('_', ' ');
                            final selected = sound.currentPlaying == file;
                            final data = metadata[file];

                            return Container(
                              key: ValueKey(file),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.2)
                                        : const Color(0xFF0A0E21),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      selected
                                          ? const Color(0xFF6C63FF)
                                          : Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // 드래그 핸들 아이콘
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.drag_handle,
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            selected
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (data != null) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  "• ${data["feature"]}",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                Text(
                                                  "• ${data["effect"]}",
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            selected && sound.isPlaying
                                                ? Icons.pause_circle
                                                : Icons.play_circle,
                                            size: 32,
                                            color:
                                                selected
                                                    ? const Color(0xFF6C63FF)
                                                    : Colors.white70,
                                          ),
                                          onPressed: () => _playSound(file),
                                        ),
                                      ],
                                    ),
                                    if (data != null) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children:
                                            data["tags"]!
                                                .split(',')
                                                .map(
                                                  (tag) => Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF6C63FF,
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFF6C63FF,
                                                        ).withOpacity(0.3),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '#${tag.trim()}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF6C63FF,
                                                        ),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 전역 미니 플레이어
          GlobalMiniPlayer(),
        ],
      ),
    );
  }
}

/// ==============================
/// 진행바(미니) 위젯: 스트림 기반, 드래그 종료 시에만 seek
/// ==============================
class _MiniSeekBar extends StatefulWidget {
  final AudioPlayer player;
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
