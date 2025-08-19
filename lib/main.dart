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
import 'package:my_app/device/alarm/alarm_model.dart';
import 'package:my_app/device/alarm/alarm_provider.dart';
import 'package:my_app/device/alarm/alarm_dashboard_page.dart';
import 'package:my_app/device/alarm/bedtime_provider.dart';
import 'package:my_app/models/message.dart';
import 'package:audio_session/audio_session.dart';

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
