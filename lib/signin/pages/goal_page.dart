import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> sleepGoalMap = {
  '깊은 수면을 자고 싶어요': 'deepSleep',
  '빨리 잠들고 싶어요': 'fallAsleepFast',
  '중간에 깨지 않고 계속 자고 싶어요': 'stayAsleep',
  '아침에 상쾌하게 일어나고 싶어요': 'wakeUpRefreshed',
  '수면 중 몸이 편안하게 쉬길 원해요': 'comfortableSleep',
  '수면 환경(조명, 소음, 온도 등)을 최적화하고 싶어요': 'optimalEnvironment',
  '일정한 수면 패턴을 유지하고 싶어요': 'consistentSchedule',
};

const Map<String, String> feedbackFormatMap = {
  '텍스트 요약': 'text',
  '그래프': 'graph',
  '음성 안내': 'voice',
};

class GoalPage extends StatefulWidget {
  final VoidCallback onNext;
  const GoalPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  String? improveSleepQuality;

  bool get isValid => improveSleepQuality != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      extendBodyBehindAppBar: true, // AppBar 뒤로 body 확장
      extendBody: true, // 하단까지 body 확장
      appBar: AppBar(
        title: const Text(
          '알라와 코잘라',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, // AppBar 배경을 투명하게
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFF0A0E21)),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 80, // 상태바 높이 + AppBar 높이
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20, // 하단 안전 영역 + 여백
          ),
          child: Column(
            children: [
              // 헤더 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '수면 목표 설정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수면 목표를 알려주세요',
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

              const SizedBox(height: 30),

              // 코알라 이미지
              Center(
                child: Image.asset(
                  'lib/assets/koala.png',
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 30),

              // 질문 카드
              Container(
                width: double.infinity,
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
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.quiz,
                            color: Color(0xFFFFD700),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Q25. 가장 중점적으로 두고 싶은\n수면 목표를 알려주세요",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...[
                      '깊은 수면을 자고 싶어요',
                      '빨리 잠들고 싶어요',
                      '중간에 깨지 않고 계속 자고 싶어요',
                      '아침에 상쾌하게 일어나고 싶어요',
                      '수면 중 몸이 편안하게 쉬길 원해요',
                      '수면 환경(조명, 소음, 온도 등)을 최적화하고 싶어요',
                      '일정한 수면 패턴을 유지하고 싶어요',
                    ].map(
                      (option) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              improveSleepQuality == option
                                  ? const Color(0xFF6C63FF).withOpacity(0.2)
                                  : const Color(0xFF0A0E21),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                improveSleepQuality == option
                                    ? const Color(0xFF6C63FF)
                                    : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: RadioListTile(
                          title: Text(
                            option,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  improveSleepQuality == option
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                          value: option,
                          groupValue: improveSleepQuality,
                          onChanged:
                              (v) => setState(() => improveSleepQuality = v),
                          activeColor: const Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      isValid
                          ? () async {
                            final m = OnboardingData.answers;

                            // 1) 라벨 → 서버 토큰 매핑
                            final apiValue = sleepGoalMap[improveSleepQuality];

                            if (apiValue == null || apiValue.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('수면 목표 매핑에 실패했어요. 다시 선택해 주세요.'),
                                ),
                              );
                              return;
                            }

                            // 2) 서버 전송용 값은 영어 토큰으로 저장
                            m['sleepGoal'] = apiValue;

                            // (선택) UI 표시용 라벨은 따로 저장
                            m['sleepGoalLabel'] = improveSleepQuality;

                            // 3) 스토리지에도 토큰 저장(유지)
                            await storage.write(
                              key: 'sleepGoal',
                              value: apiValue,
                            );

                            widget.onNext();
                          }
                          : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color:
                          isValid
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
