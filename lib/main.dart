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

late final ApiClient apiClient;
void main() async {
  await dotenv.load();
  WidgetsFlutterBinding.ensureInitialized();

  // 전역 시스템 UI 스타일 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0A0E21), // 상태바 배경색
      statusBarIconBrightness: Brightness.light, // 상태바 아이콘 색상 (밝게)
      systemNavigationBarColor: Color(0xFF0A0E21), // 하단 네비게이션바 배경색
      systemNavigationBarIconBrightness: Brightness.light, // 하단 아이콘 색상 (밝게)
    ),
  );

  apiClient = ApiClient(baseUrl: dotenv.env['API_BASE_URL']!);
  //Hive 초기화
  await Hive.initFlutter();

  Hive.registerAdapter(MessageAdapter());

  await Hive.openBox<Message>('chatBox'); // ✅ 여기서 1회만 오픈

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
    // 앱 전체 시스템 UI 스타일 설정
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0A0E21), // 상태바 배경색
        statusBarIconBrightness: Brightness.light, // 상태바 아이콘 색상 (밝게)
        systemNavigationBarColor: Color(0xFF0A0E21), // 하단 네비게이션바 배경색
        systemNavigationBarIconBrightness: Brightness.light, // 하단 아이콘 색상 (밝게)
      ),
    );

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
          case '/light-control':
            return MaterialPageRoute(builder: (_) => const LightControlPage());
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
            return MaterialPageRoute(builder: (_) => OnboardingScreen());

          case '/test':
            return MaterialPageRoute(builder: (_) => MP3TestPage());
          case '/score-explain':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder:
                    (_) => SleepScoreDetailsPage(
                      data: args['data'] ?? [],
                      sleepStart: args['sleepStart'] ?? DateTime.now(),
                      sleepEnd: args['sleepEnd'] ?? DateTime.now(),
                      goalSleepDuration:
                          args['goalSleepDuration'] ?? const Duration(hours: 8),
                    ),
              );
            } else {
              // arguments가 없는 경우 기본값으로 페이지 생성
              final now = DateTime.now();
              return MaterialPageRoute(
                builder:
                    (_) => SleepScoreDetailsPage(
                      data: [],
                      sleepStart: now,
                      sleepEnd: now,
                      goalSleepDuration: const Duration(hours: 8),
                    ),
              );
            }

          case '/sleep-score':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder:
                    (_) => SleepScoreDetailsPage(
                      data: args['data'] ?? [],
                      sleepStart: args['sleepStart'] ?? DateTime.now(),
                      sleepEnd: args['sleepEnd'] ?? DateTime.now(),
                      goalSleepDuration:
                          args['goalSleepDuration'] ?? const Duration(hours: 8),
                    ),
              );
            } else {
              // arguments가 없는 경우 기본값으로 페이지 생성
              final now = DateTime.now();
              return MaterialPageRoute(
                builder:
                    (_) => SleepScoreDetailsPage(
                      data: [],
                      sleepStart: now,
                      sleepEnd: now,
                      goalSleepDuration: const Duration(hours: 8),
                    ),
              );
            }

          case '/complete':
            return MaterialPageRoute(
              builder:
                  (_) => CompletePage(
                    onSubmit: () {
                      // TODO: 원하는 submit 동작을 여기에 정의하거나 다른 곳에서 주입
                    },
                  ),
            );

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
