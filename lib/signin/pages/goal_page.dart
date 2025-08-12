import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> sleepGoalMap = {
  '깊은 수면을 자고 싶어요': 'deepSleep',
  '빨리 잠들고 싶어요': 'fallAsleepFast',
  '깨지 않고 계속 자고 싶어요': 'stayAsleep',
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
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset('lib/assets/koala.png', width: 120),
              const SizedBox(height: 16),
              Text(
                'Q25. 가장 이루고 싶은 수면 목표가 무엇인가요?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...['깊은 수면을 자고 싶어요', '빨리 잠들고 싶어요', '깨지 않고 계속 자고 싶어요'].map(
                (o) => RadioListTile(
                  title: Text(o),
                  value: o,
                  groupValue: improveSleepQuality,
                  onChanged: (v) => setState(() => improveSleepQuality = v),
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;
                          m['sleepGoal'] = improveSleepQuality;

                          await storage.write(
                            key: 'sleepGoal',
                            value: sleepGoalMap[improveSleepQuality] ?? '',
                          );

                          widget.onNext();
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8183D9),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('다음', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
