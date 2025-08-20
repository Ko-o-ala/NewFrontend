// 전체 코드 + 모든 사운드 메타데이터 포함
// 파일명: SoundScreen.dart
import 'dart:async';

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:my_app/TopNav.dart';
import 'package:my_app/bottomNavigationBar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Timer? _prefDebounce; // 슬라이더 PATCH 디바운스

class SoundScreen extends StatefulWidget {
  const SoundScreen({Key? key}) : super(key: key);

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  Timer? _execDebounce;
  bool executing = false; // (선택) 실행 중 UI 제어에 쓰고 싶으면 사용

  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final player = AudioPlayer();
  String? currentPlaying;
  bool isPlaying = false;
  double preferenceRatio = 0.75;

  /// 🔹 추천 API 관련 상태
  String? recommendationText; // 서버가 내려주는 recommendation_text
  List<String> topRecommended = []; // 서버에서 온 filename 리스트(순위 정렬 적용)
  bool loadingRecommendations = false;
  String? userId;
  bool authReady = false;
  DateTime recDate = DateTime(2025, 8, 12); // 기본값 (라우트 args로 덮어씀)
  bool _argsApplied = false; // didChangeDependencies 1회만 실행하기 위한 플래그

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
    player.playerStateStream.listen((state) {
      setState(() {
        isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          currentPlaying = null;
        }
      });
    });
  }

  /// 라우트에서 넘어온 userId/date를 1회 반영 + 추천 호출
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    _argsApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    Future.microtask(() async {
      try {
        // 1) 날짜 먼저 반영
        if (args is Map) {
          final d = args['date'];
          if (d is String && d.isNotEmpty) {
            final parsed = DateTime.tryParse(d);
            if (parsed != null) recDate = parsed;
          } else if (d is DateTime) {
            recDate = d;
          }
        } else {
          // 날짜를 못 받았으면 오늘로 (404 회피)
          recDate = DateTime.now();
        }

        // 2) userId 확보 (JWT/스토리지 기준으로 보정)
        final ensured = await _ensureUserId();
        var finalId = ensured;

        // 3) 라우트 userId는 JWT와 같을 때만 허용 (불일치 = 403 유발)
        if (args is Map &&
            args['userId'] is String &&
            (args['userId'] as String).isNotEmpty) {
          final fromArgs = (args['userId'] as String).trim();
          if (fromArgs == ensured) {
            finalId = fromArgs;
          } else {
            debugPrint(
              '[USER] ignore mismatching route userId=$fromArgs; use token=$ensured',
            );
          }
        }

        setState(() {
          userId = finalId;
          authReady = true;
        });

        debugPrint('[USER] final userId=$userId, date=${_fmtDate(recDate)}');

        // 4) ✅ 한 번만 실행
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
    _execDebounce?.cancel(); // ← 추가
    player.dispose();
    controller.dispose();
    super.dispose();
  }

  // JWT 읽기 + 인증 헤더 생성
  Future<String?> _getJwt() async {
    // 로그인 시 저장해 둔 jwt 읽기
    return await storage.read(key: 'jwt');
  }

  Future<Map<String, String>> _authHeaders() async {
    // userId 확보 여부 로그용
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

      // 현재 화면상의 전체 순서를 1-base rank로 생성
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

    // ✅ 사용자가 순서를 바꿀 때마다 서버에 즉시 반영
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
      final body = json.encode({
        "userID": userId,
        "date": _fmtDate(recDate),
        // "preferenceRatio": preferenceRatio, // 서버가 받으면 주석 해제
      });

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
        recommendationText = null;
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
      // 서버가 0~1 스케일을 받는다고 가정 (필요 시 매핑 수정)
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
    final value = preferenceRatio; // 현재 슬라이더 값 캡처
    _prefDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _patchPreferenceBalance(value); // 1) 서버에 저장
      await _executeRecommendation(); // 2) 최신 선호도로 추천 재실행
    });
  }

  Future<void> _playSound(String fileName) async {
    if (currentPlaying == fileName && isPlaying) {
      await player.pause();
    } else {
      try {
        await player.setAsset('assets/sounds/$fileName');
        player.play();
        setState(() {
          currentPlaying = fileName;
        });
      } catch (e) {
        debugPrint("⚠️ 재생 오류: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('재생 오류: $e')));
        }
      }
    }
  }

  void _stop() async {
    await player.stop();
    setState(() {
      currentPlaying = null;
    });
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

  /// 🔹 YYYY-MM-DD 포맷
  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<String> _ensureUserId() async {
    // JWT에서 복구
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
      } catch (e) {
        debugPrint('[USER] JWT parse fail: $e');
      }
    }

    // 스토리지에서 읽기 (userID / userId 모두 시도)
    String? fromStorage =
        await storage.read(key: 'userID') ?? await storage.read(key: 'userId');
    debugPrint('[USER] storage userId(userID/userId): $fromStorage');

    // JWT와 스토리지 불일치면 JWT 값으로 보정
    if (fromJwt != null && fromJwt.isNotEmpty && fromStorage != fromJwt) {
      await storage.write(key: 'userID', value: fromJwt);
      await storage.write(key: 'userId', value: fromJwt); // 양쪽 키에 모두 저장(안전)
      fromStorage = fromJwt;
      debugPrint('[USER] storage userID/userId updated to JWT value');
    }

    if (fromStorage != null && fromStorage.trim().isNotEmpty) {
      return fromStorage.trim();
    }

    throw Exception('userID 미존재');
  }

  @override
  Widget build(BuildContext context) {
    if (!authReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    const perPage = 6;
    final pageCount = (soundFiles.length / perPage).ceil();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FF),
      appBar: TopNav(isLoggedIn: true, onLogin: () {}, onLogout: () {}),

      body: Column(
        children: [
          // 상단: AI 추천 비율 슬라이더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI 추천 비율 조정",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: preferenceRatio,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: "${(preferenceRatio * 100).toInt()}%",
                  onChanged: (value) {
                    setState(() => preferenceRatio = value);
                    _debouncedPrefUpdate(); // ✅ PATCH + 추천 재실행 (디바운스)
                  },
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "내가 좋아하는 소리를 \n 더 추천해주세요",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      "수면 데이터에 맞춰 \n 추천해주세요",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🔹 추천 결과 표시 카드(문구 + 새로고침 + 추천 태그)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF8183D9),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loadingRecommendations
                                ? "추천 불러오는 중..."
                                : (recommendationText ??
                                    "아래 새로고침을 눌러 오늘의 추천을 받아보세요."),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                          tooltip: '추천 새로고침',
                          icon: const Icon(Icons.refresh),
                          onPressed:
                              loadingRecommendations
                                  ? null
                                  : _loadRecommendations,
                        ),
                      ],
                    ),
                    if (topRecommended.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      if (topRecommended.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children:
                              topRecommended
                                  .take(2)
                                  .map(
                                    // ✅ 상위 2개만
                                    (f) => Chip(
                                      label: Text(
                                        '추천 • ${f.replaceAll(".mp3", "")}',
                                      ),
                                      backgroundColor: const Color(0xFFEDEBFF),
                                      labelStyle: const TextStyle(
                                        color: Color(0xFF4B4EBD),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 본문: 페이지당 6개, 추천이 맨 위로 온 soundFiles를 사용
          Expanded(
            child: PageView.builder(
              controller: controller,
              onPageChanged: (idx) => setState(() => currentPage = idx),
              itemCount: pageCount,
              itemBuilder: (_, pageIndex) {
                final items = _getPageItems(pageIndex, perPage);
                return ReorderableListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onReorder: (oldI, newI) {
                    final old = pageIndex * perPage + oldI;
                    final neo =
                        pageIndex * perPage + (newI > oldI ? newI - 1 : newI);
                    _onReorder(old, neo);
                  },
                  children: List.generate(items.length, (i) {
                    final file = items[i];
                    final name = file
                        .replaceAll('.mp3', '')
                        .replaceAll('_', ' ');
                    final selected = currentPlaying == file;
                    final data = metadata[file];
                    final isRecommended = topRecommended.contains(file);

                    return Card(
                      key: ValueKey(file),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: selected ? const Color(0xFFEDEBFF) : Colors.white,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF8183D9),
                                  child: Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                selected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isRecommended)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEDEBFF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            '추천',
                                            style: TextStyle(
                                              color: Color(0xFF4B4EBD),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    selected && isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    size: 32,
                                    color:
                                        selected
                                            ? const Color(0xFF8183D9)
                                            : Colors.grey,
                                  ),
                                  onPressed: () => _playSound(file),
                                ),
                              ],
                            ),
                            if (data != null) ...[
                              const SizedBox(height: 10),
                              Text("• 특징: ${data["feature"]}"),
                              Text("• 효과: ${data["effect"]}"),
                              Text("• 추천 대상: ${data["target"]}"),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children:
                                    data["tags"]!
                                        .split(',')
                                        .map(
                                          (tag) => Chip(
                                            label: Text('#${tag.trim()}'),
                                            backgroundColor: const Color(
                                              0xFFF0F0F0,
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
                  }),
                );
              },
            ),
          ),

          // 페이지 인디케이터/점프
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(pageCount, (i) {
                return OutlinedButton(
                  onPressed: () => controller.jumpToPage(i),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        currentPage == i
                            ? const Color(0xFF8183D9)
                            : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: currentPage == i ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }),
            ),
          ),

          // 현재 재생 중 바
          if (currentPlaying != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Color(0xFF8183D9)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      currentPlaying!
                          .replaceAll('.mp3', '')
                          .replaceAll('_', ' '),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    color: const Color(0xFF8183D9),
                    onPressed: () {
                      if (isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    color: Colors.redAccent,
                    onPressed: _stop,
                  ),
                ],
              ),
            ),

          // 하단 네비게이션
          CustomBottomNavBar(
            currentIndex: 2,
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
        ],
      ),
    );
  }
}
