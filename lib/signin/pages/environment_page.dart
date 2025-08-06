import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> sleepLightUsageMap = {
  '완전히 끄고 잔다': 'off',
  '무드등 또는 약한 조명': 'moodLight',
  '형광등/밝은 조명': 'brightLight',
};

const Map<String, String> lightColorTemperatureMap = {
  '차가운 (6500K)': 'coolWhite',
  '중간 (4000K)': 'neutral',
  '따뜻한 (2700K)': 'warmYellow',
  '모르겠어요': 'unknown',
};

const Map<String, String> noisePreferenceMap = {
  '완전 무음': 'silence',
  '백색소음': 'whiteNoise',
  '유튜브 틀어요': 'youtube',
  '기타': 'other',
};

const Map<String, String> youtubeContentTypeMap = {
  'ASMR': 'asmr',
  '음악': 'music',
  '라디오': 'radio',
  '드라마': 'drama',
  '기타': 'other',
};

class EnvironmentPage extends StatefulWidget {
  final VoidCallback onNext;
  const EnvironmentPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<EnvironmentPage> createState() => _EnvironmentPageState();
}

class _EnvironmentPageState extends State<EnvironmentPage> {
  String? sleepLightUsage,
      lightColorTemperature,
      noisePreference,
      youtubeContentType;
  String? userInputNoise;
  String? userInputYoutube;

  bool get isValid =>
      sleepLightUsage != null &&
      lightColorTemperature != null &&
      noisePreference != null &&
      youtubeContentType != null;

  Widget _buildQuestion(
    String title,
    List<String> options,
    String? groupValue,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        ...options.map(
          (o) => RadioListTile<String>(
            title: Text(o),
            value: o,
            groupValue: groupValue,
            onChanged: onChanged,
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

              _buildQuestion(
                'Q1. 수면 시 조명을 어떻게 사용하나요?',
                ['완전히 끄고 잔다', '무드등 또는 약한 조명', '형광등/밝은 조명'],
                sleepLightUsage,
                (v) => setState(() => sleepLightUsage = v),
              ),
              _buildQuestion(
                'Q2. 조명의 색온도는?',
                ['차가운 (6500K)', '중간 (4000K)', '따뜻한 (2700K)', '모르겠어요'],
                lightColorTemperature,
                (v) => setState(() => lightColorTemperature = v),
              ),
              _buildQuestion(
                'Q3. 조용한 소음을 좋아하나요?',
                ['완전 무음', '백색소음', '유튜브 틀어요', '기타'],
                noisePreference,
                (v) => setState(() => noisePreference = v),
              ),
              _buildQuestion(
                'Q4. 유튜브 콘텐츠를 틀면 무엇을 선호하시나요?',
                ['ASMR', '음악', '라디오', '드라마', '기타'],
                youtubeContentType,
                (v) => setState(() => youtubeContentType = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;

                          m['sleepLightUsage'] =
                              sleepLightUsageMap[sleepLightUsage];
                          m['lightColorTemperature'] =
                              lightColorTemperatureMap[lightColorTemperature];
                          m['noisePreference'] =
                              noisePreferenceMap[noisePreference];
                          m['youtubeContentType'] =
                              youtubeContentTypeMap[youtubeContentType];

                          // 만약 '기타' 선택 시 사용자가 텍스트로 입력한 값이 있다면 저장:
                          if (noisePreference == '기타') {
                            m['noisePreferenceOther'] =
                                userInputNoise; // 사용자가 입력한 값
                          }
                          if (youtubeContentType == '기타') {
                            m['youtubeContentTypeOther'] =
                                userInputYoutube; // 사용자가 입력한 값
                          }

                          await storage.write(
                            key: 'sleepLightUsage',
                            value: sleepLightUsageMap[sleepLightUsage] ?? '',
                          );
                          await storage.write(
                            key: 'lightColorTemperature',
                            value:
                                lightColorTemperatureMap[lightColorTemperature] ??
                                '',
                          );
                          await storage.write(
                            key: 'noisePreference',
                            value: noisePreferenceMap[noisePreference] ?? '',
                          );
                          await storage.write(
                            key: 'youtubeContentType',
                            value:
                                youtubeContentTypeMap[youtubeContentType] ?? '',
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
