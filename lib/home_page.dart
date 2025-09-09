// home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 수면데이터 전송을 위해 추가
import 'package:intl/intl.dart'; // 날짜 포맷팅을 위해 추가
import 'dart:convert'; // JSON 처리를 위해 추가
import 'package:http/http.dart' as http; // HTTP 요청을 위해 추가
import 'package:my_app/services/jwt_utils.dart'; // JWT 유틸리티 추가
import 'package:my_app/sound/sound.dart'; // 글로벌 사운드 서비스 추가
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:health/health.dart'; // 건강앱 연동을 위해 추가
import 'dart:math' as math; // ⬅️ 추가

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _isLoggedIn = false;
  bool _isLoading = true; // 로딩 상태 추가
  String _userName = '사용자';
  final storage = FlutterSecureStorage(); // FlutterSecureStorage 인스턴스 생성

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLoginStatus();
    _loadUserName();
    // _refreshUserNameFromServer(); // 서버에서 원래 이름을 가져와서 덮어쓰므로 제거

    // 기존 잘못된 데이터 정리 후 수면데이터 전송
    _initializeData();

    // initState에서 바로 수면데이터 전송 (더 긴 지연시간으로 로그인 완료 대기)
    Future.delayed(const Duration(milliseconds: 2000), () async {
      debugPrint('[홈페이지] 🔄 initState 수면데이터 전송 시작 (2초 지연)');
      await _forceRefresh();
    });

    // 추가 백업: 5초 후에도 한 번 더 시도 (베타테스터용)
    Future.delayed(const Duration(milliseconds: 5000), () async {
      debugPrint('[홈페이지] 🔄 백업 수면데이터 전송 시작 (5초 지연)');
      await _forceRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadUserName(); // 캐시 표시
      // _refreshUserNameFromServer(); // 서버에서 원래 이름을 가져와서 덮어쓰므로 제거
      _checkLoginStatus();
      // 앱이 다시 활성화될 때 수면데이터 전송 시도
      _tryUploadPendingSleepData(retryCount: 0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRouteArgs();

    // SharedPreferences에서 프로필 업데이트 플래그 확인
    _checkProfileUpdate();

    // 홈화면 진입 시 자동 새로고침 (사용자 모르게)
    _autoRefreshOnEnter();
  }

  void _applyRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['updatedName'] is String) {
      final newName = (args['updatedName'] as String).trim();
      if (newName.isNotEmpty && _userName != newName) {
        setState(() => _userName = newName); // ✅ 즉시 반영 (깜빡임 없이)
      }
    }
  }

  // 홈화면 진입 시 자동 새로고침 (사용자 모르게)
  void _autoRefreshOnEnter() {
    debugPrint('[홈페이지] 🔄 자동 새로고침 시작');

    // 1초 후 바로 실행
    Future.delayed(const Duration(milliseconds: 1000), () async {
      debugPrint('[홈페이지] 🔄 자동 새로고침 실행');
      await _forceRefresh();
    });
  }

  // 강제 새로고침 함수
  Future<void> _forceRefresh() async {
    debugPrint('[홈페이지] 🔄 강제 새로고침 실행');

    // 베타테스터를 위한 디버깅 정보 출력
    await _debugSleepDataStatus();

    // 상태 업데이트
    if (mounted) {
      setState(() {});
    }

    // 기존 캐시된 데이터 모두 삭제
    debugPrint('[홈페이지] 🗑️ 기존 캐시된 수면데이터 모두 삭제');
    await _clearAllSleepDataCache();

    // 강제로 새로운 수면데이터 생성 (기존 데이터 무시)
    debugPrint('[홈페이지] 🔄 강제로 새로운 수면데이터 생성');
    await _createTestSleepData();

    // lastSentDate 초기화하여 강제 전송 가능하게 함
    await _clearLastSentDate();

    // 상태 업데이트
    if (mounted) {
      setState(() {});
    }

    // 수면데이터 전송 시도
    _tryUploadPendingSleepData(retryCount: 0);

    debugPrint('[홈페이지] 🔄 강제 새로고침 완료');
  }

  // 베타테스터를 위한 디버깅 정보 다이얼로그
  Future<void> _showDebugInfoDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await storage.read(key: 'jwt');
    final username = await storage.read(key: 'username');
    final userId =
        token != null ? JwtUtils.extractUserIdFromToken(token) : null;
    final payloadJson = prefs.getString('pendingSleepPayload');
    final lastSentDate = prefs.getString('lastSentDate');

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    String debugInfo = '';
    debugInfo += '📱 사용자명: ${username ?? "없음"}\n';
    debugInfo += '👤 사용자 ID: ${userId ?? "없음"}\n';
    debugInfo +=
        '🔑 JWT 토큰: ${token != null ? "있음 (${token.length}자)" : "없음"}\n';
    debugInfo +=
        '🕐 현재 기기 시간: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}\n';
    debugInfo += '📅 기기 기준 오늘: ${DateFormat('yyyy-MM-dd').format(now)}\n';
    debugInfo += '📅 기기 기준 어제: ${DateFormat('yyyy-MM-dd').format(yesterday)}\n';
    debugInfo +=
        '📦 수면데이터: ${payloadJson != null ? "있음 (${payloadJson.length}자)" : "없음"}\n';
    debugInfo += '📅 마지막 전송일: ${lastSentDate ?? "없음"}\n';
    debugInfo += '🔄 로그인 상태: $_isLoggedIn\n';

    if (payloadJson != null) {
      try {
        final payload = json.decode(payloadJson) as Map<String, dynamic>;
        final dataDate = (payload['date'] as String?) ?? '';
        debugInfo += '📅 전송할 데이터 날짜: $dataDate\n';
        debugInfo +=
            '⏰ 수면 시간: ${payload['sleepTime']?['startTime']} ~ ${payload['sleepTime']?['endTime']}\n';
        debugInfo +=
            '💤 총 수면 시간: ${payload['Duration']?['totalSleepDuration']}분\n';
        debugInfo += '⭐ 수면 점수: ${payload['sleepScore']}\n';
      } catch (e) {
        debugInfo += '❌ 데이터 파싱 오류: $e\n';
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('🔍 디버깅 정보 (베타테스터용)'),
              content: SingleChildScrollView(
                child: Text(
                  debugInfo,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _showDatePickerDialog();
                  },
                  child: const Text('날짜 수정'),
                ),
              ],
            ),
      );
    }
  }

  // 베타테스터를 위한 날짜 선택 다이얼로그
  Future<void> _showDatePickerDialog() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: yesterday,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: '수면데이터 날짜 선택',
    );

    if (selectedDate != null) {
      debugPrint(
        '[홈페이지] 📅 선택된 날짜: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
      );
      await _createTestSleepDataForDate(selectedDate);
    }
  }

  // 특정 날짜로 수면데이터 생성
  Future<void> _createTestSleepDataForDate(DateTime targetDate) async {
    debugPrint(
      '[홈페이지] 📅 특정 날짜 수면데이터 생성 시작: ${DateFormat('yyyy-MM-dd').format(targetDate)}',
    );

    // 기존 캐시된 데이터 먼저 삭제
    await _clearAllSleepDataCache();
    debugPrint('[홈페이지] 🗑️ 기존 캐시 삭제 후 새 데이터 생성');

    final prefs = await SharedPreferences.getInstance();
    final token = await storage.read(key: 'jwt');
    final userId =
        token != null ? JwtUtils.extractUserIdFromToken(token) : null;

    if (userId == null) {
      debugPrint('[홈페이지] ❌ userID를 찾을 수 없음');
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

    try {
      // 건강앱에서 해당 날짜의 수면 데이터 가져오기
      final healthData = await _getHealthSleepData(targetDate);

      if (healthData == null || healthData.isEmpty) {
        debugPrint('[홈페이지] ❌ 해당 날짜에 건강앱 수면 데이터가 없음');
        return;
      }

      // 건강앱 데이터를 API 스펙에 맞게 변환
      final sleepData = _convertHealthDataToApiFormat(
        healthData,
        userId,
        dateStr,
      );
      await prefs.setString('pendingSleepPayload', jsonEncode(sleepData));
      debugPrint('[홈페이지] ✅ 특정 날짜 건강앱 수면데이터 생성 완료: $dateStr');
    } catch (e) {
      debugPrint('[홈페이지] ❌ 특정 날짜 건강앱 데이터 처리 중 오류: $e');
      return;
    }

    // 즉시 전송 시도
    await _clearLastSentDate();
    _tryUploadPendingSleepData(retryCount: 0);
  }

  // 베타테스터를 위한 디버깅 정보 출력
  Future<void> _debugSleepDataStatus() async {
    debugPrint('[홈페이지] ===== 베타테스터 디버깅 정보 =====');

    final prefs = await SharedPreferences.getInstance();
    final token = await storage.read(key: 'jwt');
    final username = await storage.read(key: 'username');
    final userId =
        token != null ? JwtUtils.extractUserIdFromToken(token) : null;
    final payloadJson = prefs.getString('pendingSleepPayload');
    final lastSentDate = prefs.getString('lastSentDate');

    debugPrint('[홈페이지] 📱 사용자명: ${username ?? "없음"}');
    debugPrint(
      '[홈페이지] 🔑 JWT 토큰: ${token != null ? "있음 (${token.length}자)" : "없음"}',
    );
    debugPrint('[홈페이지] 👤 사용자 ID: ${userId ?? "없음"}');
    debugPrint(
      '[홈페이지] 📦 수면데이터: ${payloadJson != null ? "있음 (${payloadJson.length}자)" : "없음"}',
    );
    debugPrint('[홈페이지] 📅 마지막 전송일: ${lastSentDate ?? "없음"}');
    debugPrint('[홈페이지] 🔄 로그인 상태: $_isLoggedIn');

    // 현재 기기 시간 정보 추가
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    debugPrint(
      '[홈페이지] 🕐 현재 기기 시간: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    debugPrint('[홈페이지] 📅 기기 기준 오늘: ${DateFormat('yyyy-MM-dd').format(now)}');
    debugPrint(
      '[홈페이지] 📅 기기 기준 어제: ${DateFormat('yyyy-MM-dd').format(yesterday)}',
    );

    // JWT 토큰의 payload 내용 확인
    if (token != null) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64.normalize(payload);
          final resp = utf8.decode(base64Url.decode(normalized));
          final payloadMap = json.decode(resp) as Map<String, dynamic>;

          debugPrint('[홈페이지] 🔍 JWT Payload 내용:');
          debugPrint('[홈페이지] 🔍 - 사용 가능한 필드: ${payloadMap.keys.toList()}');
          debugPrint('[홈페이지] 🔍 - userID: ${payloadMap['userID']}');
          debugPrint('[홈페이지] 🔍 - userId: ${payloadMap['userId']}');
          debugPrint('[홈페이지] 🔍 - id: ${payloadMap['id']}');
          debugPrint('[홈페이지] 🔍 - sub: ${payloadMap['sub']}');
          debugPrint('[홈페이지] 🔍 - username: ${payloadMap['username']}');
          debugPrint('[홈페이지] 🔍 - exp: ${payloadMap['exp']}');
        }
      } catch (e) {
        debugPrint('[홈페이지] ❌ JWT payload 파싱 오류: $e');
      }
    }

    if (payloadJson != null) {
      try {
        final payload = json.decode(payloadJson) as Map<String, dynamic>;
        debugPrint(
          '[홈페이지] 📊 수면데이터 내용: ${payload['date']} (${payload['userID']})',
        );
      } catch (e) {
        debugPrint('[홈페이지] ❌ 수면데이터 파싱 오류: $e');
      }
    }

    debugPrint('[홈페이지] ===== 디버깅 정보 끝 =====');
  }

  // lastSentDate 초기화 함수
  Future<void> _clearLastSentDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastSentDate');
    debugPrint('[홈페이지] 🗑️ lastSentDate 초기화 완료 - 강제 전송 가능');
  }

  // 모든 수면데이터 캐시 삭제
  Future<void> _clearAllSleepDataCache() async {
    final prefs = await SharedPreferences.getInstance();

    // 모든 수면 관련 캐시 삭제
    await prefs.remove('pendingSleepPayload');
    await prefs.remove('latestServerSleepData');
    await prefs.remove('lastSentDate');
    await prefs.remove('sleepDataJustUploaded');
    await prefs.remove('sleepScoreUpdated');

    debugPrint('[홈페이지] 🗑️ 모든 수면데이터 캐시 삭제 완료');
  }

  Future<void> _checkProfileUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileUpdated = prefs.getBool('profileUpdated') ?? false;
      debugPrint('[홈페이지] 프로필 업데이트 체크 - profileUpdated: $profileUpdated');

      if (profileUpdated) {
        debugPrint('[홈페이지] 프로필 업데이트 감지됨 - 로컬 저장소에서 이름 새로고침 시작');
        // 서버에서 가져오지 말고 로컬 저장소에서 직접 가져오기
        await _loadUserName();
        await prefs.remove('profileUpdated');
        debugPrint('[홈페이지] 프로필 업데이트 감지 - 로컬 저장소에서 이름 새로고침 완료');
      } else {
        debugPrint('[홈페이지] 프로필 업데이트 없음 - 캐시에서 이름 로드');
        // 일반 케이스는 캐시만 살짝 읽어와 반영
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _loadUserName();
        });
      }
    } catch (e) {
      debugPrint('[홈페이지] 프로필 업데이트 체크 실패: $e');
      if (mounted) _loadUserName();
    }
  }

  // 사용자 이름 로드
  Future<void> _loadUserName() async {
    try {
      // FlutterSecureStorage에서 username 가져오기
      final userName = await storage.read(key: 'username');
      final newUserName =
          userName != null && userName.isNotEmpty ? userName : '사용자';

      // 값이 실제로 변경되었을 때만 setState 호출
      if (_userName != newUserName) {
        if (mounted) {
          setState(() {
            _userName = newUserName;
          });
          debugPrint('[홈페이지] 사용자 이름 업데이트: $newUserName');
        }
      }
    } catch (e) {
      if (_userName != '사용자' && mounted) {
        setState(() {
          _userName = '사용자';
        });
      }
      debugPrint('[홈페이지] 사용자 이름 로드 실패: $e');
    }
  }

  // 데이터 초기화 및 수면데이터 전송
  Future<void> _initializeData() async {
    // 기존 잘못된 데이터 정리 (먼저 실행)
    await _cleanupInvalidData();

    // 데이터 정리 완료 후 수면데이터 전송 시도 (약간의 지연 후 실행)
    Future.delayed(const Duration(milliseconds: 500), () {
      _tryUploadPendingSleepData(retryCount: 0);
    });

    // 사운드 추천 요청 (홈화면 접속 시 미리 실행)
    _requestSoundRecommendation();
  }

  // 기존 잘못된 데이터 정리
  Future<void> _cleanupInvalidData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSentDate = prefs.getString('lastSentDate');
    final payloadJson = prefs.getString('pendingSleepPayload');

    if (lastSentDate != null && payloadJson != null) {
      try {
        final payload = json.decode(payloadJson) as Map<String, dynamic>;
        final dataDate = (payload['date'] as String?) ?? '';

        // lastSentDate가 데이터 날짜와 다르면 정리
        if (lastSentDate != dataDate) {
          await prefs.remove('lastSentDate');
          debugPrint('[홈페이지] 잘못된 lastSentDate 정리: $lastSentDate → $dataDate');
        }
      } catch (e) {
        debugPrint('[홈페이지] 데이터 정리 중 오류: $e');
      }
    }

    // 추가: Postman에서 데이터가 없다면 lastSentDate도 정리
    if (lastSentDate != null) {
      final token = await storage.read(key: 'jwt');
      // JWT 토큰에서 userID 추출
      final userId =
          token != null ? JwtUtils.extractUserIdFromToken(token) : null;

      if (token != null && userId != null) {
        // 서버에서 실제 데이터 존재 여부 확인
        final serverData = await _getSleepDataFromServer(
          userId: userId,
          token: token,
          date: lastSentDate,
        );

        // 서버에 데이터가 없으면 lastSentDate 정리
        if (serverData == null) {
          await prefs.remove('lastSentDate');
          debugPrint('[홈페이지] 서버에 데이터가 없어서 lastSentDate 정리: $lastSentDate');
        }
      }
    }
  }

  // 건강앱에서 실제 수면데이터 생성
  Future<void> _createTestSleepData() async {
    debugPrint('[홈페이지] 건강앱 수면데이터 생성 시작');

    final prefs = await SharedPreferences.getInstance();

    // 기존 캐시된 데이터 먼저 삭제
    await _clearAllSleepDataCache();
    debugPrint('[홈페이지] 🗑️ 기존 캐시 삭제 후 새 데이터 생성');

    // JWT에서 실제 userID 추출
    final token = await storage.read(key: 'jwt');
    final userId =
        token != null ? JwtUtils.extractUserIdFromToken(token) : null;

    debugPrint('[홈페이지] 🔍 JWT 토큰 상태: ${token != null ? "있음" : "없음"}');
    debugPrint('[홈페이지] 🔍 추출된 userID: ${userId ?? "없음"}');

    if (userId == null) {
      debugPrint('[홈페이지] ❌ userID를 찾을 수 없음 - 수면데이터 생성 건너뛰기');
      debugPrint('[홈페이지] ❌ JWT 토큰이 없거나 userID 추출 실패');
      return;
    }

    // 전날 수면데이터로 생성 (오늘이 8일이면 7일 데이터)
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    debugPrint(
      '[홈페이지] 🕐 현재 기기 시간: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
    );
    debugPrint('[홈페이지] 📅 오늘 날짜: $todayStr');
    debugPrint('[홈페이지] 📅 어제 날짜: $yesterdayStr');
    debugPrint('[홈페이지] 📅 생성할 데이터 날짜: $yesterdayStr');

    try {
      // 건강앱에서 수면 데이터 가져오기
      final healthData = await _getHealthSleepData(yesterday);

      if (healthData == null || healthData.isEmpty) {
        debugPrint('[홈페이지] ❌ 건강앱에서 수면 데이터를 가져올 수 없음');
        return;
      }

      // 건강앱 데이터를 API 스펙에 맞게 변환
      final sleepData = _convertHealthDataToApiFormat(
        healthData,
        userId,
        yesterdayStr,
      );

      await prefs.setString('pendingSleepPayload', jsonEncode(sleepData));
      debugPrint(
        '[홈페이지] ✅ 건강앱 수면데이터 생성 완료: ${sleepData['date']} (userID: $userId)',
      );
      debugPrint('[홈페이지] ✅ pendingSleepPayload 저장됨');
    } catch (e) {
      debugPrint('[홈페이지] ❌ 건강앱 데이터 처리 중 오류: $e');
      return;
    }
  }

  // 건강앱에서 수면 데이터 가져오기
  Future<List<HealthDataPoint>?> _getHealthSleepData(DateTime targetDay) async {
    try {
      final types = [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_ASLEEP, // ✅ 추가
      ];
      final permissions = List.filled(types.length, HealthDataAccess.READ);

      final granted = await Health().requestAuthorization(
        types,
        permissions: permissions,
      );
      if (!granted) {
        debugPrint('[홈페이지] ❌ 건강앱 권한이 거부됨');
        return null;
      }

      // ✅ 전날 18:00 ~ 당일 12:00
      final anchor = DateTime(targetDay.year, targetDay.month, targetDay.day);
      final startTime = anchor.subtract(const Duration(hours: 6)); // D-1 18:00
      final endTime = anchor.add(const Duration(hours: 12)); // D 12:00

      final healthData = await Health().getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: types,
      );

      debugPrint('[홈페이지] 📊 건강앱에서 가져온 수면 데이터 개수: ${healthData.length}');
      if (healthData.isEmpty) return null;

      return healthData;
    } catch (e) {
      debugPrint('[홈페이지] ❌ 건강앱 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // 건강앱 데이터를 API 스펙에 맞게 변환
  Map<String, dynamic> _convertHealthDataToApiFormat(
    List<HealthDataPoint> healthData,
    String userId,
    String date,
  ) {
    int inBedMinutes = 0;
    int awakeMinutes = 0;
    int deepMinutes = 0;
    int remMinutes = 0;
    int lightMinutes = 0;
    int coreAsleepMinutes = 0; // ✅ SLEEP_ASLEEP용

    DateTime? overallStart; // ✅ 모든 포인트 기준 시작
    DateTime? overallEnd; // ✅ 모든 포인트 기준 종료

    final segments = <Map<String, dynamic>>[];

    for (final data in healthData) {
      final duration = data.dateTo.difference(data.dateFrom).inMinutes;

      // ✅ 모든 포인트로 외피 계산
      overallStart =
          (overallStart == null || data.dateFrom.isBefore(overallStart!))
              ? data.dateFrom
              : overallStart;
      overallEnd =
          (overallEnd == null || data.dateTo.isAfter(overallEnd!))
              ? data.dateTo
              : overallEnd;

      debugPrint(
        '[홈페이지] 🔍 수면 데이터: ${data.type} - ${data.dateFrom} ~ ${data.dateTo} (${duration}분)',
      );

      switch (data.type) {
        case HealthDataType.SLEEP_IN_BED:
          inBedMinutes += duration;
          break;
        case HealthDataType.SLEEP_AWAKE:
          awakeMinutes += duration;
          segments.add({
            "startTime": DateFormat('HH:mm').format(data.dateFrom),
            "endTime": DateFormat('HH:mm').format(data.dateTo),
            "stage": "awake",
          });
          break;
        case HealthDataType.SLEEP_DEEP:
          deepMinutes += duration;
          segments.add({
            "startTime": DateFormat('HH:mm').format(data.dateFrom),
            "endTime": DateFormat('HH:mm').format(data.dateTo),
            "stage": "deep",
          });
          break;
        case HealthDataType.SLEEP_REM:
          remMinutes += duration;
          segments.add({
            "startTime": DateFormat('HH:mm').format(data.dateFrom),
            "endTime": DateFormat('HH:mm').format(data.dateTo),
            "stage": "rem",
          });
          break;
        case HealthDataType.SLEEP_LIGHT:
          lightMinutes += duration;
          segments.add({
            "startTime": DateFormat('HH:mm').format(data.dateFrom),
            "endTime": DateFormat('HH:mm').format(data.dateTo),
            "stage": "light",
          });
          break;
        case HealthDataType.SLEEP_ASLEEP:
          // ✅ 플랫폼에 따라 Core/Unspecified가 여기로 옴. 서버 스펙에 'asleep'이 없다면 light로 흡수.
          coreAsleepMinutes += duration;
          // 필요하면 세그먼트도 light로 넣기:
          segments.add({
            "startTime": DateFormat('HH:mm').format(data.dateFrom),
            "endTime": DateFormat('HH:mm').format(data.dateTo),
            "stage": "light",
          });
          break;
        default:
          break;
      }
    }

    // ✅ 실제 수면(깊+REM+얕음+코어)
    final actualSleepMinutes =
        deepMinutes + remMinutes + (lightMinutes + coreAsleepMinutes);
    final scoringTotal = actualSleepMinutes + awakeMinutes; // ✅ 점수용 분모

    // ✅ 외피(첫 시작~마지막 종료)
    final envelopeMinutes =
        (overallStart != null && overallEnd != null)
            ? overallEnd!.difference(overallStart!).inMinutes
            : 0;

    // ✅ 총 수면시간 = max(실제수면+깸, 외피)  → 자정 경계/타입 누락에 안전
    final totalSleepDuration = math.max(
      actualSleepMinutes + awakeMinutes,
      envelopeMinutes,
    );

    // 시작/종료 시각도 외피 기준으로
    final startClock =
        overallStart != null
            ? DateFormat('HH:mm').format(overallStart!)
            : "22:00";
    final endClock =
        overallEnd != null ? DateFormat('HH:mm').format(overallEnd!) : "07:00";

    // 디버그
    debugPrint('[홈페이지] 📊 수면 시간 계산 결과:');
    debugPrint(
      '  envelope: ${envelopeMinutes}분, actual: ${actualSleepMinutes}분, awake: ${awakeMinutes}분',
    );
    debugPrint('  totalSleepDuration(업로드): ${totalSleepDuration}분');

    return {
      "userID": userId,
      "date": date,
      "sleepTime": {"startTime": startClock, "endTime": endClock},
      "Duration": {
        "totalSleepDuration":
            totalSleepDuration, // 업로드용: max(actual+awake, envelope)
        "deepSleepDuration": deepMinutes,
        "remSleepDuration": remMinutes,
        "lightSleepDuration": lightMinutes + coreAsleepMinutes,
        "awakeDuration": awakeMinutes,
      },
      "segments": segments,
      "sleepScore": _calculateSleepScore(
        actualSleepMinutes, // ✅ 실제 수면 시간만으로 점수 계산
        deepMinutes,
        remMinutes,
        lightMinutes + coreAsleepMinutes,
        awakeMinutes,
      ),
    };
  }

  // 수면 점수 계산
  int _calculateSleepScore(
    int totalSleepMinutes,
    int deepMinutes,
    int remMinutes,
    int lightMinutes,
    int awakeMinutes,
  ) {
    // 기본 점수 50점에서 시작 (더 엄격하게)
    int score = 50;

    // 총 수면 시간에 따른 점수 조정 (7-8시간이 최적)
    if (totalSleepMinutes >= 420 && totalSleepMinutes <= 480) {
      score += 15; // 7-8시간: +15점
    } else if (totalSleepMinutes >= 360 && totalSleepMinutes < 420) {
      score += 5; // 6-7시간: +5점
    } else if (totalSleepMinutes > 480 && totalSleepMinutes <= 540) {
      score += 2; // 8-9시간: +2점
    } else {
      score -= 15; // 그 외: -15점
    }

    // 깊은 수면 비율에 따른 점수 조정 (15-20%가 최적)
    final deepRatio =
        totalSleepMinutes > 0 ? (deepMinutes / totalSleepMinutes) * 100 : 0;
    if (deepRatio >= 15 && deepRatio <= 20) {
      score += 8;
    } else if (deepRatio >= 10 && deepRatio < 15) {
      score += 3;
    } else if (deepRatio < 10) {
      score -= 8;
    } else {
      score -= 3;
    }

    // REM 수면 비율에 따른 점수 조정 (20-25%가 최적)
    final remRatio =
        totalSleepMinutes > 0 ? (remMinutes / totalSleepMinutes) * 100 : 0;
    if (remRatio >= 20 && remRatio <= 25) {
      score += 8;
    } else if (remRatio >= 15 && remRatio < 20) {
      score += 3;
    } else if (remRatio < 15) {
      score -= 8;
    } else {
      score -= 3;
    }

    // 깨어있음 시간에 따른 점수 조정 (5% 이하가 좋음)
    final awakeRatio =
        totalSleepMinutes > 0 ? (awakeMinutes / totalSleepMinutes) * 100 : 0;
    if (awakeRatio <= 5) {
      score += 5;
    } else if (awakeRatio <= 10) {
      score += 0;
    } else if (awakeRatio <= 15) {
      score -= 5;
    } else {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  Future<void> _checkLoginStatus() async {
    final username = await storage.read(key: 'username');
    final jwt = await storage.read(key: 'jwt');

    setState(() {
      _isLoggedIn = username != null && jwt != null;
      _isLoading = false; // 로딩 완료
    });

    // 로그인 상태가 확인된 후 수면데이터 생성 및 전송 시도
    if (_isLoggedIn) {
      debugPrint('[홈페이지] 🔄 로그인 확인됨 - 수면데이터 생성 및 전송 예정 (3초 지연)');

      // 먼저 수면데이터 생성 (강제 생성)
      await _createTestSleepData();

      // 그 다음 전송 시도
      Future.delayed(const Duration(milliseconds: 3000), () {
        _tryUploadPendingSleepData(retryCount: 0);
      });
    } else {
      debugPrint('[홈페이지] ❌ 로그인되지 않음 - 수면데이터 생성 및 전송 건너뛰기');
    }
  }

  // ===== 수면데이터 서버 전송 관련 함수들 =====

  // 수면데이터 서버 전송 시도 (재시도 포함)
  Future<void> _tryUploadPendingSleepData({int retryCount = 0}) async {
    debugPrint('[홈페이지] ===== 수면데이터 전송 시작 (시도 ${retryCount + 1}/3) =====');

    final prefs = await SharedPreferences.getInstance();
    debugPrint('[홈페이지] SharedPreferences 초기화 완료');

    final token = await storage.read(key: 'jwt');
    // JWT 토큰에서 userID 추출
    final userId =
        token != null ? JwtUtils.extractUserIdFromToken(token) : null;
    final payloadJson = prefs.getString('pendingSleepPayload');
    final lastSentDate = prefs.getString('lastSentDate'); // yyyy-MM-dd

    debugPrint('[홈페이지] 토큰: ${token != null ? "있음" : "없음"}');
    debugPrint('[홈페이지] 사용자ID: ${userId ?? "없음"}');
    debugPrint('[홈페이지] 수면데이터 페이로드: ${payloadJson != null ? "있음" : "없음"}');
    debugPrint('[홈페이지] 마지막 전송일: ${lastSentDate ?? "없음"}');

    // 페이로드에서 날짜 정보 추출하여 표시
    if (payloadJson != null) {
      try {
        final payload = json.decode(payloadJson) as Map<String, dynamic>;
        final dataDate = (payload['date'] as String?) ?? '';
        debugPrint('[홈페이지] 📅 전송할 수면데이터 날짜: $dataDate');
      } catch (e) {
        debugPrint('[홈페이지] 페이로드 날짜 파싱 오류: $e');
      }
    }

    if (token == null || userId == null || payloadJson == null) {
      debugPrint('[홈페이지] ❌ 필수 데이터 부족으로 전송 중단');
      debugPrint('[홈페이지] ❌ token: ${token != null ? "있음" : "없음"}');
      debugPrint('[홈페이지] ❌ userId: ${userId ?? "없음"}');
      debugPrint('[홈페이지] ❌ payloadJson: ${payloadJson != null ? "있음" : "없음"}');
      return;
    }

    // payload에서 date 읽기 및 userID 업데이트
    Map<String, dynamic> payload;
    try {
      payload = json.decode(payloadJson) as Map<String, dynamic>;
      debugPrint('[홈페이지] 페이로드 파싱 성공: ${payload['date']}');

      // 실제 userID로 업데이트
      payload['userID'] = userId;
      debugPrint('[홈페이지] userID 업데이트: $userId');
    } catch (e) {
      debugPrint('[홈페이지] 페이로드 파싱 실패: $e');
      return;
    }
    final date = (payload['date'] as String?) ?? '';
    if (date.isEmpty) {
      debugPrint('[홈페이지] 날짜 정보 없음');
      return;
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    debugPrint('[홈페이지] 오늘 날짜: $todayStr, 데이터 날짜: $date');

    // 수정: 데이터 날짜와 마지막 전송일을 비교 (오늘 날짜가 아닌)
    debugPrint(
      '[홈페이지] 🔍 날짜 비교: lastSentDate="$lastSentDate", dataDate="$date"',
    );
    if (lastSentDate == date) {
      debugPrint('[홈페이지] ⚠️ 해당 날짜 데이터 이미 전송됨: $date');
      debugPrint('[홈페이지] ⚠️ 전송 건너뛰기 - lastSentDate와 dataDate가 동일함');
      return;
    }

    debugPrint('[홈페이지] ✅ 전송 진행 - lastSentDate와 dataDate가 다름');

    debugPrint('[홈페이지] 서버 전송 시작...');
    try {
      // 업데이트된 payload를 JSON으로 변환
      final updatedPayloadJson = jsonEncode(payload);
      debugPrint('[홈페이지] 전송할 데이터: $updatedPayloadJson');

      final resp = await http.post(
        Uri.parse('https://kooala.tassoo.uk/sleep-data'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: updatedPayloadJson,
      );

      debugPrint('[홈페이지] 서버 응답: ${resp.statusCode}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        debugPrint('[홈페이지] ✅ 수면데이터 전송 성공: $date');

        // 성공 상태 업데이트
        if (mounted) {
          setState(() {});
        }

        // 업로드 성공 → 서버 데이터로 캐시 갱신
        final server = await _getSleepDataFromServer(
          userId: userId,
          token: token,
          date: date,
        );

        // 서버에서 실제로 데이터가 확인된 경우에만 lastSentDate 업데이트
        if (server != null) {
          await prefs.setString('lastSentDate', date);
          await prefs.setString('latestServerSleepData', jsonEncode(server));
          // 업로드 성공 후 서버 데이터 캐시 저장하는 바로 *다음 줄* 정도에 추가
          await prefs.setBool('sleepDataJustUploaded', true); // 🔔 조용한 새로고침 신호

          debugPrint('[홈페이지] 서버 수면데이터 캐시 갱신 완료 및 lastSentDate 업데이트: $date');
        } else {
          debugPrint('[홈페이지] 서버에서 데이터 확인 실패 - 3초 후 재시도');

          // 3초 후 재시도
          Future.delayed(const Duration(seconds: 3), () async {
            final retryServer = await _getSleepDataFromServer(
              userId: userId,
              token: token,
              date: date,
            );

            if (retryServer != null) {
              await prefs.setString('lastSentDate', date);
              await prefs.setString(
                'latestServerSleepData',
                jsonEncode(retryServer),
              );
              debugPrint('[홈페이지] 재시도 성공: 서버 수면데이터 캐시 갱신 완료');
            } else {
              debugPrint('[홈페이지] 재시도 실패: 서버에 데이터가 아직 준비되지 않음');
              // 재시도 실패 시에도 lastSentDate는 업데이트 (POST는 성공했으므로)
              await prefs.setString('lastSentDate', date);
            }
          });
        }
      } else if (resp.statusCode == 409) {
        // 409 Conflict: 이미 같은 시작 시간의 데이터가 존재
        debugPrint('[홈페이지] 409 오류: 기존 데이터 삭제 후 재전송 시도');

        try {
          // 1. 기존 데이터 삭제
          final deleteResp = await http.delete(
            Uri.parse('https://kooala.tassoo.uk/sleep-data/$userId/$date'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (deleteResp.statusCode == 200 || deleteResp.statusCode == 404) {
            debugPrint('[홈페이지] 기존 데이터 삭제 완료 (또는 없음)');

            // 2. 새 데이터 다시 전송
            final retryResp = await http.post(
              Uri.parse('https://kooala.tassoo.uk/sleep-data'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: payloadJson,
            );

            if (retryResp.statusCode == 200 || retryResp.statusCode == 201) {
              debugPrint('[홈페이지] 재전송 성공: $date');
              await prefs.setString('lastSentDate', date);

              // 서버 데이터로 캐시 갱신
              final server = await _getSleepDataFromServer(
                userId: userId,
                token: token,
                date: date,
              );
              if (server != null) {
                await prefs.setString(
                  'latestServerSleepData',
                  jsonEncode(server),
                );
                debugPrint('[홈페이지] 재전송 후 서버 캐시 갱신 완료');
              }
            } else {
              debugPrint(
                '[홈페이지] 재전송 실패: ${retryResp.statusCode} ${retryResp.body}',
              );
            }
          } else {
            debugPrint('[홈페이지] 기존 데이터 삭제 실패: ${deleteResp.statusCode}');
          }
        } catch (e) {
          debugPrint('[홈페이지] 409 오류 처리 중 예외: $e');
        }
      } else {
        debugPrint('[홈페이지] ❌ 수면데이터 전송 실패: ${resp.statusCode} ${resp.body}');
        debugPrint('[홈페이지] ❌ 전송한 데이터: $updatedPayloadJson');
        debugPrint('[홈페이지] ❌ 사용자 ID: $userId');
        debugPrint('[홈페이지] ❌ 데이터 날짜: $date');
        debugPrint('[홈페이지] ❌ JWT 토큰: ${token.substring(0, 20)}...');

        // 실패 시 재시도 (최대 3번)
        if (retryCount < 2) {
          debugPrint('[홈페이지] 🔄 재시도 예정 (${retryCount + 1}/3)');
          Future.delayed(Duration(seconds: (retryCount + 1) * 2), () {
            _tryUploadPendingSleepData(retryCount: retryCount + 1);
          });
        } else {
          debugPrint('[홈페이지] ❌ 최대 재시도 횟수 초과');
        }
      }
    } catch (e) {
      debugPrint('[홈페이지] ❌ 수면데이터 전송 오류: $e');

      // 오류 시 재시도 (최대 3번)
      if (retryCount < 2) {
        debugPrint('[홈페이지] 🔄 오류로 인한 재시도 예정 (${retryCount + 1}/3)');
        Future.delayed(Duration(seconds: (retryCount + 1) * 2), () {
          _tryUploadPendingSleepData(retryCount: retryCount + 1);
        });
      } else {
        debugPrint('[홈페이지] ❌ 최대 재시도 횟수 초과');
      }
    }
    debugPrint('[홈페이지] ===== 수면데이터 전송 완료 =====');
  }

  // 서버에서 수면데이터 가져오기
  Future<Map<String, dynamic>?> _getSleepDataFromServer({
    required String userId,
    required String token,
    required String date,
  }) async {
    try {
      final uri = Uri.parse(
        'https://kooala.tassoo.uk/sleep-data/$userId/$date',
      );
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final record =
            (body is Map && body['data'] is List)
                ? (body['data'] as List).first
                : (body is Map ? body : null);
        return (record is Map<String, dynamic>) ? record : null;
      } else {
        debugPrint('[홈페이지] 서버 데이터 가져오기 실패: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[홈페이지] 서버 데이터 가져오기 오류: $e');
    }
    return null;
  }

  // 사운드 추천 요청 및 결과 미리 받기
  Future<void> _requestSoundRecommendation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await JwtUtils.getCurrentUserId();

      if (userId == null) {
        debugPrint('[홈페이지] userID가 없어서 사운드 추천 요청 불가');
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      debugPrint('[홈페이지] 사운드 추천 요청 시작: $userId, $dateStr');

      // 1단계: 추천 요청
      final response = await http.post(
        Uri.parse('https://kooala.tassoo.uk/recommend-sound/execute'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
        },
        body: jsonEncode({'userID': userId, 'date': dateStr}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[홈페이지] 사운드 추천 요청 성공');

        // 추천 요청 완료 표시
        await prefs.setString('soundRecommendationRequested', dateStr);

        // 2단계: 잠시 기다린 후 결과 가져오기
        await Future.delayed(const Duration(seconds: 3));

        // 3단계: 추천 결과 가져오기
        final resultsResponse = await http.get(
          Uri.parse(
            'https://kooala.tassoo.uk/recommend-sound/$userId/$dateStr/results',
          ),
          headers: {
            'Authorization': 'Bearer ${await JwtUtils.getCurrentToken()}',
          },
        );

        if (resultsResponse.statusCode == 200) {
          final resultsData = jsonDecode(resultsResponse.body);
          debugPrint('[홈페이지] 추천 결과 응답 전체: $resultsData');
          debugPrint('[홈페이지] 응답 키들: ${resultsData.keys.toList()}');

          if (resultsData['recommended_sounds'] != null) {
            final recommendations = resultsData['recommended_sounds'] as List;
            debugPrint('[홈페이지] recommended_sounds 데이터: $recommendations');

            // 추천 결과를 SharedPreferences에 저장
            final recommendationsJson = jsonEncode(recommendations);
            await prefs.setString('soundRecommendations', recommendationsJson);
            await prefs.setString('soundRecommendationsDate', dateStr);

            debugPrint('[홈페이지] SharedPreferences 저장 완료:');
            debugPrint(
              '[홈페이지] soundRecommendations 키에 저장: $recommendationsJson',
            );
            debugPrint('[홈페이지] soundRecommendationsDate 키에 저장: $dateStr');

            // 저장 확인
            final savedCheck = prefs.getString('soundRecommendations');
            final savedDateCheck = prefs.getString('soundRecommendationsDate');
            debugPrint('[홈페이지] 저장 확인 - soundRecommendations: $savedCheck');
            debugPrint(
              '[홈페이지] 저장 확인 - soundRecommendationsDate: $savedDateCheck',
            );

            debugPrint('[홈페이지] 사운드 추천 결과 미리 저장 완료: ${recommendations.length}개');
          } else {
            debugPrint('[홈페이지] 사운드 추천 결과 데이터 없음');
            debugPrint(
              '[홈페이지] recommended_sounds: ${resultsData['recommended_sounds']}',
            );
          }
        } else {
          debugPrint('[홈페이지] 사운드 추천 결과 가져오기 실패: ${resultsResponse.statusCode}');
          debugPrint('[홈페이지] 응답 내용: ${resultsResponse.body}');
        }
      } else {
        debugPrint(
          '[홈페이지] 사운드 추천 요청 실패: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[홈페이지] 사운드 추천 요청 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '알라와 코잘라',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 베타테스터를 위한 디버깅 정보 표시 버튼
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () async {
              await _showDebugInfoDialog();
            },
            tooltip: '디버깅 정보 표시 (베타테스터용)',
          ),
          // 베타테스터를 위한 날짜 수정 버튼
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () async {
              debugPrint('[홈페이지] 📅 베타테스터 날짜 수정 버튼 클릭');
              await _showDatePickerDialog();
            },
            tooltip: '수면데이터 날짜 수정 (베타테스터용)',
          ),
          // 베타테스터를 위한 수면데이터 수동 전송 버튼
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              debugPrint('[홈페이지] 🔄 베타테스터 수동 새로고침 버튼 클릭');

              // 즉시 디버깅 정보 출력
              await _debugSleepDataStatus();

              // 강제 새로고침 실행
              await _forceRefresh();

              // 3초 후 한 번 더 시도
              Future.delayed(const Duration(seconds: 3), () async {
                debugPrint('[홈페이지] 🔄 수동 버튼 3초 후 재시도');
                await _forceRefresh();
              });
            },
            tooltip: '수면데이터 수동 전송 (베타테스터용)',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    )
                    : _isLoggedIn
                    ? _buildMainContent()
                    : _buildLoginRequired(),
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
      // 숨겨진 새로고침 버튼 (테스트용)
    );
  }

  Widget _buildGlobalMiniPlayer() {
    final service = GlobalSoundService();

    return AnimatedBuilder(
      animation: service,
      builder: (context, child) {
        if (service.currentPlaying == null || service.currentPlaying!.isEmpty) {
          return const SizedBox.shrink();
        }

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

  Widget _buildLoginRequired() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '로그인해주세요',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 코알라 캐릭터와 환영 메시지
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
                Image.asset(
                  'lib/assets/koala.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  '${_userName.isNotEmpty ? _userName : "사용자"}님, 안녕하세요!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '알라와 함께 더 나은 수면을 경험해보세요',
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

          const SizedBox(height: 32),

          // 코알라와 대화하기 (특별 강조)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '코알라와 대화하기',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'AI 코알라와 음성으로 대화하며\n수면에 대한 조언을 받아보세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/real-home'),
                    icon: const Icon(Icons.mic, color: Colors.white),
                    label: const Text(
                      '대화 시작하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 핵심 기능들
          _buildFeatureSection(
            context,
            title: '수면 관리',
            icon: Icons.bedtime,
            color: const Color(0xFF5E35B1),
            features: [
              _buildFeatureItem(
                context,
                icon: Icons.analytics,
                title: '수면 분석',
                subtitle: '상세한 수면 데이터와 차트',
                onTap: () => Navigator.pushNamed(context, '/sleep'),
              ),
              _buildFeatureItem(
                context,
                icon: Icons.timeline,
                title: '수면 차트',
                subtitle: '서버 기반 수면 분석 차트',
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/sleep-chart',
                    arguments: {'date': DateTime.now()},
                  );
                },
              ),
              _buildFeatureItem(
                context,
                icon: Icons.access_time,
                title: '수면 목표 설정',
                subtitle: '개인 맞춤 수면 목표 관리',
                onTap: () => Navigator.pushNamed(context, '/time-set'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildFeatureSection(
            context,
            title: '수면 환경',
            icon: Icons.music_note,
            color: const Color(0xFFFF9800),
            features: [
              _buildFeatureItem(
                context,
                icon: Icons.music_note,
                title: '수면 사운드',
                subtitle: 'AI 추천 수면 유도 음악',
                onTap: () => Navigator.pushNamed(context, '/sound'),
              ),
              _buildFeatureItem(
                context,
                icon: Icons.lightbulb,
                title: '조명 관리',
                subtitle: '수면 환경 조명 설정',
                onTap: () => Navigator.pushNamed(context, '/light-control'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 기타 기능들
          Container(
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
                  children: const [
                    Icon(Icons.more_horiz, color: Colors.white70, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '기타 기능',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAccessButton(
                        context,
                        icon: Icons.person,
                        label: '프로필 수정',
                        onTap:
                            () => Navigator.pushNamed(context, '/edit-account'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAccessButton(
                        context,
                        icon: _isLoggedIn ? Icons.logout : Icons.login,
                        label: _isLoggedIn ? '로그아웃' : '로그인',
                        onTap:
                            _isLoggedIn
                                ? () async {
                                  // 로그아웃 로직
                                  final storage = FlutterSecureStorage();
                                  await storage.delete(key: 'username');
                                  await storage.delete(key: 'jwt');
                                  setState(() {
                                    _isLoggedIn = false;
                                  });
                                }
                                : () => Navigator.pushNamed(context, '/login'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAccessButton(
                        context,
                        icon: Icons.question_answer,
                        label: '자주 묻는 질문',
                        onTap: () => Navigator.pushNamed(context, '/faq'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAccessButton(
                        context,
                        icon: Icons.description,
                        label: '이용약관/개인정보',
                        onTap: () => Navigator.pushNamed(context, '/notice'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> features,
  }) {
    return Container(
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
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features,
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E21),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF6C63FF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E21),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
