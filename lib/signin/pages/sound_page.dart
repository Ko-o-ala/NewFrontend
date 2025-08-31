import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../onboarding_data.dart';

final storage = FlutterSecureStorage();
// 파일 상단 아무 데나(클래스 밖) 추가

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
  String? calmingSoundOtherInput;

  String? preferredSleepSoundLabel; // 라벨(한국어) 보관
  String? calmingSoundTypeLabel; // 라벨(한국어) 보관
  double preferenceBalance = 0.5; // 0.0 ~ 1.0

  bool get isValid =>
      preferredSleepSoundLabel != null &&
      calmingSoundTypeLabel != null &&
      (calmingSoundTypeLabel != '기타' ||
          (calmingSoundOtherInput != null &&
              calmingSoundOtherInput!.isNotEmpty));

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

          // ✅ 세로로 '한 줄씩'만 보이도록 ListView.separated 사용
          ListView.separated(
            shrinkWrap: true, // 부모 스크롤(SingleChildScrollView)에 맞춤
            physics: const NeverScrollableScrollPhysics(), // 이 리스트 자체는 스크롤 금지
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final option = options[index];
              final selected = groupValue == option;
              return Container(
                decoration: BoxDecoration(
                  color:
                      selected
                          ? const Color(0xFF6C63FF).withOpacity(0.2)
                          : const Color(0xFF0A0E21),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selected
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: RadioListTile<String>(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  value: option,
                  groupValue: groupValue,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF6C63FF),
                  dense: true, // 높이 조금 더 컴팩트하게
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        child: SingleChildScrollView(
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
                        Icons.music_note,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '사운드 선호도',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수면에 도움이 되는\n사운드 선호도를 알려주세요',
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

              // Q15 - 수면 시 듣고 싶은 소리
              _buildQuestionCard(
                'Q15. 수면 시 듣고 싶은 소리는 어떤 것인가요?',
                preferredSleepSoundMap.keys.toList(),
                preferredSleepSoundLabel,
                (v) => setState(() => preferredSleepSoundLabel = v),
              ),

              // Q16 - 마음을 안정시키는 사운드
              _buildQuestionCard(
                'Q16. 마음을 안정시키는 사운드는 어떤 것인가요?',
                calmingSoundTypeMap.keys.toList(),
                calmingSoundTypeLabel,
                (v) => setState(() => calmingSoundTypeLabel = v),
              ),

              // 기타 입력 필드
              if (calmingSoundTypeLabel == '기타')
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
                            "기타 사운드 입력",
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: '기타 사운드를 입력해주세요',
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
                            (value) => setState(
                              () => calmingSoundOtherInput = value.trim(),
                            ),
                      ),
                    ],
                  ),
                ),

              // Q17 - 선호도 vs 알고리즘 추천
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
                            color: const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.balance,
                            color: Color(0xFF6C63FF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Q17. 선호하는 사운드 vs 알고리즘이 추천해주는 사운드?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF6C63FF),
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                        thumbColor: const Color(0xFF6C63FF),
                        overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
                        valueIndicatorColor: const Color(0xFF6C63FF),
                        valueIndicatorTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Slider(
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        value: preferenceBalance,
                        onChanged: (v) => setState(() => preferenceBalance = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '내가 좋아하는 소리를\n더 추천해주세요',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '수면 데이터에 맞춰\n추천해주세요',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
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

                            // 라벨 → enum 값 변환
                            final preferredEnum =
                                preferredSleepSoundMap[preferredSleepSoundLabel]!;
                            final calmingEnum =
                                calmingSoundTypeMap[calmingSoundTypeLabel]!;
                            if (calmingSoundTypeLabel == '기타' &&
                                calmingSoundOtherInput != null &&
                                calmingSoundOtherInput!.isNotEmpty) {
                              m['calmingSoundTypeOther'] =
                                  calmingSoundOtherInput;
                            }

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
