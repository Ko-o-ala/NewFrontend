import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../onboarding_data.dart';

final storage = FlutterSecureStorage();
// 파일 상단 아무 데나(클래스 밖) 추가
List<String> _normalizeNone(List<String> arr) {
  return arr.contains('none') ? <String>['none'] : arr;
}

const Map<String, String> preferredSleepSoundMap = {
  '자연 소리': 'nature',
  '음악': 'music',
  '저주파/백색소음': 'lowFreq', // ← 옵션/라벨 이 이름으로 고정
  '목소리 (ASMR)': 'voice',
  '무음': 'silence',
};

const Map<String, String> calmingSoundTypeMap = {
  '비 오는 소리': 'rain',
  '파도/물소리': 'waves',
  '잔잔한 피아노': 'piano',
  '사람의 말소리': 'humanVoice', // ← 옵션/라벨 이 이름으로 고정
  '기타': 'other',
};

class SoundPage extends StatefulWidget {
  final VoidCallback onNext;
  const SoundPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> {
  String? preferredSleepSoundLabel; // 라벨(한국어) 보관
  String? calmingSoundTypeLabel; // 라벨(한국어) 보관
  double preferenceBalance = 0.5; // 0.0 ~ 1.0

  bool get isValid =>
      preferredSleepSoundLabel != null && calmingSoundTypeLabel != null;

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

              // Q15
              const Text(
                'Q15. 수면 시 듣고 싶은 소리는?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              ...preferredSleepSoundMap.keys.map(
                (label) => RadioListTile<String>(
                  title: Text(label),
                  value: label,
                  groupValue: preferredSleepSoundLabel,
                  onChanged:
                      (v) => setState(() => preferredSleepSoundLabel = v),
                ),
              ),

              const SizedBox(height: 16),

              // Q16
              const Text(
                'Q16. 마음을 안정시키는 사운드?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              ...calmingSoundTypeMap.keys.map(
                (label) => RadioListTile<String>(
                  title: Text(label),
                  value: label,
                  groupValue: calmingSoundTypeLabel,
                  onChanged: (v) => setState(() => calmingSoundTypeLabel = v),
                ),
              ),

              const SizedBox(height: 16),

              // Q17
              const Text(
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
                activeColor: const Color(0xFF7D5EFF),
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

                          // 라벨 → enum 값 변환
                          final preferredEnum =
                              preferredSleepSoundMap[preferredSleepSoundLabel]!;
                          final calmingEnum =
                              calmingSoundTypeMap[calmingSoundTypeLabel]!;

                          // 서버 스펙에 맞게 저장
                          m['preferredSleepSound'] =
                              preferredEnum; // ex) 'nature'
                          m['calmingSoundType'] = calmingEnum; // ex) 'rain'
                          m['preferenceBalance'] = preferenceBalance;
                          // 만약 서버가 0~100 정수를 요구한다면:
                          // m['preferenceBalance'] = (preferenceBalance * 100).round();

                          // 보조 저장
                          await storage.write(
                            key: 'preferredSleepSound',
                            value: preferredEnum,
                          );
                          await storage.write(
                            key: 'calmingSoundType',
                            value: calmingEnum,
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
