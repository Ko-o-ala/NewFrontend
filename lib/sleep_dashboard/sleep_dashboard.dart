import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:my_app/Top_Nav.dart';
import 'package:my_app/sleep_dashboard/monthly_sleep_screen.dart';
import 'package:my_app/sleep_dashboard/weekly_sleep_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/jwt_utils.dart';

final storage = FlutterSecureStorage();

class SleepDashboard extends StatefulWidget {
  final Duration? goalSleepDuration;
  const SleepDashboard({Key? key, this.goalSleepDuration}) : super(key: key);

  @override
  State<SleepDashboard> createState() => _SleepDashboardState();
}

class _SleepDashboardState extends State<SleepDashboard>
    with WidgetsBindingObserver {
  String formattedDuration = '불러오는 중...';
  String username = '사용자';
  String fm(DateTime t) => t.toIso8601String().substring(11, 16);
  String goalText = '미설정';
  String _fmtMin(int m) => '${m ~/ 60}시간 ${m % 60}분';
  bool get _inMidnightWindow {
    final h = DateTime.now().hour;
    return h >= 0 && h < 4; // 00:00 ~ 03:59
  }

  void _scheduleAutoRefreshAt4am() {
    final now = DateTime.now();
    final four = DateTime(now.year, now.month, now.day, 4);
    final delay = four.isAfter(now) ? four.difference(now) : Duration.zero;
    if (delay > Duration.zero) {
      Future.delayed(delay, () {
        if (!mounted) return;
        _fetchTodaySleep(); // 4시에 자동 새로고침
        setState(() {}); // 배너 자동 숨김
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadGoalText();
    _fetchTodaySleep();
    WidgetsBinding.instance.addObserver(this);

    if (_inMidnightWindow) _scheduleAutoRefreshAt4am();
  }

  // 목표 수면시간과 실제 수면시간을 비교하는 함수
  String _getSleepComparisonText() {
    if (goalText == '미설정' || goalText == '시간 없음') {
      return '오늘 $formattedDuration 수면하셨네요.';
    }

    if (formattedDuration == '불러오는 중...') {
      return '오늘 $formattedDuration 수면하셨네요.';
    }

    // 목표 시간을 분 단위로 변환
    final goalRegex = RegExp(r'(\d+)시간\s*(\d+)분');
    final goalMatch = goalRegex.firstMatch(goalText);
    if (goalMatch == null) {
      return '오늘 $formattedDuration 수면하셨네요.';
    }

    final goalHours = int.parse(goalMatch.group(1)!);
    final goalMinutes = int.parse(goalMatch.group(2)!);
    final goalTotalMinutes = goalHours * 60 + goalMinutes;

    // 실제 수면시간을 분 단위로 변환
    final actualRegex = RegExp(r'(\d+)시간\s*(\d+)분');
    final actualMatch = actualRegex.firstMatch(formattedDuration);
    if (actualMatch == null) {
      return '오늘 $formattedDuration 수면하셨네요.';
    }

    final actualHours = int.parse(actualMatch.group(1)!);
    final actualMinutes = int.parse(actualMatch.group(2)!);
    final actualTotalMinutes = actualHours * 60 + actualMinutes;

    // 목표 대비 달성률 계산 (100% 이상이면 목표 달성)
    final percentage = (actualTotalMinutes / goalTotalMinutes * 100).round();

    if (percentage >= 100) {
      if (percentage > 100) {
        final diffMinutes = actualTotalMinutes - goalTotalMinutes;
        final diffHours = diffMinutes ~/ 60;
        final diffMins = diffMinutes % 60;
        if (diffHours > 0) {
          return '🎉 목표달성! ${diffHours}시간 ${diffMins}분 더 잘 잤어요!';
        } else {
          return '🎉 목표달성! ${diffMins}분 더 잘 잤어요!';
        }
      } else {
        return '🎉 목표달성! $formattedDuration 수면 완료';
      }
    } else {
      final diffMinutes = goalTotalMinutes - actualTotalMinutes;
      final diffHours = diffMinutes ~/ 60;
      final diffMins = diffMinutes % 60;
      if (diffHours > 0) {
        return '😔 아쉽네요. 목표까지 ${diffHours}시간 ${diffMins}분 부족';
      } else {
        return '😔 아쉽네요. 목표까지 ${diffMins}분 부족';
      }
    }
  }

  Duration? goalSleepDuration;
  DateTime? sleepStartReal;
  DateTime? sleepEndReal;
  bool _isLoggedIn = false;
  Duration? todaySleep;
  DateTime? sleepStart;
  DateTime? sleepEnd;
  int deepMin = 0, remMin = 0, lightMin = 0, awakeMin = 0;
  List<HealthDataPoint> healthData = [];
  int sleepScore = 0;

  // 요일별 목표 수면 시간 가져오기
  Future<String> _getGoalTextForWeekday(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weekday = date.weekday; // 1=월요일, 7=일요일

      // 요일별 목표 시간 가져오기
      final goalKey = 'sleep_goal_weekday_$weekday';
      final goalMinutes = prefs.getInt(goalKey);

      if (goalMinutes != null && goalMinutes > 0) {
        final hours = goalMinutes ~/ 60;
        final minutes = goalMinutes % 60;
        return '${hours}시간 ${minutes}분';
      } else {
        return '시간 없음';
      }
    } catch (e) {
      return '시간 없음';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱 생명주기 상태 변경 시 추가 작업이 필요하면 여기에 추가
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _recalcScore() {
    if (sleepStart == null || sleepEnd == null || healthData.isEmpty) return;
    final newScore = calculateSleepScore(
      data: healthData,
      sleepStart: (sleepStartReal ?? sleepStart!),
      sleepEnd: (sleepEndReal ?? sleepEnd!),
      goalSleepDuration:
          (goalSleepDuration ??
              widget.goalSleepDuration ??
              const Duration(hours: 8)),
    );
    setState(() => sleepScore = newScore);
    _savePendingPayload();
  }

  Future<void> _applyServerCacheIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('latestServerSleepData');
    if (jsonStr == null) return;
    try {
      final m = json.decode(jsonStr) as Map<String, dynamic>;
      final durationMin = (m['Duration']?['totalSleepDuration'] ?? 0) as int;
      final hrs = durationMin ~/ 60;
      final mins = durationMin % 60;
      final awakeMin = (m['Duration']?['awakeDuration'] ?? 0) as int;
      //final inBedMin = durationMin + awakeMin; // ✅ 깨어있음 포함
      // setState(() {
      //     formattedDuration = '${hrs}시간 ${mins}분';
      // sleepScore = (m['sleepScore'] as int?) ?? sleepScore;
      //  });
    } catch (_) {}
  }

  // ⬇️ _SleepDashboardState 클래스 안에 추가
  List<Map<String, String>> _buildSegments() {
    return healthData
        .where(
          (d) =>
              d.type == HealthDataType.SLEEP_DEEP ||
              d.type == HealthDataType.SLEEP_REM ||
              d.type == HealthDataType.SLEEP_LIGHT ||
              d.type == HealthDataType.SLEEP_ASLEEP ||
              d.type == HealthDataType.SLEEP_AWAKE,
        )
        .map((d) {
          String stage;
          switch (d.type) {
            case HealthDataType.SLEEP_DEEP:
              stage = "deep";
              break;
            case HealthDataType.SLEEP_REM:
              stage = "rem";
              break;
            case HealthDataType.SLEEP_LIGHT:
            case HealthDataType.SLEEP_ASLEEP:
              stage = "light";
              break;
            case HealthDataType.SLEEP_AWAKE:
              stage = "awake";
              break;
            default:
              stage = "unknown";
          }
          return {
            "startTime": d.dateFrom.toIso8601String().substring(11, 16),
            "endTime": d.dateTo.toIso8601String().substring(11, 16),
            "stage": stage,
          };
        })
        .toList();
  }

  Future<void> _refreshFromServerByRealStart() async {
    final token = await storage.read(key: 'jwt');
    final userId = await storage.read(key: 'userID');
    final base = sleepStartReal ?? sleepStart;
    if (token == null || userId == null || base == null) return;

    // 수정된 날짜 계산: 잠든 시간 기준으로 날짜 결정
    // 잠든 시간이 자정 전이면 그 날짜, 자정 이후면 전날로 처리
    DateTime targetDate;
    if (base.hour < 12) {
      // 자정 이후(00:00~11:59)에 잠들었다면 전날
      targetDate = base.subtract(const Duration(days: 1));
    } else {
      // 자정 이전(12:00~23:59)에 잠들었다면 그 날
      targetDate = base;
    }
    final date = DateFormat('yyyy-MM-dd').format(targetDate);

    final server = await _getSleepDataFromServer(
      userId: userId,
      token: token,
      date: date,
    );
    if (server == null) return;

    final durationMin = (server['Duration']?['totalSleepDuration'] ?? 0) as int;
    final hrs = durationMin ~/ 60;
    final mins = durationMin % 60;
    final awakeMin = (server['Duration']?['awakeDuration'] ?? 0) as int;
    final inBedMin = durationMin + awakeMin; // ✅ 포함

    setState(() {
      formattedDuration = '${inBedMin ~/ 60}시간 ${inBedMin % 60}분';
      sleepScore = (server['sleepScore'] as int?) ?? sleepScore;
    });

    // (선택) 캐시 갱신
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latestServerSleepData', jsonEncode(server));
  }

  Future<void> _savePendingPayload() async {
    final prefs = await SharedPreferences.getInstance();

    // 날짜 계산: 실제 잠든 시각(sleepStartReal) 우선, 없으면 예상 시작(sleepStart)
    final realStart = sleepStartReal ?? sleepStart;
    if (realStart == null || sleepEnd == null) return;

    final uid = await storage.read(key: 'userID');
    if (uid == null) return; // ← 추가 (로그인 전에 저장 방지)

    // 수정된 날짜 계산: 잠든 시간 기준으로 날짜 결정
    // 잠든 시간이 자정 전이면 그 날짜, 자정 이후면 전날로 처리
    // 예: 8월 31일 오후 11시에 잠들면 → 8월 31일 데이터 (자정 전)
    // 예: 9월 1일 새벽 2시에 잠들면 → 8월 31일 데이터 (자정 이후이므로 전날)
    DateTime targetDate;
    if (realStart.hour < 12) {
      // 자정 이후(00:00~11:59)에 잠들었다면 전날
      targetDate = realStart.subtract(const Duration(days: 1));
    } else {
      // 자정 이전(12:00~23:59)에 잠들었다면 그 날
      targetDate = realStart;
    }
    final date = DateFormat('yyyy-MM-dd').format(targetDate);

    final segments = _buildSegments();

    final body = {
      "userID": uid,
      "date": date,
      "sleepTime": {"startTime": fm(sleepStart!), "endTime": fm(sleepEnd!)},
      "Duration": {
        "totalSleepDuration": deepMin + remMin + lightMin,
        "deepSleepDuration": deepMin,
        "remSleepDuration": remMin,
        "lightSleepDuration": lightMin,
        "awakeDuration": awakeMin,
      },
      "segments": segments,
      "sleepScore": sleepScore,
    };

    await prefs.setString('pendingSleepPayload', jsonEncode(body));
    // 오늘 저장한 날짜 메모(선택): 백그라운드 업로드 성공 시 갱신됨
    // await prefs.setString('lastSavedDate', date);
  }

  Future<void> _loadGoalText() async {
    final text = await _getGoalTextForTodayWithEnabledCheck();
    if (!mounted) return;
    setState(() {
      goalText = text;
    });
  }

  // ✅ SleepDashboard 내 _getGoalTextForTodayWithEnabledCheck 보강
  Future<String> _getGoalTextForTodayWithEnabledCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weekday = DateTime.now().weekday; // 1=월 .. 7=일
      bool enabledToday = true;

      // A) sleep_goal_enabled_days : JSON 또는 CSV
      final enabledStr = prefs.getString('sleep_goal_enabled_days');
      if (enabledStr != null) {
        Set<int> enabled = {};
        try {
          final decoded = json.decode(enabledStr);
          if (decoded is List) {
            enabled =
                decoded
                    .map((e) => int.tryParse(e.toString()) ?? -1)
                    .where((v) => v >= 1 && v <= 7)
                    .toSet();
          } else {
            enabled =
                enabledStr
                    .split(RegExp(r'[^\d]+'))
                    .where((s) => s.isNotEmpty)
                    .map(int.parse)
                    .toSet();
          }
        } catch (_) {
          enabled =
              enabledStr
                  .split(RegExp(r'[^\d]+'))
                  .where((s) => s.isNotEmpty)
                  .map(int.parse)
                  .toSet();
        }
        if (enabled.isNotEmpty) enabledToday = enabled.contains(weekday);
      } else {
        // B) 개별 플래그: sleep_goal_enabled_{weekday}
        final flag = prefs.getBool('sleep_goal_enabled_$weekday');
        if (flag != null) enabledToday = flag;
      }

      // C) ✅ SleepGoalScreen이 저장한 selectedDays(0=일~6=토)도 지원
      if (enabledStr == null) {
        // 위 키가 없을 때만 보조로 사용
        final selected = prefs.getStringList('selectedDays');
        if (selected != null && selected.isNotEmpty) {
          final selectedWeekdays =
              selected
                  .map((s) => int.tryParse(s) ?? -1)
                  .where((d) => d >= 0 && d <= 6)
                  .map((d) => d == 0 ? 7 : d) // 0(일) → 7(일)
                  .toSet();
          enabledToday = selectedWeekdays.contains(weekday);
        }
      }

      if (!enabledToday) return '시간 없음';

      final goalKey = 'sleep_goal_weekday_$weekday';
      final goalMinutes = prefs.getInt(goalKey);
      if (goalMinutes != null && goalMinutes > 0) {
        final hours = goalMinutes ~/ 60;
        final minutes = goalMinutes % 60;
        return '${hours}시간 ${minutes}분';
      }
      return '시간 없음';
    } catch (_) {
      return '시간 없음';
    }
  }

  // 전역: 서버에서 하루 데이터 조회
  Future<Map<String, dynamic>?> _getSleepDataFromServer({
    required String userId,
    required String token,
    required String date, // yyyy-MM-dd
  }) async {
    final uri = Uri.parse('https://kooala.tassoo.uk/sleep-data/$userId/$date');
    try {
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final record =
            (body['data'] is List && (body['data'] as List).isNotEmpty)
                ? (body['data'] as List).first
                : (body is Map ? body : null);
        return (record is Map<String, dynamic>) ? record : null;
      } else {
        debugPrint('[GET] ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[GET] error $e');
    }
    return null;
  }

  // 전역: 백그라운드 업로드 + 서버값 캐시 저장 (UI 건드리지 않음)
  Future<void> _tryUploadPending() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = const FlutterSecureStorage();

    final token = await storage.read(key: 'jwt');
    final userId = await storage.read(key: 'userID');
    final payloadJson = prefs.getString('pendingSleepPayload');
    final lastSentDate = prefs.getString('lastSentDate'); // yyyy-MM-dd

    if (token == null || userId == null || payloadJson == null) return;

    // payload에서 date 읽기 (UI 변수 사용 금지)
    Map<String, dynamic> payload;
    try {
      payload = json.decode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final date = (payload['date'] as String?) ?? '';
    if (date.isEmpty) return;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 시간 조건 제거: 앱 접속 시마다 데이터 전송
    // if (now.hour < 15) {
    //   debugPrint('[BG] skip: before 3PM');
    //   return;
    // }
    if (lastSentDate == todayStr) return;

    try {
      final resp = await http.post(
        Uri.parse('https://kooala.tassoo.uk/sleep-data'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: payloadJson,
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await prefs.setString('lastSentDate', todayStr);

        // 업로드 성공 → 서버 진짜 데이터로 캐시 갱신
        final server = await _getSleepDataFromServer(
          userId: userId,
          token: token,
          date: date,
        );
        if (server != null) {
          await prefs.setString('latestServerSleepData', jsonEncode(server));
          debugPrint('[BGFetch][GET] cached latestServerSleepData for $date');
        }

        // 원하면 페이로드 삭제:
        // await prefs.remove('pendingSleepPayload');
      } else {
        debugPrint('[BGFetch][POST] ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('[BGFetch] upload error: $e');
    }
  }

  Future<void> _loadUsername() async {
    try {
      // JWT 토큰 유효성 먼저 확인
      final isLoggedIn = await JwtUtils.isLoggedIn();
      if (!isLoggedIn) {
        setState(() {
          username = '사용자';
          _isLoggedIn = false;
        });
        return;
      }

      // SharedPreferences에서 사용자명 확인 (프로필 수정 후 즉시 반영)
      final prefs = await SharedPreferences.getInstance();
      final userNameFromPrefs = prefs.getString('userName');
      if (userNameFromPrefs != null && userNameFromPrefs.isNotEmpty) {
        setState(() {
          username = userNameFromPrefs;
          _isLoggedIn = true;
        });
        return;
      }

      // 토큰에서 사용자명 추출 시도
      final usernameFromToken = await JwtUtils.getCurrentUsername();
      if (usernameFromToken != null) {
        setState(() {
          username = usernameFromToken;
          _isLoggedIn = true;
        });
        return;
      }

      // 토큰에서 사용자명을 가져올 수 없는 경우 서버에서 프로필 정보 가져오기
      final token = await storage.read(key: 'jwt');
      if (token == null) {
        setState(() {
          username = '사용자';
          _isLoggedIn = false;
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
          final name = userData['data']['name'] ?? '사용자';
          setState(() {
            username = name;
            _isLoggedIn = true;
          });
        } else {
          setState(() {
            username = '사용자';
            _isLoggedIn = false;
          });
        }
      } else {
        setState(() {
          username = '사용자';
          _isLoggedIn = false;
        });
      }
    } catch (e) {
      debugPrint('[USERNAME] Error fetching username: $e');
      setState(() {
        username = '사용자';
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      // 모든 관련 데이터 정리
      await storage.delete(key: 'username');
      await storage.delete(key: 'jwt');
      await storage.delete(key: 'userID');

      // SharedPreferences 데이터도 정리
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastSentDate');
      await prefs.remove('pendingSleepPayload');
      await prefs.remove('latestServerSleepData');

      setState(() {
        username = '사용자';
        _isLoggedIn = false;
      });

      debugPrint('[LOGOUT] 모든 데이터 정리 완료');
    } catch (e) {
      debugPrint('[LOGOUT] 로그아웃 중 오류: $e');
    }
  }

  Future<void> sendSleepData({
    required String userId,
    required String token,
    required DateTime sleepStart,
    required DateTime sleepEnd,
    required int totalSleep,
    required int deepSleep,
    required int remSleep,
    required int lightSleep,
    required int awakeDuration,
    required List<Map<String, String>> segments,
    required int sleepScore,
  }) async {
    final url = Uri.parse('https://kooala.tassoo.uk/sleep-data');

    final realStart = sleepStartReal ?? sleepStart;
    final sleepDate = realStart.subtract(const Duration(hours: 6));
    final date = DateFormat('yyyy-MM-dd').format(sleepDate);

    print('🕒 sleepStartReal: $realStart');
    print('📅 최종 전송 날짜: $date');

    final body = {
      "userID": userId,
      "date": date,
      "sleepTime": {"startTime": fm(sleepStart), "endTime": fm(sleepEnd)},
      "Duration": {
        "totalSleepDuration": totalSleep,
        "deepSleepDuration": deepSleep,
        "remSleepDuration": remSleep,
        "lightSleepDuration": lightSleep,
        "awakeDuration": awakeDuration,
      },
      "segments": segments,
      "sleepScore": sleepScore,
    };

    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final isOk = resp.statusCode >= 200 && resp.statusCode < 300;

    if (isOk) {
      // 201은 바디가 비어있을 수 있으니 파싱은 방어적으로
      final text = resp.body.trim();
      final _ = text.isEmpty ? null : jsonDecode(text);
      // 성공 시 별도 UX가 필요하면 여기서 처리
      return;
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? ''}'),
        ),
      );
    }
  } // ← 이 닫는 중괄호가 꼭 필요합니다!

  int calculateSleepScore({
    required List<HealthDataPoint> data,
    required DateTime sleepStart,
    required DateTime sleepEnd,
    required Duration goalSleepDuration,
  }) {
    int deepMin = 0,
        remMin = 0,
        lightMin = 0,
        awakeMin = 0,
        wakeEpisodes = 0,
        longDeepSegments = 0,
        transitions = 0;

    HealthDataPoint? prev;

    for (var d in data) {
      final minutes = d.dateTo.difference(d.dateFrom).inMinutes;

      switch (d.type) {
        case HealthDataType.SLEEP_DEEP:
          deepMin += minutes;
          if (minutes >= 30) longDeepSegments++;
          break;
        case HealthDataType.SLEEP_REM:
          remMin += minutes;
          break;
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_ASLEEP:
          lightMin += minutes;
          break;
        case HealthDataType.SLEEP_AWAKE:
          awakeMin += minutes;
          wakeEpisodes++;
          break;
        default:
          break;
      }

      if (prev != null && prev.type != d.type) transitions++;
      prev = d;
    }

    final totalSleepMin = deepMin + remMin + lightMin;
    if (totalSleepMin == 0) return 0;

    final totalMinutes = sleepEnd.difference(sleepStart).inMinutes;
    final goalMinutes = goalSleepDuration.inMinutes;

    int score = 100;

    // 1. 수면 시간 감점 (더 관대하게)
    if (totalMinutes < goalMinutes) {
      final hourDiff = ((goalMinutes - totalMinutes) / 60).ceil();
      score -= (hourDiff * 5).clamp(0, 15); // 10 → 5, 25 → 15
    }

    // 2. 수면 구조 감점 (더 관대하게)
    final deepPct = totalSleepMin > 0 ? deepMin / totalSleepMin : 0;
    final remPct = totalSleepMin > 0 ? remMin / totalSleepMin : 0;
    final lightPct = totalSleepMin > 0 ? lightMin / totalSleepMin : 0;
    final diffSum =
        (deepPct - 0.2).abs() + (remPct - 0.2).abs() + (lightPct - 0.6).abs();
    score -= ((diffSum / 0.3).round() * 3).clamp(
      0,
      10,
    ); // 0.2 → 0.3, 5 → 3, 15 → 10

    // 3. 심층 수면 분포 감점 (더 관대하게)
    final sleepDuration = sleepEnd.difference(sleepStart);
    final earlyEnd = sleepStart.add(
      Duration(minutes: (sleepDuration.inMinutes * 0.4).round()),
    );
    final earlyDeepMin = data
        .where(
          (d) =>
              d.type == HealthDataType.SLEEP_DEEP &&
              d.dateFrom.isBefore(earlyEnd),
        )
        .fold<int>(
          0,
          (sum, d) => sum + d.dateTo.difference(d.dateFrom).inMinutes,
        );
    final earlyDeepRatio = deepMin > 0 ? earlyDeepMin / deepMin : 0;
    if (earlyDeepRatio < 0.4) score -= 3; // 0.6 → 0.4, 5 → 3

    // 4. 깸 횟수 감점 (더 관대하게)
    score -= (wakeEpisodes * 2).clamp(0, 6); // 3 → 2, 8 → 6

    // 5. 수면 통합성 감점 (더 관대하게)
    final hours = totalSleepMin / 60;
    final transitionRate = hours > 0 ? transitions / hours : 0;
    if (transitionRate >= 10) score -= 2; // 8 → 10, 3 → 2
    if (longDeepSegments == 0) score -= 3; // 5 → 3

    final finalScore = score.clamp(0, 100);

    print(
      '🧠 수면 세부 점수 - 감점 기준: 총:${finalScore}점 '
      '(시간:${totalMinutes}분, 구조편차:${diffSum.toStringAsFixed(2)}, '
      '깸:${wakeEpisodes}회, 전환:${transitions}회, 긴 깊은수면:${longDeepSegments})',
    );

    return finalScore;
  }

  bool _isSleepType(HealthDataType type) {
    return type == HealthDataType.SLEEP_ASLEEP ||
        type == HealthDataType.SLEEP_LIGHT ||
        type == HealthDataType.SLEEP_DEEP ||
        type == HealthDataType.SLEEP_REM;
  }

  Future<void> _fetchTodaySleep() async {
    final health = Health();
    final types = [
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_LIGHT,
    ];

    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final formattedDate = DateFormat('yyyy-MM-dd').format(yesterday);

    sleepStart = DateTime(now.year, now.month, now.day - 1, 18);
    sleepEnd = DateTime(now.year, now.month, now.day, 12);
    final inBedMin = deepMin + remMin + lightMin + awakeMin; // ✅ 포함
    setState(() {
      formattedDuration = _fmtMin(inBedMin);
    });
    final authorized = await health.requestAuthorization(types);
    if (!authorized) {
      setState(() => formattedDuration = '❌ 건강 앱 접근 거부됨');
      return;
    }

    try {
      final data = await health.getHealthDataFromTypes(
        types: types,
        startTime: sleepStart!,
        endTime: sleepEnd!,
      );
      healthData = data;

      sleepStartReal = healthData
          .where((d) => _isSleepType(d.type))
          .map((d) => d.dateFrom)
          .fold<DateTime?>(
            null,
            (prev, curr) => prev == null || curr.isBefore(prev) ? curr : prev,
          );

      sleepEndReal = healthData
          .where((d) => _isSleepType(d.type))
          .map((d) => d.dateTo)
          .fold<DateTime?>(
            null,
            (prev, curr) => prev == null || curr.isAfter(prev) ? curr : prev,
          );

      deepMin = remMin = lightMin = awakeMin = 0;
      Duration total = Duration.zero;
      for (var d in data) {
        final dur = d.dateTo.difference(d.dateFrom);
        switch (d.type) {
          case HealthDataType.SLEEP_DEEP:
            deepMin += dur.inMinutes;
            break;
          case HealthDataType.SLEEP_REM:
            remMin += dur.inMinutes;
            break;
          case HealthDataType.SLEEP_LIGHT:
          case HealthDataType.SLEEP_ASLEEP:
            lightMin += dur.inMinutes;
            break;
          case HealthDataType.SLEEP_AWAKE:
            awakeMin += dur.inMinutes;
            break;
          default:
            break;
        }
      }
      final inBedMin = deepMin + remMin + lightMin + awakeMin; // ✅ 깨어있음 포함
      final score = calculateSleepScore(
        data: data,
        // 가능하면 “실제” 수면시작/종료를 쓰면 시간감점 왜곡이 줄어요:
        sleepStart: (sleepStartReal ?? sleepStart!),
        sleepEnd: (sleepEndReal ?? sleepEnd!),
        goalSleepDuration:
            (goalSleepDuration ??
                widget.goalSleepDuration ??
                const Duration(hours: 8)),
      );

      setState(() {
        todaySleep = Duration(minutes: inBedMin);
        formattedDuration = _fmtMin(inBedMin);
        sleepScore = score;
      });
      await _savePendingPayload(); // ✅ 업로드용 페이로드는 계속 저장// ← 정오 자동 업로드용 페이로드 캐시
    } catch (e) {
      setState(() => formattedDuration = '⚠️ 오류 발생');
      print('⚠️ 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopNav(
        title: '수면 분석',
        showBackButton: true, // 홈은 루트이므로 숨김
        // gradient: LinearGradient( // 필요시 그라디언트 켜기
        //   colors: [Color(0xFF1D1E33), Color(0xFF141527)],
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        // ),
      ),

      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 환영 메시지
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.waving_hand,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Good Morning, $username',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '오늘도 좋은 하루 되세요!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTab(context, 'Days', true),
                    _buildTab(context, 'Weeks', false),
                    _buildTab(context, 'Months', false),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2C72), Color(0xFF1F1F4C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2C2C72).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bedtime,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '오늘의 수면',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getSleepComparisonText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.nights_stay,
                      time: formattedDuration,
                      label: '오늘 총 수면시간',
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.access_time,
                      time: goalText,
                      label: '목표 수면 시간',
                      // ✅ SleepDashboard.build 안의 _InfoItem(onTap) 부분 교체
                      onTap: () async {
                        final updatedDuration = await Navigator.pushNamed(
                          context,
                          '/time-set',
                        );
                        if (updatedDuration is Duration) {
                          setState(() {
                            goalSleepDuration = updatedDuration; // ← State 업데이트
                          });
                          final newText =
                              await _getGoalTextForTodayWithEnabledCheck();
                          if (!mounted) return;
                          setState(() {
                            goalText = newText;
                          });
                          _recalcScore();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ElevatedButton(
              //   onPressed: () async {
              //     if (sleepScore == 0) {
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(
              //           content: Text("수면점수 계산 중입니다. 잠시 후 다시 시도해주세요."),
              //         ),
              //       );
              //       return;
              //     }
              //     final token = await storage.read(key: 'jwt');
              //     final userId = await storage.read(key: 'userID');
              //     if (token == null ||
              //         userId == null ||
              //         todaySleep == null ||
              //         sleepStart == null ||
              //         sleepEnd == null) {
              //       print('❌ 유저/토큰/수면데이터 부족');
              //       return;
              //     }
              //     print('📤 sleepScore 전송 전 확인: $sleepScore');
              //     print('🕒 sleepStartReal: $sleepStartReal');
              //     final segments =
              //         healthData
              //             .where(
              //               (d) =>
              //                   _isSleepType(d.type) ||
              //                   d.type == HealthDataType.SLEEP_AWAKE,
              //             )
              //             .map((d) {
              //               String stage;
              //               switch (d.type) {
              //               case HealthDataType.SLEEP_DEEP:
              //     stage = "deep";
              //     break;
              //   case HealthDataType.SLEEP_REM:
              //     stage = "rem";
              //     break;
              //   case HealthDataType.SLEEP_LIGHT:
              //   case HealthDataType.SLEEP_ASLEEP:
              //     stage = "light";
              //     break;
              //   case HealthDataType.SLEEP_AWAKE:
              //     stage = "awake";
              //     break;
              //   default:
              //     stage = "unknown";
              // }

              // return {
              //   "startTime": d.dateFrom
              //       .toIso8601String()
              //       .substring(11, 16),
              //   "endTime": d.dateTo.toIso8601String().substring(
              //     11,
              //     16,
              //   ),
              //     "stage": stage,
              //   };
              //         })
              //         .toList();
              //     await sendSleepData(
              //       userId: userId,
              //       token: userId,
              //       sleepStart: sleepStartReal ?? sleepStart!,
              //       sleepEnd: sleepEndReal ?? sleepEnd!,
              //       totalSleep: deepMin + remMin + lightMin,
              //       deepSleep: deepMin,
              //       remSleep: remMin,
              //       lightSleep: lightMin,
              //       awakeDuration: awakeMin,
              //       segments: segments, // 이건 위에서 따로 생성해 둔 리스트
              //       sleepScore: sleepScore,
              //     );
              //     await _refreshFromServerByRealStart();
              //   },
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: const Color(0xFF2C2C72),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       foregroundColor: Colors.white,
              //       padding: const EdgeInsets.symmetric(vertical: 14),
              //     ),
              //   child: const Text('🛏️ 오늘 수면 데이터 전송하기'),
              // ),
              // const SizedBox(height: 24),
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
                    if (_inMidnightWindow) _midnightNoticeCard(),
                    if (_inMidnightWindow) const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.psychology,
                                color: Colors.amber,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '오늘 $username님의 수면점수',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // ... 기존 로직 그대로 ...
                                },
                                child: const Text('더 알아보기 >'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: CircularPercentIndicator(
                              radius: 80.0,
                              lineWidth: 14.0,
                              percent:
                                  (sleepScore.clamp(0, 100)) /
                                  100.0, // 안전하게 클램프
                              center: Text(
                                "$sleepScore 점",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              progressColor: const Color(0xFFF6D35F),
                              backgroundColor: const Color(0xFF0A0E21),
                              circularStrokeCap: CircularStrokeCap.round,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        children: [
                          _buildActionTile(
                            icon: Icons.music_note,
                            title: '수면 사운드 추천받기',
                            subtitle: 'AI가 추천하는 맞춤형 수면 음악',
                            onTap: () => Navigator.pushNamed(context, '/sound'),
                          ),
                          const Divider(color: Colors.white10, height: 32),
                          _buildActionTile(
                            icon: Icons.psychology,
                            title: '내 수면 자세히 알아보기',
                            subtitle: '수면 차트 보러가기',
                            onTap:
                                () => Navigator.pushNamed(
                                  context,
                                  '/sleep-chart',
                                ),
                          ),
                        ],
                      ), // Column (액션 타일 내부)
                    ), // Container (액션 타일 카드)
                  ],
                ), // Column (카드들을 감싸는 컬럼)
              ), // Container (바깥 카드 박스)
            ],
          ), // Column (SingleChildScrollView의 child)
        ),
      ), // SingleChildScrollView
    ); // SafeArea
    // Scaffold
  }

  Widget _midnightNoticeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, color: Colors.amber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '지금은 00:00–04:00 동기화 시간이에요.\n'
              '건강 앱/서버 집계가 완료되기 전까진 수면점수가 잠시 보이지 않을 수 있어요.\n'
              '• 04시 이후 자동으로 갱신됩니다.\n'
              '• 잠시 후 다시 확인해 주세요.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String label, bool selected) {
    Widget to = SleepDashboard(
      goalSleepDuration: goalSleepDuration ?? widget.goalSleepDuration,
    );
    if (label == 'Weeks') to = WeeklySleepScreen();
    if (label == 'Months') to = MonthlySleepScreen();
    return GestureDetector(
      onTap:
          () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => to),
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8183D9) : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E21),
          borderRadius: BorderRadius.circular(12),
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
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
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
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String time;
  final String label;
  final VoidCallback? onTap;

  const _InfoItem({
    required this.icon,
    required this.time,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 90,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
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
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: content)
        : content;
  }
}
