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

  // 자동 재생 콜백 함수
  VoidCallback? _onSongFinished;

  // 노래 종료 감지를 위한 변수들
  Timer? _positionCheckTimer;
  Duration? _currentDuration;
  bool _callbackExecuted = false; // 중복 콜백 실행 방지

  // 재생 상태 변수들
  String? _currentPlaying;
  bool _isPlaying = false;

  String? get currentPlaying => _currentPlaying;
  bool get isPlaying => _isPlaying;

  GlobalSoundService._internal() {
    player.playerStateStream.listen((state) {
      debugPrint(
        '[GLOBAL_SOUND] playerState 변경: playing=${state.playing}, processingState=${state.processingState}',
      );

      // 이전 상태와 비교하여 변화 감지
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;

      if (wasPlaying != _isPlaying) {
        debugPrint('[GLOBAL_SOUND] 재생 상태 변화: $wasPlaying -> $_isPlaying');
      }

      // 노래가 끝났는지 간단하게 확인
      if (state.processingState == ProcessingState.completed &&
          state.playing == false &&
          _currentPlaying != null &&
          !_callbackExecuted) {
        debugPrint('[GLOBAL_SOUND] 노래 종료 감지됨!');
        debugPrint('[GLOBAL_SOUND] _currentPlaying: $_currentPlaying');
        debugPrint('[GLOBAL_SOUND] _callbackExecuted: $_callbackExecuted');
        debugPrint(
          '[GLOBAL_SOUND] _onSongFinished: ${_onSongFinished != null ? "설정됨" : "설정되지 않음"}',
        );
        debugPrint(
          '[GLOBAL_SOUND] playerState: playing=${state.playing}, processingState=${state.processingState}',
        );

        // _currentPlaying은 다음 노래가 시작될 때까지 유지 (플레이어 표시용)
        // _currentDuration = null; // 이 줄 제거
        _callbackExecuted = true;

        // 노래가 끝났을 때 자동 재생 콜백 실행
        if (_onSongFinished != null) {
          debugPrint('[GLOBAL_SOUND] 노래 종료 감지 - 콜백 실행 시작');
          try {
            _onSongFinished!();
            debugPrint('[GLOBAL_SOUND] 콜백 실행 완료');
          } catch (e) {
            debugPrint('[GLOBAL_SOUND] 콜백 실행 중 오류: $e');
          }
        } else {
          debugPrint('[GLOBAL_SOUND] 콜백이 설정되지 않음 - 다음 노래 재생 불가');
        }
      } else if (state.processingState == ProcessingState.completed &&
          state.playing == false) {
        debugPrint('[GLOBAL_SOUND] 노래 종료 조건 불만족:');
        debugPrint('[GLOBAL_SOUND] _currentPlaying: $_currentPlaying');
        debugPrint('[GLOBAL_SOUND] _callbackExecuted: $_callbackExecuted');
        debugPrint(
          '[GLOBAL_SOUND] _onSongFinished: ${_onSongFinished != null ? "설정됨" : "설정되지 않음"}',
        );
      }

      notifyListeners();
    });

    // position 체크 타이머로 더 정확한 노래 종료 감지
    _startPositionCheck();
  }

  // 자동 재생 콜백 설정
  void setAutoPlayCallback(VoidCallback callback) {
    _onSongFinished = callback;
    debugPrint('[GLOBAL_SOUND] 자동 재생 콜백 설정됨');
  }

  // 자동 재생 콜백 제거
  void clearAutoPlayCallback() {
    _onSongFinished = null;
    debugPrint('[GLOBAL_SOUND] 자동 재생 콜백 제거됨');
  }

  // position 체크 타이머 시작
  void _startPositionCheck() {
    _positionCheckTimer?.cancel(); // 기존 타이머가 있다면 취소
    // position 체크는 더 이상 사용하지 않음
    // just_audio의 playerStateStream으로 충분히 감지 가능
    debugPrint('[GLOBAL_SOUND] position 체크 타이머 비활성화됨');
  }

  Future<void> playAsset(String file) async {
    debugPrint('[GLOBAL_SOUND] playAsset 호출됨: $file');

    // 기존 재생 중지
    await stop();

    try {
      // 에셋 설정
      await player.setAsset('assets/sounds/$file');
      debugPrint('[GLOBAL_SOUND] 에셋 설정 완료: assets/sounds/$file');

      // 재생 시작
      debugPrint('[GLOBAL_SOUND] play() 호출 시작');
      await player.play();
      debugPrint('[GLOBAL_SOUND] play() 완료');

      _isPlaying = true;
      _currentPlaying = file; // 새로운 노래 파일명 설정
      _currentDuration = player.duration;
      _callbackExecuted = false; // 새로운 노래 시작 시 콜백 실행 가능하도록 리셋

      debugPrint(
        '[GLOBAL_SOUND] 재생 상태 설정 완료: _isPlaying=$_isPlaying, _currentPlaying=$_currentPlaying, _callbackExecuted=$_callbackExecuted',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('[GLOBAL_SOUND] playAsset 실행 중 오류: $e');
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
    _currentPlaying = null;
    _currentDuration = null;
    _callbackExecuted = false; // 콜백 실행 상태 리셋
    notifyListeners();
  }

  @override
  void dispose() {
    _positionCheckTimer?.cancel();
    player.dispose(); // AudioPlayer도 정리
    super.dispose();
  }
}

/// ==============================
/// 전역 미니 플레이어 (하단 고정)
/// ==============================
class GlobalMiniPlayer extends StatelessWidget {
  final GlobalSoundService service = GlobalSoundService();

  GlobalMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (_, __) {
        if (service.currentPlaying == null) return const SizedBox.shrink();
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
              child: Padding(
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        } else if (service.currentPlaying != null) {
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
                      onPressed: service.stop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  final List<String> soundFiles = [
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

  @override
  void initState() {
    super.initState();
    sound.addListener(() => mounted ? setState(() {}) : null);

    // 자동 재생 시작 (2초 후)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Future.microtask(() => _startAutoPlay());
      }
    });
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
    _autoPlayTimer?.cancel(); // 자동 재생 타이머 정리

    // GlobalSoundService에서 자동 재생 콜백 제거
    sound.clearAutoPlayCallback();

    sound.removeListener(() {});
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    debugPrint('[AUTH] preparing headers, userId=$userId');

    try {
      // JWT 토큰 유효성 확인
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
      debugPrint('[AUTH] _authHeaders 오류: $e');
      throw Exception('인증 헤더 생성 실패: $e');
    }
  }

  Future<void> _patchPreferredSoundsRank() async {
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

      final resp = await http.patch(url, headers: headers, body: body);

      debugPrint(
        '[PATCH preferredSounds] status=${resp.statusCode} body=${resp.body}',
      );
      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('preferredSounds PATCH 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('정렬 저장 실패: $e')));
      }
    }
  }

  void _onReorder(int oldIdx, int newIdx) async {
    setState(() {
      if (newIdx > oldIdx) newIdx -= 1; // ✅ Flutter 인덱스 보정
      final item = soundFiles.removeAt(oldIdx);
      soundFiles.insert(newIdx, item);
    });
    await _patchPreferredSoundsRank(); // ✅ 서버에 정렬 저장
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
        // 추천 요청 완료 상태 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'soundRecommendationRequested',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );

        // 잠시 기다린 후 결과 가져오기
        await Future.delayed(const Duration(seconds: 3));

        // 결과 가져오기 (직접 처리)
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
              debugPrint(
                '[RESULTS] 새로운 추천 결과 로드 완료: ${topRecommended.length}개',
              );

              // 자동 재생 시작
              Future.microtask(() => _startAutoPlay());
            } else {
              debugPrint('[RESULTS] 새로운 추천 결과 데이터 없음');
              setState(() {
                _isLoadingRecommendations = false;
              });
            }
          } else {
            debugPrint(
              '[RESULTS] 새로운 추천 결과 가져오기 실패: ${resultsResponse.statusCode}',
            );
            setState(() {
              _isLoadingRecommendations = false;
            });
          }
        } catch (e) {
          debugPrint('[RESULTS] 새로운 추천 결과 가져오기 중 오류: $e');
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
        debugPrint('추천 실행 실패: ${response.statusCode}');
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
      debugPrint('추천 실행 중 오류: $e');
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

      // 홈화면에서 이미 추천 요청이 완료되었는지 확인
      final prefs = await SharedPreferences.getInstance();
      final recommendationRequested = prefs.getString(
        'soundRecommendationRequested',
      );
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint('[RESULTS] === 추천 상태 확인 ===');
      debugPrint('[RESULTS] 오늘 날짜: $today');
      debugPrint(
        '[RESULTS] SharedPreferences에 저장된 날짜: $recommendationRequested',
      );
      debugPrint('[RESULTS] 날짜 일치 여부: ${recommendationRequested == today}');

      if (recommendationRequested == today) {
        debugPrint('[RESULTS] 홈화면에서 이미 추천 요청 완료됨, 저장된 결과 사용');

        // 미리 저장된 추천 결과가 있는지 확인
        final savedRecommendations = prefs.getString('soundRecommendations');
        final savedDate = prefs.getString('soundRecommendationsDate');

        debugPrint('[RESULTS] 저장된 추천 결과 확인:');
        debugPrint('[RESULTS] soundRecommendations 키 값: $savedRecommendations');
        debugPrint('[RESULTS] soundRecommendationsDate 키 값: $savedDate');
        debugPrint('[RESULTS] 모든 SharedPreferences 키들: ${prefs.getKeys()}');

        if (savedRecommendations != null && savedDate == today) {
          try {
            final recommendations = jsonDecode(savedRecommendations) as List;
            debugPrint('[RESULTS] 파싱할 추천 결과: $recommendations');

            // filename 필드가 null이 아닌 항목만 필터링하여 안전하게 처리
            final validRecommendations =
                recommendations
                    .where(
                      (item) =>
                          item is Map<String, dynamic> &&
                          item['filename'] != null &&
                          item['filename'].toString().isNotEmpty,
                    )
                    .map((item) => item['filename'].toString())
                    .toList();

            debugPrint('[RESULTS] 유효한 추천 결과: $validRecommendations');

            setState(() {
              topRecommended = validRecommendations;
              _isLoadingRecommendations = false;
            });
            debugPrint('[RESULTS] 저장된 추천 결과 로드 완료: ${topRecommended.length}개');

            // 자동 재생 시작
            Future.microtask(() => _startAutoPlay());
            return; // 저장된 데이터 사용 완료, 함수 종료
          } catch (e) {
            debugPrint('[RESULTS] 저장된 추천 결과 파싱 실패: $e');
            // 저장된 결과가 잘못되었으면 새로 요청
          }
        } else {
          debugPrint('[RESULTS] 저장된 추천 결과가 없음, 서버에서 새로 요청');
        }
      } else {
        debugPrint('[RESULTS] 홈화면에서 추천 요청 안됨, 새로 요청');
      }

      // 홈화면에서 추천을 받지 않았거나 저장된 결과가 없는 경우에만 서버에서 새로 요청
      await _requestNewRecommendation();
    } catch (e) {
      debugPrint('[RESULTS] 추천 사운드 로드 중 오류: $e');
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  // 홈화면에서 이미 추천 요청이 완료된 경우 결과만 가져오기 (현재 사용하지 않음)
  /*
  Future<void> _loadRecommendationResults() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await http.get(
        Uri.parse(
          'https://kooala.tassoo.uk/recommend-sound/$userId/$dateStr/results',
        ),
        headers: {
          'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[RESULTS] 추천 결과 응답 전체: $data');
        debugPrint('[RESULTS] 응답 키들: ${data.keys.toList()}');
        
        if (data['success'] == true && data['recommended_sounds'] != null) {
          final recommendations = data['recommended_sounds'] as List;
          debugPrint('[RESULTS] recommended_sounds 데이터: $recommendations');
          
          setState(() {
            topRecommended =
                recommendations
                    .map((item) => item['fileName'] as String)
                    .toList();
            _isLoadingRecommendations = false;
          });
          debugPrint('[RESULTS] 서버에서 추천 결과 가져오기 완료: ${topRecommended.length}개');
          
          // 자동 재생 시작
          Future.microtask(() => _startAutoPlay());
        } else {
          debugPrint('[RESULTS] 추천 결과 데이터 없음');
          debugPrint('[RESULTS] success: ${data['success']}');
          debugPrint(
            '[RESULTS] recommended_sounds: ${data['recommended_sounds']}',
          );
          setState(() {
            _isLoadingRecommendations = false;
          });
        }
      } else {
        debugPrint('[RESULTS] 추천 결과 가져오기 실패: ${response.statusCode}');
        debugPrint('[RESULTS] 응답 내용: ${response.body}');
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('[RESULTS] 추천 결과 가져오기 중 오류: $e');
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }
  */

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
        debugPrint('[RESULTS] 새로운 추천 요청 성공');

        // 추천 요청 완료 상태 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'soundRecommendationRequested',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );

        // 잠시 기다린 후 결과 가져오기
        await Future.delayed(const Duration(seconds: 3));

        // 결과 가져오기 (직접 처리)
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
              debugPrint(
                '[RESULTS] 새로운 추천 결과 로드 완료: ${topRecommended.length}개',
              );

              // 자동 재생 시작
              Future.microtask(() => _startAutoPlay());
            } else {
              debugPrint('[RESULTS] 새로운 추천 결과 데이터 없음');
              setState(() {
                _isLoadingRecommendations = false;
              });
            }
          } else {
            debugPrint(
              '[RESULTS] 새로운 추천 결과 가져오기 실패: ${resultsResponse.statusCode}',
            );
            setState(() {
              _isLoadingRecommendations = false;
            });
          }
        } catch (e) {
          debugPrint('[RESULTS] 새로운 추천 결과 가져오기 중 오류: $e');
          setState(() {
            _isLoadingRecommendations = false;
          });
        }
      } else {
        debugPrint('[RESULTS] 새로운 추천 요청 실패: ${response.statusCode}');
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('[RESULTS] 새로운 추천 요청 중 오류: $e');
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

      debugPrint(
        '[PATCH] preferenceBalance=${payload["preferenceBalance"]} '
        'status=${resp.statusCode} body=${resp.body}',
      );

      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('preferenceBalance PATCH 실패: $e');
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

  // 자동 재생 시작
  void _startAutoPlay() {
    debugPrint('[AUTO_PLAY] _startAutoPlay 시작');
    debugPrint('[AUTO_PLAY] _userStoppedAutoPlay: $_userStoppedAutoPlay');
    debugPrint('[AUTO_PLAY] mounted: $mounted');

    if (_userStoppedAutoPlay) {
      debugPrint('[AUTO_PLAY] 사용자가 자동 재생을 중지했음');
      return;
    }

    if (!mounted) {
      debugPrint('[AUTO_PLAY] 위젯이 마운트되지 않음');
      return;
    }

    // 추천사운드가 로드되었는지 확인
    if (topRecommended.isEmpty) {
      debugPrint('[AUTO_PLAY] 추천사운드가 로드되지 않음');
      return;
    }

    // 자동 재생 시작
    _isAutoPlaying = true;
    _autoPlayQueue.clear();
    _currentAutoPlayIndex = 0;

    final top3Songs = topRecommended.take(3).toList();
    debugPrint('[AUTO_PLAY] top3Songs: $top3Songs');

    // 2바퀴 돌리기
    for (int round = 0; round < 2; round++) {
      for (String song in top3Songs) {
        _autoPlayQueue.add(song);
      }
    }

    debugPrint('[AUTO_PLAY] 추천사운드 TOP3 2바퀴 추가: ${_autoPlayQueue.length}개');
    debugPrint('[AUTO_PLAY] _autoPlayQueue 내용: $_autoPlayQueue');

    // GlobalSoundService에서 자동 재생 콜백 제거 (기존 콜백 정리)
    sound.clearAutoPlayCallback();

    // GlobalSoundService에 자동 재생 콜백 설정
    sound.setAutoPlayCallback(() {
      debugPrint('[AUTO_PLAY] 콜백 실행됨!');
      debugPrint('[AUTO_PLAY] _currentAutoPlayIndex: $_currentAutoPlayIndex');
      debugPrint('[AUTO_PLAY] _autoPlayQueue 길이: ${_autoPlayQueue.length}');

      if (_currentAutoPlayIndex < _autoPlayQueue.length) {
        debugPrint(
          '[AUTO_PLAY] 현재 노래 종료, 다음 노래로 이동: $_currentAutoPlayIndex -> ${_currentAutoPlayIndex + 1}',
        );

        // 다음 노래 재생
        _playNextInQueue();
      } else {
        debugPrint('[AUTO_PLAY] 모든 노래 재생 완료 - 자동 재생 종료');
        _isAutoPlaying = false;
        _currentAutoPlayIndex = 0;
      }
    });

    debugPrint('[AUTO_PLAY] 콜백 설정 완료');
    debugPrint('[AUTO_PLAY] _playNextInQueue 호출 시작');

    // 즉시 첫 번째 곡 재생 시작
    _playNextInQueue();
  }

  // 5분 동안 반복 재생할 노래를 큐에 추가 (현재 사용하지 않음)
  /*
  Future<void> _addRepeatedSong(String songFile) async {
    try {
      // 노래 길이를 가져와서 5분 동안 몇 번 반복해야 하는지 계산
      const targetDuration = Duration(minutes: 5);

      // 실제 노래 길이를 가져오기 위해 임시로 AudioPlayer 생성
      final tempPlayer = AudioPlayer();
      await tempPlayer.setAsset('assets/sounds/$songFile');

      final songDuration = tempPlayer.duration;
      await tempPlayer.dispose();

      if (songDuration != null && songDuration.inSeconds > 0) {
        // 실제 노래 길이로 정확한 반복 횟수 계산
        final repeatCount =
            (targetDuration.inSeconds / songDuration.inSeconds).ceil();

        // 기존에 추가된 노래를 제거하고 반복 재생용으로만 추가
        _autoPlayQueue.removeWhere((item) => item == songFile);

        for (int i = 0; i < repeatCount; i++) {
          _autoPlayQueue.add(songFile);
        }

        debugPrint(
          '[AUTO_PLAY] $songFile을 $repeatCount번 반복 추가 (노래 길이: ${songDuration.inSeconds}초, 목표: 5분)',
        );
      } else {
        // 노래 길이를 가져올 수 없는 경우 기본값 사용
        const estimatedSongLength = Duration(minutes: 3);
        final repeatCount =
            (targetDuration.inSeconds / estimatedSongLength.inSeconds).ceil();

        // 기존에 추가된 노래를 제거하고 반복 재생용으로만 추가
        _autoPlayQueue.removeWhere((item) => item == songFile);

        for (int i = 0; i < repeatCount; i++) {
          _autoPlayQueue.add(songFile);
        }

        debugPrint('[AUTO_PLAY] $songFile을 $repeatCount번 반복 추가 (기본 추정 길이 사용)');
      }
    } catch (e) {
      debugPrint('[AUTO_PLAY] 반복 노래 추가 실패: $e');
      // 실패 시 기본값으로 3번 추가
      _autoPlayQueue.removeWhere((item) => item == songFile);
      for (int i = 0; i < 3; i++) {
        _autoPlayQueue.add(songFile);
      }
    }
  }
  */

  // 큐에서 다음 곡 재생
  void _playNextInQueue() {
    debugPrint('[AUTO_PLAY] _playNextInQueue 시작');
    debugPrint('[AUTO_PLAY] _currentAutoPlayIndex: $_currentAutoPlayIndex');
    debugPrint('[AUTO_PLAY] _autoPlayQueue 길이: ${_autoPlayQueue.length}');

    if (_currentAutoPlayIndex >= _autoPlayQueue.length) {
      debugPrint('[AUTO_PLAY] 모든 노래 재생 완료');
      _isAutoPlaying = false;
      _currentAutoPlayIndex = 0;
      return;
    }

    final songFile = _autoPlayQueue[_currentAutoPlayIndex];
    debugPrint(
      '[AUTO_PLAY] 재생할 노래: $songFile (${_currentAutoPlayIndex + 1}/${_autoPlayQueue.length})',
    );

    // GlobalSoundService를 통해 노래 재생
    sound
        .playAsset(songFile)
        .then((_) {
          debugPrint('[AUTO_PLAY] 노래 재생 시작 완료: $songFile');
          // 노래가 끝나면 콜백이 자동으로 실행되어 다음 노래로 넘어감
        })
        .catchError((error) {
          debugPrint('[AUTO_PLAY] 노래 재생 실패: $error');
          // 재생 실패 시 다음 노래로 넘어가기 (콜백을 통하지 않고 직접)
          _currentAutoPlayIndex++;
          if (_currentAutoPlayIndex < _autoPlayQueue.length) {
            _playNextInQueue();
          } else {
            debugPrint('[AUTO_PLAY] 모든 노래 재생 완료 (오류로 인한 종료)');
            _isAutoPlaying = false;
            _currentAutoPlayIndex = 0;
          }
        });
  }

  // 자동 재생 중지
  void _stopAutoPlay() {
    _isAutoPlaying = false;
    _userStoppedAutoPlay = true;
    _autoPlayTimer?.cancel();

    // GlobalSoundService에서 자동 재생 콜백 제거
    sound.clearAutoPlayCallback();

    debugPrint('[AUTO_PLAY] 사용자가 자동 재생 중지');
  }

  // 사용자가 수동으로 사운드 재생 시 자동 재생 중지
  Future<void> _playSound(String file) async {
    debugPrint(
      '[AUTO_PLAY] _playSound 호출: $file, _isAutoPlaying: $_isAutoPlaying',
    );

    // 자동 재생 중이 아닐 때만 자동 재생 중지 (자동 재생 중에는 중지하지 않음)
    if (_isAutoPlaying) {
      // 자동 재생 중이므로 중지하지 않음
      debugPrint('[AUTO_PLAY] 자동 재생 중: $file 재생');
    } else {
      // 사용자가 수동으로 재생하면 자동 재생 중지
      debugPrint('[AUTO_PLAY] 수동 재생: 자동 재생 중지');
      _stopAutoPlay();
    }

    await sound.playAsset(file);
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
      // JWT 토큰 유효성 먼저 확인
      final isLoggedIn = await JwtUtils.isLoggedIn();
      if (!isLoggedIn) {
        throw Exception('JWT 토큰이 유효하지 않습니다. 다시 로그인해주세요.');
      }

      // JWT 토큰에서 userID 추출
      final fromJwt = await JwtUtils.getCurrentUserId();
      if (fromJwt != null && fromJwt.isNotEmpty) {
        // storage에 userID 저장 (동기화)
        await storage.write(key: 'userID', value: fromJwt);
        await storage.write(key: 'userId', value: fromJwt);
        debugPrint('[USER] JWT에서 userID 추출: $fromJwt');
        return fromJwt.trim();
      }

      // JWT에서 추출할 수 없는 경우 storage에서 확인
      String? fromStorage =
          await storage.read(key: 'userID') ??
          await storage.read(key: 'userId');

      if (fromStorage != null && fromStorage.trim().isNotEmpty) {
        return fromStorage.trim();
      }

      throw Exception('userID를 찾을 수 없습니다. 다시 로그인해주세요.');
    } catch (e) {
      debugPrint('[USER] _ensureUserId 오류: $e');
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

      final resp = await http.patch(url, headers: headers, body: body);

      debugPrint(
        '[PATCH preferredSounds] status=${resp.statusCode} body=${resp.body}',
      );
      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('preferredSounds PATCH 실패: $e');
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

    // 2바퀴 돌리므로 3으로 나누어 실제 노래 순위 계산
    final actualIndex = _currentAutoPlayIndex % 3;
    return actualIndex + 1; // 1부터 시작
  }

  // 현재 재생 중인 노래의 바퀴 수 계산
  int _getCurrentRound() {
    if (_autoPlayQueue.isEmpty ||
        _currentAutoPlayIndex >= _autoPlayQueue.length) {
      return 0;
    }

    // 3으로 나누어 바퀴 수 계산
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
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                120,
              ), // 하단 미니플레이어 여백
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

                  // 추천 결과 카드 (+ 버튼 2개: 새로고침, 왜 추천?)
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
                                      color: const Color(0xFF4CAF50),
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

                        // ✅ "왜 사운드를 추천하나요?" 버튼 (새 페이지로 이동해서 API 호출)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final uid = userId; // null이면 _ensureUserId()로 보강
                              final date = recDate; // 지금 추천을 실행한 날짜
                              if (uid == null) return; // 가드
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
                                                  const Color(0xFFFFD700),
                                                  const Color(0xFFFFA500),
                                                ] // 1위: 금색
                                                : index == 2
                                                ? [
                                                  const Color(0xFFC0C0C0),
                                                  const Color(0xFFA0A0A0),
                                                ] // 2위: 은색
                                                : [
                                                  const Color(0xFFCD7F32),
                                                  const Color(0xFFB8860B),
                                                ], // 3위: 동색
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
                                              style: TextStyle(
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
                                // 로딩 애니메이션 추가
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
                                  '사운드를 드래그해서 순서를 변경할 수 있습니다. 변경된 순서는 자동으로 사용자 선호도 데이터로 사용됩니다.',
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
                            setState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = soundFiles.removeAt(oldIndex);
                              soundFiles.insert(newIndex, item);
                            });

                            // 순서 변경 후 서버에 저장
                            _savePreferredSoundsRank();
                          },
                          itemBuilder: (context, i) {
                            final file = soundFiles[i];
                            final name = file
                                .replaceAll('.mp3', '')
                                .replaceAll('_', ' ');
                            final selected = sound.currentPlaying == file;
                            final data = metadata[file];
                            final isRecommended = topRecommended.contains(file);

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
                                                  // 추천 라벨 제거 - 모든 곡에 표시되어 의미 없음
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
