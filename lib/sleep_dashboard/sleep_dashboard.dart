import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:my_app/bottomNavigationBar.dart';
import 'package:my_app/TopNav.dart';
import 'package:my_app/sleep_dashboard/monthly_sleep_screen.dart';
import 'package:my_app/sleep_dashboard/weekly_sleep_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final storage = FlutterSecureStorage();

class SleepDashboard extends StatefulWidget {
  final Duration? goalSleepDuration;
  const SleepDashboard({Key? key, this.goalSleepDuration}) : super(key: key);

  @override
  State<SleepDashboard> createState() => _SleepDashboardState();
}

class _SleepDashboardState extends State<SleepDashboard> {
  String formattedDuration = '불러오는 중...';
  String username = '사용자';
  String fm(DateTime t) => t.toIso8601String().substring(11, 16);
  String goalText = '미설정';
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

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _fetchTodaySleep();
    _loadGoalText();
    _applyServerCacheIfAny();
    // HealthKit 윈도우/시작시각 계산 -> 끝난 직후 서버 GET으로 UI 갱신
    _fetchTodaySleep().then((_) {
      _refreshFromServerByRealStart(); // ✅ 항상 서버 값으로 덮어씀
    });
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
      setState(() {
        formattedDuration = '${hrs}시간 ${mins}분';
        sleepScore = (m['sleepScore'] as int?) ?? sleepScore;
      });
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

    final date = DateFormat(
      'yyyy-MM-dd',
    ).format(base.subtract(const Duration(hours: 6)));

    final server = await _getSleepDataFromServer(
      userId: userId,
      token: token,
      date: date,
    );
    if (server == null) return;

    final durationMin = (server['Duration']?['totalSleepDuration'] ?? 0) as int;
    final hrs = durationMin ~/ 60;
    final mins = durationMin % 60;

    setState(() {
      formattedDuration = '${hrs}시간 ${mins}분';
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
    // 서버 규칙: 시작시각 -6시간을 해당 날짜로 사용
    final date = DateFormat(
      'yyyy-MM-dd',
    ).format(realStart.subtract(const Duration(hours: 6)));

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
    final goal = await _loadTodayGoalSleepDuration();
    print('[goal] 불러온 수면 목표: ${goal?.inMinutes}분');

    setState(() {
      goalSleepDuration = goal ?? Duration(hours: 8);
      goalText =
          goal != null
              ? '${goal.inHours}시간 ${goal.inMinutes % 60}분'
              : '목표수면시간 없음';
    });
  }

  Future<Duration?> _loadTodayGoalSleepDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final weekday = DateTime.now().weekday % 7; // Sunday = 0
    final minutes = prefs.getInt('sleepGoal_$weekday');

    if (minutes != null) {
      return Duration(minutes: minutes);
    }
    return null;
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

    // iOS: 정오 이후 처음 깨어났을 때 업로드
    if (now.hour < 12) return;
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
    final name = await storage.read(key: 'username');
    setState(() {
      username = name ?? '사용자';
      _isLoggedIn = name != null;
    });
  }

  Future<void> _handleLogout() async {
    await storage.delete(key: 'username');
    await storage.delete(key: 'jwt');
    await storage.delete(key: 'userID');
    setState(() {
      username = '사용자';
      _isLoggedIn = false;
    });
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
    final sleepDate = realStart.subtract(Duration(hours: 6));
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
      "segments": segments, // 👈 segment 추가는 선택적으로
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

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      print('✅ 수면 데이터 전송 성공');
    } else {
      print('❌ 전송 실패: ${resp.statusCode} / ${resp.body}');
    }
  }

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

    // 1. 수면 시간 감점
    if (totalMinutes < goalMinutes) {
      final hourDiff = ((goalMinutes - totalMinutes) / 60).ceil();
      score -= (hourDiff * 20).clamp(0, 40);
    }

    // 2. 수면 구조 감점 (깊/REM/얕은 수면 비율 기준)
    final deepPct = totalSleepMin > 0 ? deepMin / totalSleepMin : 0;
    final remPct = totalSleepMin > 0 ? remMin / totalSleepMin : 0;
    final lightPct = totalSleepMin > 0 ? lightMin / totalSleepMin : 0;
    final diffSum =
        (deepPct - 0.2).abs() + (remPct - 0.2).abs() + (lightPct - 0.6).abs();
    score -= ((diffSum / 0.1).round() * 10).clamp(0, 30);

    // 3. 심층 수면 분포 감점 (전반부 집중도)
    final sleepDuration = sleepEnd.difference(sleepStart);
    final earlyEnd = sleepStart.add(sleepDuration * 0.4);
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
    if (earlyDeepRatio < 0.8) score -= 8;

    // 4. 깸 횟수 감점
    score -= (wakeEpisodes * 5).clamp(0, 10);

    // 5. 수면 통합성 감점
    final hours = totalSleepMin / 60;
    final transitionRate = hours > 0 ? transitions / hours : 0;
    if (transitionRate >= 5) score -= 5;
    if (longDeepSegments == 0) score -= 10;

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
        total += dur;
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

      todaySleep = total;
      //formattedDuration = '${total.inHours}시간 ${total.inMinutes % 60}분';

      sleepScore = calculateSleepScore(
        data: data,
        sleepStart: sleepStart!,
        sleepEnd: sleepEnd!,
        goalSleepDuration: widget.goalSleepDuration ?? Duration(hours: 8),
      );

      setState(() {});
      await _savePendingPayload(); // ← 정오 자동 업로드용 페이로드 캐시
    } catch (e) {
      setState(() => formattedDuration = '⚠️ 오류 발생');
      print('⚠️ 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNav(
        isLoggedIn: _isLoggedIn,
        onLogin: () => Navigator.pushNamed(context, '/login'),
        onLogout: _handleLogout,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Good Morning',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTab(context, 'Days', true),
                  _buildTab(context, 'Weeks', false),
                  _buildTab(context, 'Months', false),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2C72), Color(0xFF1F1F4C)],
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'You have slept '),
                      TextSpan(
                        text: formattedDuration,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' today.'),
                    ],
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.nights_stay,
                      time: formattedDuration,
                      label: '오늘 총 수면 시간',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.access_time,
                      time: goalText,
                      label: '목표 수면 시간',
                      onTap: () async {
                        final updatedDuration = await Navigator.pushNamed(
                          context,
                          '/time-set',
                        );
                        if (updatedDuration is Duration) {
                          setState(() {
                            goalSleepDuration = updatedDuration;
                            goalText =
                                '${updatedDuration.inHours}시간 ${updatedDuration.inMinutes % 60}분';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (sleepScore == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("수면점수 계산 중입니다. 잠시 후 다시 시도해주세요."),
                      ),
                    );
                    return;
                  }
                  final token = await storage.read(key: 'jwt');
                  final userId = await storage.read(key: 'userID');
                  if (token == null ||
                      userId == null ||
                      todaySleep == null ||
                      sleepStart == null ||
                      sleepEnd == null) {
                    print('❌ 유저/토큰/수면데이터 부족');
                    return;
                  }
                  print('📤 sleepScore 전송 전 확인: $sleepScore');
                  print('🕒 sleepStartReal: $sleepStartReal');
                  final segments =
                      healthData
                          .where(
                            (d) =>
                                _isSleepType(d.type) ||
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
                              "startTime": d.dateFrom
                                  .toIso8601String()
                                  .substring(11, 16),
                              "endTime": d.dateTo.toIso8601String().substring(
                                11,
                                16,
                              ),
                              "stage": stage,
                            };
                          })
                          .toList();
                  await sendSleepData(
                    userId: userId,
                    token: token,
                    sleepStart: sleepStartReal ?? sleepStart!,
                    sleepEnd: sleepEndReal ?? sleepEnd!,
                    totalSleep: deepMin + remMin + lightMin,
                    deepSleep: deepMin,
                    remSleep: remMin,
                    lightSleep: lightMin,
                    awakeDuration: awakeMin,
                    segments: segments, // 이건 위에서 따로 생성해 둔 리스트
                    sleepScore: sleepScore,
                  );
                  await _refreshFromServerByRealStart();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2C72),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('🛏️ 오늘 수면 데이터 전송하기'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '오늘 $username님의 수면점수는..',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('수면점수 더 알아보기 >'),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: CircularPercentIndicator(
                  radius: 80.0,
                  lineWidth: 14.0,
                  percent: sleepScore / 100.0,
                  center: Text(
                    "$sleepScore 점",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  progressColor: const Color(0xFFF6D35F),
                  backgroundColor: Colors.black,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                title: const Text('수면 사운드 추천받기'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/sound');
                },
              ),
              ListTile(
                title: const Text('수면 조언 받으러 가기'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/advice');
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
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

  Widget _buildTab(BuildContext context, String label, bool selected) {
    Widget to = SleepDashboard(goalSleepDuration: widget.goalSleepDuration);
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
          color: selected ? const Color(0xFF8183D9) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
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
    final content = Row(
      children: [
        Icon(icon, size: 32, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: content)
        : content;
  }
}
