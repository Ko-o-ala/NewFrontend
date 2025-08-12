import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> napFrequencyMap = {
  '매일': 'daily',
  '주3~4': '3to4perWeek',
  '1~2회': '1to2perWeek',
  '거의 안 잠': 'rarely',
};

const Map<String, String> napDurationMap = {
  '15분 이하': 'under15',
  '15~30분': '15to30',
  '30분~1시간': '30to60',
  '1시간 이상': 'over60',
};

const Map<String, String> mostDrowsyTimeMap = {
  '오전': 'morning',
  '오후': 'afternoon',
  '저녁': 'evening',
  '새벽': 'night',
  '일정 없음': 'random',
};

const Map<String, String> averageSleepDurationMap = {
  '4시간 이하': 'under4h',
  '4~6시간': '4to6h',
  '6~7시간': '6to7h',
  '7~8시간': '7to8h',
  '8시간 이상': 'over8h',
};

class HabitPage2 extends StatefulWidget {
  final VoidCallback onNext;
  const HabitPage2({Key? key, required this.onNext}) : super(key: key);

  @override
  State<HabitPage2> createState() => _HabitPage2State();
}

class _HabitPage2State extends State<HabitPage2> {
  String? napFrequency, napDuration, mostDrowsyTime, averageSleepDuration;

  bool get isValid =>
      napFrequency != null &&
      napDuration != null &&
      mostDrowsyTime != null &&
      averageSleepDuration != null;

  Widget _q(String t, List<String> opts, String? gv, Function(String?) cg) {
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
            onChanged: cg,
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
                'Q9. 낮잠 빈도는 어떻게 되시나요?',
                ['매일', '주3~4', '1~2회', '거의 안 잠'],
                napFrequency,
                (v) => setState(() => napFrequency = v),
              ),
              _q(
                'Q10. 평소에 낮잠은 얼마나 주무시나요?',
                ['15분 이하', '15~30분', '30분~1시간', '1시간 이상'],
                napDuration,
                (v) => setState(() => napDuration = v),
              ),
              _q(
                'Q11. 가장 졸리거나 피곤한 시간대는 어떻게 되나요?',
                ['오전', '오후', '저녁', '새벽', '일정 없음'],
                mostDrowsyTime,
                (v) => setState(() => mostDrowsyTime = v),
              ),
              _q(
                'Q12. 최근 1주일 평균 수면 시간은 어떻게 되나요?',
                ['4시간 이하', '4~6시간', '6~7시간', '7~8시간', '8시간 이상'],
                averageSleepDuration,
                (v) => setState(() => averageSleepDuration = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;

                          m['napFrequency'] = napFrequencyMap[napFrequency];
                          m['napDuration'] = napDurationMap[napDuration];
                          m['mostDrowsyTime'] =
                              mostDrowsyTimeMap[mostDrowsyTime];
                          m['averageSleepDuration'] =
                              averageSleepDurationMap[averageSleepDuration];

                          await storage.write(
                            key: 'napFrequency',
                            value: napFrequencyMap[napFrequency] ?? '',
                          );
                          await storage.write(
                            key: 'napDuration',
                            value: napDurationMap[napDuration] ?? '',
                          );
                          await storage.write(
                            key: 'mostDrowsyTime',
                            value: mostDrowsyTimeMap[mostDrowsyTime] ?? '',
                          );
                          await storage.write(
                            key: 'averageSleepDuration',
                            value:
                                averageSleepDurationMap[averageSleepDuration] ??
                                '',
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
