import 'package:flutter/material.dart';
import 'package:my_app/mkhome/real_home.dart';
import 'package:my_app/signin/onboarding_screen.dart';
import 'package:my_app/signin/pages/complete_page.dart';
import 'package:my_app/sleep_dashboard/sleep_entry_screen.dart';
import 'package:my_app/sleep_time/sleep_goal_screen.dart';
import 'package:my_app/sound/sound.dart';
import 'package:my_app/sleep_dashboard/sleep_entry.dart';
import 'package:my_app/test.dart';
import 'package:provider/provider.dart';
import 'package:my_app/login/login.dart';
import 'package:my_app/signin/signin.dart';
import 'package:my_app/sleep_dashboard/sleep_chart_screen.dart';

import 'home_page.dart';
import 'sleep_dashboard/sleep_dashboard.dart';
import 'package:my_app/sleep_dashboard/weekly_sleep_screen.dart';
import 'package:my_app/sleep_dashboard/monthly_sleep_screen.dart';
import 'package:my_app/mkhome/opening.dart';
import 'package:my_app/mkhome/sleep_routine_setup_page.dart';
import 'package:my_app/mkhome/setting_page.dart';
import 'package:my_app/connect_settings/notification.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_app/device/alarm/alarm_provider.dart';
import 'package:my_app/device/alarm/alarm_dashboard_page.dart';
import 'package:my_app/device/alarm/bedtime_provider.dart';
import 'package:my_app/models/message.dart';
import 'package:audio_session/audio_session.dart';

// ⬇️ ADD: 백그라운드 페치 & 네트워킹/저장소 유틸
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

// ⬇️ ADD: 헤드리스(앱 종료 상태)에서도 콜백이 살아있게
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  final taskId = task.taskId;
  final timeout = task.timeout;
  if (timeout) {
    BackgroundFetch.finish(taskId);
    return;
  }
  debugPrint('[BGFetch][headless] fired: $taskId');
  await _tryUploadPending(); // 정오 이후 & 오늘 미전송 & 페이로드 있음 → 업로드
  BackgroundFetch.finish(taskId);
}

// 🔹 서버 하루 데이터 조회(최상위 함수)
Future<Map<String, dynamic>?> _getSleepDataFromServer({
  required String userId,
  required String token,
  required String date, // yyyy-MM-dd
}) async {
  final uri = Uri.parse('https://kooala.tassoo.uk/sleep-data/$userId/$date');
  try {
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
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

// 🔹 업로드 + 성공 시 GET해서 캐시 저장(최상위 함수)
Future<void> _tryUploadPending() async {
  final prefs = await SharedPreferences.getInstance();
  final storage = const FlutterSecureStorage();

  final token = await storage.read(key: 'jwt');
  final userId = await storage.read(key: 'userID');
  final payloadJson = prefs.getString('pendingSleepPayload');
  final lastSentDate = prefs.getString('lastSentDate'); // yyyy-MM-dd

  if (token == null || userId == null || payloadJson == null) return;

  // payload 에서 날짜 추출 (UI 변수 쓰지 마세요)
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

  if (now.hour < 12) return; // 정오 이후
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

      // ✅ 서버 진짜 값으로 캐시 갱신
      final server = await _getSleepDataFromServer(
        userId: userId,
        token: token,
        date: date,
      );
      if (server != null) {
        await prefs.setString('latestServerSleepData', jsonEncode(server));
        debugPrint('[BGFetch][GET] cached latestServerSleepData for $date');
      }
      // 원하면 대기 페이로드 제거:
      // await prefs.remove('pendingSleepPayload');
    } else {
      debugPrint('[BGFetch][POST] ${resp.statusCode} ${resp.body}');
    }
  } catch (e) {
    debugPrint('[BGFetch] upload error: $e');
  }
}

// ⬇️ 추가: 초기화 함수
Future<void> _initBackgroundFetch() async {
  // 헤드리스 등록
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);

  final status = await BackgroundFetch.configure(
    BackgroundFetchConfig(
      minimumFetchInterval: 15, // iOS는 정확하지 않지만 최소간격 힌트
      stopOnTerminate: false,
      enableHeadless: true,
      startOnBoot: true,
      requiredNetworkType: NetworkType.ANY,
    ),
    (String taskId) async {
      debugPrint('[BGFetch] event: $taskId');
      await _tryUploadPending(); // 정오 이후면 업로드 시도
      BackgroundFetch.finish(taskId);
    },
    (String taskId) async {
      debugPrint('[BGFetch] TIMEOUT: $taskId');
      BackgroundFetch.finish(taskId);
    },
  );

  debugPrint('[BGFetch] configure status = $status');
  // ⭐ 반드시 start
  await BackgroundFetch.start();
  debugPrint('[BGFetch] started');

  // 앱 켰을 때도 한번 시도(정오 이후면 업로드 됨)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _tryUploadPending();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Hive 초기화
  await Hive.initFlutter();

  Hive.registerAdapter(MessageAdapter());

  await Hive.openBox<Message>('chatBox'); // ✅ 여기서 1회만 오픈
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider(create: (_) => BedtimeModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const opening());
          case '/setup':
            return MaterialPageRoute(
              builder: (_) => const SleepRoutineSetupPage(),
            );
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomePage());
          case '/sleep':
            return MaterialPageRoute(builder: (_) => const SleepDashboard());
          case '/weekly':
            return MaterialPageRoute(builder: (_) => const WeeklySleepScreen());
          case '/monthly':
            return MaterialPageRoute(builder: (_) => MonthlySleepScreen());
          case '/setting':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case '/notice':
            return MaterialPageRoute(builder: (_) => const Notice());
          case '/alarm':
            return MaterialPageRoute(
              builder: (_) => const AlarmDashboardPage(),
            );
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginScreen());
          case '/sign-in':
            return MaterialPageRoute(builder: (_) => const SignInScreen());
          case '/time-set':
            return MaterialPageRoute(builder: (_) => SleepGoalScreen());
          case '/real-home':
            return MaterialPageRoute(builder: (_) => RealHomeScreen());
          case '/sound':
            return MaterialPageRoute(builder: (_) => SoundScreen());

          case '/start':
            return MaterialPageRoute(builder: (_) => OnboardingScreen());

          case '/test':
            return MaterialPageRoute(builder: (_) => MP3TestPage());

          case '/complete':
            return MaterialPageRoute(
              builder:
                  (_) => CompletePage(
                    onSubmit: () {
                      // TODO: 원하는 submit 동작을 여기에 정의하거나 다른 곳에서 주입
                    },
                  ),
            );

          case '/sleep-entry':
            final entry = settings.arguments as SleepEntry;
            return MaterialPageRoute(
              builder: (_) => SleepEntryScreen(entry: entry),
            );

          case '/sleep-chart':
            final args = settings.arguments as Map<String, dynamic>;
            final entries = args['entries'] as List<SleepEntry>;
            final selectedDate = DateTime.now().subtract(
              const Duration(hours: 6),
            ); // ✅ 현재 기준 날짜로 계산
            return MaterialPageRoute(
              builder:
                  (_) => SleepChartScreen(
                    entries: entries,
                    selectedDate: selectedDate,
                  ),
            );

          default:
            return MaterialPageRoute(
              builder:
                  (_) => const Scaffold(
                    body: Center(child: Text('404 - 페이지를 찾을 수 없습니다')),
                  ),
            );
        }
      },
    );
  }
}
