import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> timeToFallAsleepMap = {
  '5분 이하': 'under5min',
  '5~15분': '5to15min',
  '15~30분': '15to30min',
  '30~1시간': 'over30min',
  '1시간 이상': 'over1h',
};

const Map<String, String> caffeineIntakeLevelMap = {
  '안 마심': 'none',
  '하루 1~2잔': '1to2cups',
  '하루 3~4잔': 'over3cups',
  '하루 5잔 이상': 'over5cups',
};

const Map<String, String> exerciseFrequencyMap = {
  '하지 않음': 'none',
  '주2~3회': '2to3week',
  '매일': 'daily',
};

const Map<String, String> screenTimeBeforeSleepMap = {
  '없음': 'none',
  '30분 미만': 'under30min',
  '30분~1시간': '30to1h',
  '1시간~2시간': '1hto2h',
  '2시간~3시간': '2hto3h',
  '3시간 이상': 'over3h',
};

const Map<String, String> stressLevelMap = {
  '높음': 'high',
  '보통': 'medium',
  '낮음': 'low',
};
const Map<String, String> exerciseWhenMap = {
  '8시 이전': 'before8',
  '8~12시': '8to12',
  '12~16시': '12to16',
  '16~20시': '16to20',
  '20~24시': '20to24',
  '새벽': 'night',
  '안함': 'none',
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

  late ScrollController _scrollController;
  final GlobalKey _question9Key = GlobalKey();
  final GlobalKey _question10Key = GlobalKey();
  final GlobalKey _question11Key = GlobalKey();
  final GlobalKey _question12Key = GlobalKey();
  final GlobalKey _question13Key = GlobalKey();
  final GlobalKey _question14Key = GlobalKey();

  bool get isValid =>
      timeToFallAsleep != null &&
      caffeineIntakeLevel != null &&
      exerciseFrequency != null &&
      screenTimeBeforeSleep != null &&
      stressLevel != null;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToQuestion(GlobalKey key) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final scrollOffset =
          _scrollController.offset + position.dy - 200; // 200px 여백으로 증가
      _scrollController.animateTo(
        scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildQuestionCard(
    String title,
    List<String> options,
    String? groupValue,
    Function(String?) onChanged, {
    GlobalKey? key,
    VoidCallback? onTitleTap,
  }) {
    return Container(
      key: key,
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
          GestureDetector(
            onTap: onTitleTap,
            child: Row(
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
                if (onTitleTap != null)
                  const Icon(Icons.touch_app, color: Colors.white54, size: 16),
              ],
            ),
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
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
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
                        Icons.favorite,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '건강 상태 파악',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수면에 영향을 주는\n건강 관련 정보를 알려주세요',
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

              const SizedBox(height: 20),

              // 질문들
              _buildQuestionCard(
                'Q19. 잠들끼까지 걸리는 시간은 보통 어떻게 되시나요?',
                ['5분 이하', '5~15분', '15~30분', '30~1시간', '1시간 이상'],
                timeToFallAsleep,
                (v) => setState(() => timeToFallAsleep = v),
                key: _question9Key,
                onTitleTap: () => _scrollToQuestion(_question9Key),
              ),
              _buildQuestionCard(
                'Q20. 커피(카페인)는 보통 하루에 몇잔정도 드시나요?',
                ['안 마심', '하루 1~2잔', '하루 3~4잔', '하루 5잔 이상'],
                caffeineIntakeLevel,
                (v) => setState(() => caffeineIntakeLevel = v),
                key: _question10Key,
                onTitleTap: () => _scrollToQuestion(_question10Key),
              ),
              _buildQuestionCard(
                'Q21. 운동을 얼마나 자주 하시나요?',
                ['하지 않음', '주2~3회', '매일'],
                exerciseFrequency,
                (v) => setState(() => exerciseFrequency = v),
                key: _question11Key,
                onTitleTap: () => _scrollToQuestion(_question11Key),
              ),
              _buildQuestionCard(
                'Q22. 운동은 언제 하시나요?',
                ['8시 이전', '8~12시', '12~16시', '16~20시', '20~24시', '새벽', '안함'],
                exerciseWhen,
                (v) => setState(() => exerciseWhen = v),
                key: _question12Key,
                onTitleTap: () => _scrollToQuestion(_question12Key),
              ),
              _buildQuestionCard(
                'Q23. 잠들기 전에 전자기기는 얼마나 사용하시나요?',
                ['없음', '30분 미만', '30분~1시간', '1시간~2시간', '2시간~3시간', '3시간 이상'],
                screenTimeBeforeSleep,
                (v) => setState(() => screenTimeBeforeSleep = v),
                key: _question13Key,
                onTitleTap: () => _scrollToQuestion(_question13Key),
              ),
              _buildQuestionCard(
                'Q24. 요즘 스트레스는 어느 정도라고 느끼시나요?',
                ['높음', '보통', '낮음'],
                stressLevel,
                (v) => setState(() => stressLevel = v),
                key: _question14Key,
                onTitleTap: () => _scrollToQuestion(_question14Key),
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
                              value:
                                  timeToFallAsleepMap[timeToFallAsleep] ?? '',
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
