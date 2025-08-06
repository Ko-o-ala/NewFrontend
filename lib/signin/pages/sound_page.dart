import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../onboarding_data.dart';

final storage = FlutterSecureStorage();
const Map<String, String> sleepIssuesMap = {
  '잠들기 어려움': 'fallAsleepHard',
  '자주 깨요': 'wakeOften',
  '일찍 깨요': 'wakeEarly',
  '낮 졸림': 'daySleepy',
  '악몽/불안': 'nightmares',
  '움직임 많음': 'movesALot',
  '없음': 'none',
};

const Map<String, String> emotionalSleepMap = {
  '스트레스': 'stress',
  '불안감': 'anxiety',
  '외로움': 'loneliness',
  '긴장': 'tension',
  '기타': 'other',
};

class SoundPage extends StatefulWidget {
  final VoidCallback onNext;
  const SoundPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> {
  String? preferredSleepSound, calmingSoundType;
  bool get isValid => preferredSleepSound != null && calmingSoundType != null;
  double stressLevel = 5;
  double preferenceBalance = 0.5; // 초기값

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
                'Q15. 수면 시 듣고 싶은 소리는?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...['자연 소리', '음악', '백색소음', '목소리 (ASMR)', '무음'].map(
                (o) => RadioListTile(
                  title: Text(o),
                  value: o,
                  groupValue: preferredSleepSound,
                  onChanged: (v) => setState(() => preferredSleepSound = v),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Q16. 마음을 안정시키는 사운드?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ...['비 오는 소리', '파도/물소리', '잔잔한 피아노', '말소리', '기타'].map(
                (o) => RadioListTile(
                  title: Text(o),
                  value: o,
                  groupValue: calmingSoundType,
                  onChanged: (v) => setState(() => calmingSoundType = v),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Q17. 선호하는 사운드 vs 알고리즘이 추천해주는 사운드 ?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Slider(
                min: 0.0,
                max: 1.0,
                divisions: 20,
                value: preferenceBalance,
                onChanged: (v) => setState(() => preferenceBalance = v),
                activeColor: Color(0xFF7D5EFF),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Expanded(
                    child: Text(
                      '내가 좋아하는 소리를\n더 추천해주세요',
                      textAlign: TextAlign.left,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '수면 데이터에 맞춰\n추천해주세요',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;
                          m['preferredSleepSound'] = preferredSleepSound;
                          m['calmingSoundType'] = calmingSoundType;
                          m['preferenceBalance'] = preferenceBalance;

                          await storage.write(
                            key: 'preferredSleepSound',
                            value: preferredSleepSound,
                          );
                          await storage.write(
                            key: 'calmingSoundType',
                            value: calmingSoundType,
                          );
                          await storage.write(
                            key: 'preferenceBalance',
                            value: preferenceBalance.toString(),
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
