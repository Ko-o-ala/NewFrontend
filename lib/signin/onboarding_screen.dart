import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pages/welcome_page.dart';
import 'pages/nickname_greeting_page.dart';
import 'pages/intro_question.dart';
import 'pages/environment_page.dart';
import 'pages/habit_page1.dart';
import 'pages/habit_page2.dart';
import 'pages/problem_page.dart';
import 'pages/sound_page.dart';
import 'pages/device_page.dart';
import 'pages/health_page.dart';
import 'pages/goal_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  final storage = const FlutterSecureStorage();

  List<Widget> get pages => [
    WelcomePage(onNext: _next),
    NicknameGreetPage(onNext: _next),
    IntroQuestionPage(onNext: _next),
    EnvironmentPage(onNext: _next),
    HabitPage1(onNext: _next),
    HabitPage2(onNext: _next),
    ProblemPage(onNext: _next),
    SoundPage(onNext: _next),

    DevicePage(onNext: _next),
    HealthPage(onNext: _next),
    GoalPage(
      onNext: () {
        Navigator.pushReplacementNamed(context, '/sign-in');
      },
    ),
  ];

  void _next() {
    if (_currentIndex < pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / pages.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Container(
          color: const Color(0xFF0A0E21),
          child: Column(
            children: [
              // 진행률 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // 진행률 텍스트
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '설문조사',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${pages.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 진행률 바
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 페이지 내용
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  children: pages,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
