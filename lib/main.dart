import 'package:flutter/material.dart';
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
            return MaterialPageRoute(
              builder:
                  (_) => Scaffold(
                    backgroundColor: const Color(0xFF0A0E21),
                    appBar: AppBar(
                      title: const Text(
                        '수면 점수 설명',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      centerTitle: true,
                      backgroundColor: const Color(0xFF1D1E33),
                      elevation: 0,
                      iconTheme: const IconThemeData(color: Colors.white),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    body: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1D1E33), Color(0xFF0A0E21)],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: ListView(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFF4B47BD),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6C63FF,
                                      ).withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.psychology,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '수면 점수 설명',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '수면 점수가 어떻게 계산되는지 알아보세요',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
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
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.access_time,
                                        color: Color(0xFF6C63FF),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '수면 시간 (40점)',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            '목표 수면 시간을 달성하면 높은 점수를 받습니다. 부족한 시간만큼 감점됩니다.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
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
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.pie_chart,
                                        color: Color(0xFF6C63FF),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '수면 구조 (30점)',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            '깊은 수면, REM 수면, 가벼운 수면의 균형이 좋을수록 높은 점수를 받습니다.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
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
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.nights_stay,
                                        color: Color(0xFF6C63FF),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '수면 안정성 (20점)',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            '잠을 깨는 횟수가 적고, 수면 단계 간 전환이 부드러울수록 높은 점수를 받습니다.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
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
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6C63FF,
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.trending_up,
                                        color: Color(0xFF6C63FF),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '수면 효율성 (10점)',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            '침대에 누워있는 시간 대비 실제 수면 시간의 비율이 높을수록 좋습니다.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              // 전 버튼 추가
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    minimumSize: const Size(
                                      double.infinity,
                                      56,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 8,
                                    shadowColor: const Color(
                                      0xFF6C63FF,
                                    ).withOpacity(0.3),
                                  ),
                                  child: const Text(
                                    '전',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            );

          case '/sleep-score':
            final args = settings.arguments as SleepScoreArgs;
            return MaterialPageRoute(
              builder:
                  (_) => SleepScoreDetailsPage(
                    data: args.data,
                    sleepStart: args.sleepStart,
                    sleepEnd: args.sleepEnd,
                    goalSleepDuration: args.goalSleepDuration,
                    finalScore: args.finalScore,
                  ),
            );

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
