import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> sleepLightUsageMap = {
  '완전히 끄고 잔다': 'off',
  '무드등 또는 약한 조명': 'moodLight',
  '형광등/밝은 조명': 'brightLight',
};

const Map<String, String> lightColorTemperatureMap = {
  '차가운 하얀색(6500K)': 'coolWhite',
  '중간 톤(4000K)': 'neutral',
  '따뜻한 노란색(2700K)': 'warmYellow',
  '모르겠어요': 'unknown',
};

const Map<String, String> noisePreferenceMap = {
  '완전한 무음': 'silence',
  '백색소음': 'whiteNoise',
  '유튜브': 'youtube',
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
  String _hex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0')}'; // AARRGGBB

  void _logRadioColors(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.radioTheme.fillColor; // Theme에서 지정된 경우

    // 선택/미선택 상태에 대해 Theme 값을 해석
    final selectedColor =
        fill?.resolve({MaterialState.selected}) ?? theme.colorScheme.primary;

    final unselectedColor =
        fill?.resolve({}) ??
        theme.unselectedWidgetColor ?? // (M2) 있을 수 있음
        theme.colorScheme.onSurface.withOpacity(0.6); // 기본 링 색 추정

    debugPrint('▶ Radio selected  = $selectedColor (${_hex(selectedColor)})');
    debugPrint(
      '▶ Radio unselect = $unselectedColor (${_hex(unselectedColor)})',
    );
  }

  bool get isValid =>
      sleepLightUsage != null &&
      lightColorTemperature != null &&
      noisePreference != null &&
      youtubeContentType != null &&
      (noisePreference != '기타' ||
          (userInputNoise != null && userInputNoise!.isNotEmpty)) &&
      (youtubeContentType != '기타' ||
          (userInputYoutube != null && userInputYoutube!.isNotEmpty));

  Widget _buildQuestionCard(
    String title,
    List<String> options,
    String? groupValue,
    Function(String?) onChanged,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...options.map(
            (option) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color:
                    groupValue == option
                        ? const Color(0xFF6C63FF).withOpacity(0.2)
                        : const Color(0xFF0A0E21),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      groupValue == option
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
                        groupValue == option
                            ? FontWeight.w600
                            : FontWeight.normal,
                  ),
                ),
                value: option,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: const Color(0xFF6C63FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logRadioColors(context);
    });

    // 시스템 UI 스타일 설정 (상태바, 네비게이션바 색상)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0A0E21), // 상태바 배경색
        statusBarIconBrightness: Brightness.light, // 상태바 아이콘 색상 (밝게)
        systemNavigationBarColor: Color(0xFF0A0E21), // 하단 네비게이션바 배경색
        systemNavigationBarIconBrightness: Brightness.light, // 하단 아이콘 색상 (밝게)
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '알라와 코잘라',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                      Icons.home,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '수면 환경 설정',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '수면에 영향을 주는\n환경 요소들을 알려주세요',
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
            Container(
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
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'lib/assets/koala.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Q1 - 수면 시 조명 사용
            _buildQuestionCard(
              'Q1. 수면 시 조명을 어떻게 사용하나요?',
              ['완전히 끄고 잔다', '무드등 또는 약한 조명', '형광등/밝은 조명'],
              sleepLightUsage,
              (v) => setState(() => sleepLightUsage = v),
            ),

            // Q2 - 조명 색온도
            _buildQuestionCard(
              'Q2. 조명의 색온도는 어떤 것을 선호하시나요?',
              ['차가운 하얀색(6500K)', '중간 톤(4000K)', '따뜻한 노란색(2700K)', '모르겠어요'],
              lightColorTemperature,
              (v) => setState(() => lightColorTemperature = v),
            ),

            // Q3 - 수면시 소리 선호
            _buildQuestionCard(
              'Q3. 수면시에 어떤 소리를 좋아하시나요?',
              ['완전한 무음', '백색소음', '유튜브', '기타'],
              noisePreference,
              (v) => setState(() {
                noisePreference = v;
                if (v != '기타') userInputNoise = null;
              }),
            ),

            // 기타 소리 입력 필드
            if (noisePreference == '기타')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
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
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "기타 소리 유형 입력",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '기타 소리 유형을 입력해주세요',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0A0E21),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C63FF),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged:
                          (value) =>
                              setState(() => userInputNoise = value.trim()),
                    ),
                  ],
                ),
              ),

            // Q4 - 유튜브 콘텐츠 선호
            _buildQuestionCard(
              'Q4. 유튜브 콘텐츠를 틀면 무엇을 선호하시나요?',
              ['ASMR', '음악', '라디오', '드라마', '기타'],
              youtubeContentType,
              (v) => setState(() {
                youtubeContentType = v;
                if (v != '기타') userInputYoutube = null;
              }),
            ),

            // 기타 유튜브 콘텐츠 입력 필드
            if (youtubeContentType == '기타')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
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
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "기타 유튜브 콘텐츠 유형 입력",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '기타 유튜브 콘텐츠 유형을 입력해주세요',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0A0E21),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C63FF),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged:
                          (value) =>
                              setState(() => userInputYoutube = value.trim()),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 다음 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                        isValid ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
