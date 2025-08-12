import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> timeToFallAsleepMap = {
  '5분 이하': 'under5min',
  '5~15분': '5to15min',
  '15~30분': '15to30min',
  '30분 이상': 'over30min',
};

const Map<String, String> caffeineIntakeLevelMap = {
  '안 마심': 'none',
  '1~2잔': '1to2cups',
  '3잔 이상': 'over3cups',
};

const Map<String, String> exerciseFrequencyMap = {
  '하지 않음': 'none',
  '주2~3회': '2to3week',
  '매일': 'daily',
};

const Map<String, String> screenTimeBeforeSleepMap = {
  '없음': 'none',
  '30분 이하': 'under30min',
  '1시간 이상': 'over1hour',
};

const Map<String, String> stressLevelMap = {
  '높음': 'high',
  '보통': 'medium',
  '낮음': 'low',
};
const Map<String, String> exerciseWhenMap = {
  '오전': 'morning',
  '낮': 'day',
  '저녁': 'night',
  '운동을 하지 않음': 'none',
};

class HealthPage extends StatefulWidget {
  final VoidCallback onNext;
  const HealthPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  String? timeToFallAsleep,
      caffeineIntakeLevel,
      exerciseFrequency,
      screenTimeBeforeSleep,
      stressLevel,
      exerciseWhen;

  bool get isValid =>
      timeToFallAsleep != null &&
      caffeineIntakeLevel != null &&
      exerciseFrequency != null &&
      screenTimeBeforeSleep != null &&
      stressLevel != null;

  Widget _q(String t, List<String> opts, String? gv, Function(String?) oc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        ...opts.map(
          (o) => RadioListTile(
            title: Text(o),
            value: o,
            groupValue: gv,
            onChanged: oc,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

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
              _q(
                'Q19. 잠들끼까지 걸리는 시간은 보통 어떻게 되시나요?',
                ['5분 이하', '5~15분', '15~30분', '30분 이상'],
                timeToFallAsleep,
                (v) => setState(() => timeToFallAsleep = v),
              ),
              _q(
                'Q20. 커피(카페인)는 보통 하루에 몇잔정도 드시나요?',
                ['안 마심', '1~2잔', '3잔 이상'],
                caffeineIntakeLevel,
                (v) => setState(() => caffeineIntakeLevel = v),
              ),
              _q(
                'Q21. 운동을 얼마나 자주 하시나요??',
                ['하지 않음', '주2~3회', '매일'],
                exerciseFrequency,
                (v) => setState(() => exerciseFrequency = v),
              ),
              _q(
                'Q22. 운동을 언제 하시나요??',
                ['오전', '낮', '저녁', '운동을 하지 않음'],
                exerciseWhen,
                (v) => setState(() => exerciseWhen = v),
              ),
              _q(
                'Q23. 취침 전 전자기기 사용 시간은 어떻게 되시나요?',
                ['없음', '30분 이하', '1시간 이상'],
                screenTimeBeforeSleep,
                (v) => setState(() => screenTimeBeforeSleep = v),
              ),
              _q(
                'Q24. 최근 스트레스를 얼마나 받으시나요?',
                ['높음', '보통', '낮음'],
                stressLevel,
                (v) => setState(() => stressLevel = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;

                          m['timeToFallAsleep'] =
                              timeToFallAsleepMap[timeToFallAsleep];
                          m['caffeineIntakeLevel'] =
                              caffeineIntakeLevelMap[caffeineIntakeLevel];
                          m['exerciseFrequency'] =
                              exerciseFrequencyMap[exerciseFrequency];
                          m['exerciseWhen'] = exerciseWhenMap[exerciseWhen];
                          m['screenTimeBeforeSleep'] =
                              screenTimeBeforeSleepMap[screenTimeBeforeSleep];
                          m['stressLevel'] = stressLevelMap[stressLevel];

                          await storage.write(
                            key: 'timeToFallAsleep',
                            value: timeToFallAsleepMap[timeToFallAsleep] ?? '',
                          );
                          await storage.write(
                            key: 'caffeineIntakeLevel',
                            value:
                                caffeineIntakeLevelMap[caffeineIntakeLevel] ??
                                '',
                          );
                          await storage.write(
                            key: 'exerciseFrequency',
                            value:
                                exerciseFrequencyMap[exerciseFrequency] ?? '',
                          );
                          await storage.write(
                            key: 'exerciseWhen',
                            value: exerciseWhenMap[exerciseWhen] ?? '',
                          );
                          await storage.write(
                            key: 'screenTimeBeforeSleep',
                            value:
                                screenTimeBeforeSleepMap[screenTimeBeforeSleep] ??
                                '',
                          );
                          await storage.write(
                            key: 'stressLevel',
                            value: stressLevelMap[stressLevel] ?? '',
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
