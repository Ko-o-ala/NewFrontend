// 파일명: SoundScreen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/sound/why_recommended_page.dart';

/// ==============================
/// 전역 사운드 서비스 (화면 이동해도 유지)
/// ==============================
class GlobalSoundService extends ChangeNotifier {
  static final GlobalSoundService _instance = GlobalSoundService._internal();
  factory GlobalSoundService() => _instance;
  GlobalSoundService._internal() {
    player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _currentPlaying = null;
      }
      notifyListeners();
    });
  }

  final AudioPlayer player = AudioPlayer();
  String? _currentPlaying;
  bool _isPlaying = false;

  String? get currentPlaying => _currentPlaying;
  bool get isPlaying => _isPlaying;

  Future<void> playAsset(String file) async {
    if (_currentPlaying == file && _isPlaying) {
      await pause();
      return;
    }
    await player.setAsset('assets/sounds/$file');
    _currentPlaying = file;
    await player.play();
    _isPlaying = true;
    notifyListeners();
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
    notifyListeners();
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
  bool loadingRecommendations = false;
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

  final PageController controller = PageController();
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    // 전역 사운드 상태 변경 시 화면 갱신
    sound.addListener(() => mounted ? setState(() {}) : null);
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

        await _executeRecommendation();
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
    controller.dispose();
    sound.removeListener(() {});
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    debugPrint('[AUTH] preparing headers, userId=$userId');
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
      final item = soundFiles.removeAt(oldIdx);
      soundFiles.insert(newIdx, item);
    });
    await _patchPreferredSoundsRank();
  }

  Future<void> _executeRecommendation() async {
    if (userId == null) {
      debugPrint('[EXEC] skip: userId is null');
      return;
    }
    if (executing) return;

    try {
      setState(() => executing = true);
      final url = Uri.parse('https://kooala.tassoo.uk/recommend-sound/execute');
      final headers = await _authHeaders();
      final body = json.encode({"userID": userId, "date": _fmtDate(recDate)});

      final resp = await http.post(url, headers: headers, body: body);
      debugPrint('[EXEC] status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode == 200 ||
          resp.statusCode == 202 ||
          resp.statusCode == 204) {
        await _loadRecommendations();
        return;
      }
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      debugPrint('execute 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('추천 실행 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => executing = false);
    }
  }

  Future<void> _loadRecommendations() async {
    if (userId == null) {
      debugPrint('[RESULTS] skip: userId is null');
      return;
    }

    setState(() => loadingRecommendations = true);

    try {
      // 기존 date 포함 API (유지)
      final url = Uri.parse(
        'https://kooala.tassoo.uk/recommend-sound/${Uri.encodeComponent(userId!)}/${_fmtDate(recDate)}/results',
      );
      debugPrint('[RESULTS] GET $url');

      final resp = await http.get(url, headers: await _authHeaders());
      debugPrint('[RESULTS] status=${resp.statusCode} body=${resp.body}');

      if (resp.statusCode == 401) {
        await storage.delete(key: 'jwt');
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final Map<String, dynamic> jsonBody = json.decode(resp.body);
      final List<dynamic> recs =
          (jsonBody['recommended_sounds'] as List?) ?? [];

      final recommendationText =
          (jsonBody['recommendation_text'] ??
                  jsonBody['recommended_text'] ??
                  '')
              .toString();

      final sorted =
          recs.whereType<Map<String, dynamic>>().toList()
            ..sort((a, b) => (a['rank'] ?? 999).compareTo(b['rank'] ?? 999));

      final filenames = <String>[];
      for (final m in sorted) {
        final fn = m['filename']?.toString();
        if (fn != null && soundFiles.contains(fn)) filenames.add(fn);
      }

      final rest = soundFiles.where((f) => !filenames.contains(f)).toList();

      setState(() {
        this.recommendationText = recommendationText;
        topRecommended = filenames;
        soundFiles
          ..clear()
          ..addAll(filenames)
          ..addAll(rest);

        currentPage = 0;
        if (controller.hasClients) {
          controller.jumpToPage(0);
        }
      });
    } catch (e) {
      debugPrint('추천 조회 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('추천을 불러오지 못했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => loadingRecommendations = false);
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

  Future<void> _playSound(String fileName) async {
    await sound.playAsset(fileName);
  }

  void _debouncedExecute() {
    _execDebounce?.cancel();
    _execDebounce = Timer(const Duration(milliseconds: 350), () {
      _executeRecommendation();
    });
  }

  List<String> _getPageItems(int page, int perPage) {
    final start = page * perPage;
    return soundFiles.skip(start).take(perPage).toList();
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<String> _ensureUserId() async {
    final raw = await storage.read(key: 'jwt');
    String? fromJwt;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final tokenOnly =
            raw.startsWith(RegExp(r'Bearer\s', caseSensitive: false))
                ? raw.split(' ').last
                : raw;
        final parts = tokenOnly.split('.');
        if (parts.length == 3) {
          final payloadJson = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final payload = json.decode(payloadJson) as Map<String, dynamic>;
          fromJwt =
              (payload['userId'] ?? payload['userID'] ?? payload['sub'])
                  ?.toString();
          debugPrint('[USER] recovered from JWT: $fromJwt');
        }
      } catch (_) {}
    }

    String? fromStorage =
        await storage.read(key: 'userID') ?? await storage.read(key: 'userId');

    if (fromJwt != null && fromJwt.isNotEmpty && fromStorage != fromJwt) {
      await storage.write(key: 'userID', value: fromJwt);
      await storage.write(key: 'userId', value: fromJwt);
      fromStorage = fromJwt;
    }

    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return fromStorage.trim();
    }
    throw Exception('userID 미존재');
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

    const perPage = 6;
    final pageCount = (soundFiles.length / perPage).ceil();

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
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loadingRecommendations
                                    ? "추천 불러오는 중..."
                                    : (recommendationText ??
                                        "아래 새로고침을 눌러 오늘의 추천을 받아보세요."),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '추천 새로고침',
                              icon: const Icon(
                                Icons.refresh,
                                color: Color(0xFF6C63FF),
                              ),
                              onPressed:
                                  loadingRecommendations
                                      ? null
                                      : _executeRecommendation,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ✅ “왜 사운드를 추천하나요?” 버튼 (새 페이지로 이동해서 API 호출)
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                topRecommended.take(2).map((f) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6C63FF),
                                          Color(0xFF4B47BD),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '추천 • ${f.replaceAll(".mp3", "")}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
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

                        // 페이지 인디케이터
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(pageCount, (i) {
                            return GestureDetector(
                              onTap: () => controller.jumpToPage(i),
                              child: Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      currentPage == i
                                          ? const Color(0xFF6C63FF)
                                          : Colors.white.withOpacity(0.3),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 20),

                        // 사운드 카드들
                        SizedBox(
                          height: 400,
                          child: PageView.builder(
                            controller: controller,
                            onPageChanged:
                                (idx) => setState(() => currentPage = idx),
                            itemCount: pageCount,
                            itemBuilder: (_, pageIndex) {
                              const perPage = 6;
                              final items = _getPageItems(pageIndex, perPage);
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, i) {
                                  final file = items[i];
                                  final name = file
                                      .replaceAll('.mp3', '')
                                      .replaceAll('_', ' ');
                                  final selected = sound.currentPlaying == file;
                                  final data = metadata[file];
                                  final isRecommended = topRecommended.contains(
                                    file,
                                  );

                                  return Container(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      selected
                                                          ? const Color(
                                                            0xFF6C63FF,
                                                          )
                                                          : Colors.white
                                                              .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  selected && sound.isPlaying
                                                      ? Icons.pause_circle
                                                      : Icons.play_circle,
                                                  color:
                                                      selected
                                                          ? Colors.white
                                                          : const Color(
                                                            0xFF6C63FF,
                                                          ),
                                                  size: 24,
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
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                        if (isRecommended)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFFFFD700,
                                                                  ).withOpacity(
                                                                    0.2,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              '추천',
                                                              style: TextStyle(
                                                                color: Color(
                                                                  0xFFFFD700,
                                                                ),
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
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
                                                          ? const Color(
                                                            0xFF6C63FF,
                                                          )
                                                          : Colors.white70,
                                                ),
                                                onPressed:
                                                    () => _playSound(file),
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
                                                              color:
                                                                  const Color(
                                                                    0xFF6C63FF,
                                                                  ).withOpacity(
                                                                    0.3,
                                                                  ),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            '#${tag.trim()}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF6C63FF,
                                                                  ),
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
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
          ),

          // 하단 전역 미니 플레이어
          GlobalMiniPlayer(),
        ],
      ),
    );
  }
}
