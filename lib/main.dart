import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/connect_settings/delete_account.dart';
import 'package:my_app/connect_settings/faq.dart';
import 'package:my_app/connect_settings/manage_account.dart';
import 'package:my_app/device/light_control_page.dart';
import 'package:my_app/mkhome/real_home.dart';
import 'package:my_app/signin/onboarding_screen.dart';
import 'package:my_app/signin/pages/complete_page.dart';
import 'package:my_app/sleep_dashboard/sleep_score_details.dart';
import 'package:my_app/sleep_time/sleep_goal_screen.dart';
import 'package:my_app/sound/sound.dart';

import 'package:my_app/test.dart';
import 'package:provider/provider.dart';
import 'package:my_app/login/login.dart';
import 'package:my_app/signin/signin.dart';
import 'package:my_app/sleep_dashboard/sleep_chart_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'package:my_app/services/api_client.dart';
import 'package:my_app/services/auth_service.dart';

late final ApiClient apiClient;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0A0E21),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E21),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'https://kooala.tassoo.uk';
  apiClient = ApiClient(baseUrl: apiBaseUrl);

  await Hive.initFlutter();
  Hive.registerAdapter(MessageAdapter());
  await Hive.openBox<Message>('chatBox');

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
      debugPrint('[MyApp] 로그인 상태: $_isLoggedIn');
    } catch (e) {
      debugPrint('[MyApp] 로그인 상태 확인 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 UI 스타일 유지
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0A0E21),
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0E21),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // 1) 로딩 중이면 로딩 화면
    if (_isLoading) {
      return MaterialApp(
        title: 'Sleep App',
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          backgroundColor: Color(0xFF0A0E21),
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    // 2) 초기 라우트 대신, 로그인 여부로 home을 바로 정함
    return MaterialApp(
      title: 'Sleep App',
      debugShowCheckedModeBanner: false,

      /// ✅ 여기! 로그인 상태면 HomePage, 아니면 opening 위젯로 시작
      home: _isLoggedIn ? const HomePage() : const opening(),

      /// 나머지 라우팅은 그대로(onGenerateRoute)
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/opening':
            return MaterialPageRoute(builder: (_) => const opening());
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
          case '/light-control':
            return MaterialPageRoute(builder: (_) => const LightControlPage());
          case '/monthly':
            return MaterialPageRoute(builder: (_) => MonthlySleepScreen());
          case '/complete':
            return MaterialPageRoute(builder: (_) => const CompletePage());
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
          case '/faq':
            return MaterialPageRoute(builder: (_) => FAQPage());
          case '/sign-in':
            return MaterialPageRoute(builder: (_) => const SignInScreen());
          case '/time-set':
            return MaterialPageRoute(builder: (_) => SleepGoalScreen());
          case '/real-home':
            return MaterialPageRoute(builder: (_) => RealHomeScreen());
          case '/sound':
            return MaterialPageRoute(builder: (_) => SoundScreen());
          case '/edit-account':
            return MaterialPageRoute(builder: (_) => ManageAccountPage());
          case '/delete-account':
            return MaterialPageRoute(builder: (_) => DeleteAccountPage());
          case '/start':
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => OnboardingScreen());
          case '/test':
            return MaterialPageRoute(builder: (_) => MP3TestPage());
          case '/score-explain':
          case '/sleep-score':
            {
              final args = settings.arguments as Map<String, dynamic>?;
              final now = DateTime.now();
              return MaterialPageRoute(
                builder:
                    (_) => SleepScoreDetailsPage(
                      data: args?['data'] ?? [],
                      sleepStart: args?['sleepStart'] ?? now,
                      sleepEnd: args?['sleepEnd'] ?? now,
                      goalSleepDuration:
                          args?['goalSleepDuration'] ??
                          const Duration(hours: 8),
                      fallbackFromTwoDaysAgo:
                          args?['fallbackFromTwoDaysAgo'] ?? false,
                    ),
              );
            }
          case '/sleep-chart':
            {
              final args = settings.arguments as Map<String, dynamic>?;
              final selectedDate =
                  (args?['date'] as DateTime?) ?? DateTime.now();
              return MaterialPageRoute(
                builder: (_) => SleepChartScreen(selectedDate: selectedDate),
              );
            }
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
