import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> napFrequencyMap = {
  '매일': 'daily',
  '주 3~4회': '3to4perWeek',
  '주 1~2회': '1to2perWeek',
  '거의 안 잠': 'rarely',
};

const Map<String, String> napDurationMap = {
  '안잠': 'none',
  '15분 이내': 'under15',
  '15~30분': '15to30',
  '30분~1시간': '30to60',
  '1시간 이상': 'over60',
};

const Map<String, String> mostDrowsyTimeMap = {
  '아침 기상 직후': 'morningWakeup',
  '점심 시간 후': 'afterLunch',
  '오후 활동 시간': 'afternoon',
  '저녁 식사 후': 'afterDinner',
  '밤/늦은 시간': 'night',
  '일정하지 않음': 'random',
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

  late ScrollController _scrollController;
  final GlobalKey _question9Key = GlobalKey();
  final GlobalKey _question10Key = GlobalKey();
  final GlobalKey _question11Key = GlobalKey();
  final GlobalKey _question12Key = GlobalKey();

  bool get isValid =>
      napFrequency != null &&
      napDuration != null &&
      mostDrowsyTime != null &&
      averageSleepDuration != null;

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
              key: key,
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
                  const Icon(Icons.touch_app, color: Colors.white70, size: 16),
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
                        Icons.nightlight,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '수면 패턴 상세',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '낮잠과 수면 시간에 대한\n더 자세한 정보를 알려주세요',
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
                'Q9. 낮잠은 얼마나 자주 주무시나요?',
                ['매일', '주 3~4회', '주 1~2회', '거의 안 잠'],
                napFrequency,
                (v) => setState(() => napFrequency = v),
                key: _question9Key,
                onTitleTap: () => _scrollToQuestion(_question9Key),
              ),
              _buildQuestionCard(
                'Q10. 평소에 낮잠은 얼마나 주무시나요?',
                ['안잠', '15분 이내', '15~30분', '30분~1시간', '1시간 이상'],
                napDuration,
                (v) => setState(() => napDuration = v),
                key: _question10Key,
                onTitleTap: () => _scrollToQuestion(_question10Key),
              ),
              _buildQuestionCard(
                'Q11. 가장 졸리거나 피곤한 시간대는 어떻게 되나요?',
                [
                  '아침 기상 직후',
                  '점심 시간 후',
                  '오후 활동 시간',
                  '저녁 식사 후',
                  '밤/늦은 시간',
                  '일정하지 않음',
                ],
                mostDrowsyTime,
                (v) => setState(() => mostDrowsyTime = v),
                key: _question11Key,
                onTitleTap: () => _scrollToQuestion(_question11Key),
              ),
              _buildQuestionCard(
                'Q12. 최근 1주일 평균 수면 시간은 어떻게 되나요?',
                ['4시간 이하', '4~6시간', '6~7시간', '7~8시간', '8시간 이상'],
                averageSleepDuration,
                (v) => setState(() => averageSleepDuration = v),
                key: _question12Key,
                onTitleTap: () => _scrollToQuestion(_question12Key),
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
