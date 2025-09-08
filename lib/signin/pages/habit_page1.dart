import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
const Map<String, String> usualBedtimeMap = {
  '오후 9시 이전': 'before9pm',
  '오후 9시~새벽 12시': '9to12pm',
  '새벽 12시~새벽 2시': '12to2am',
  '새벽 2시 이후': 'after2am',
};

const Map<String, String> usualWakeupTimeMap = {
  '오전 5시 이전': 'before5am',
  '오전 5시~오전 7시': '5to7am',
  '오전 7시~오전 9시': '7to9am',
  '오전 9시 이후': 'after9am',
};

const Map<String, String> dayActivityTypeMap = {
  '실내 활동 시': 'indoor',
  '실외 활동 시': 'outdoor',
  '비슷함': 'mixed',
};

const Map<String, String> morningSunlightExposureMap = {
  '1시간 이내': 'under1h',
  '1~3시간': 'between1to3',
  '3~5시간': 'between3to5',
  '5~7시간': 'between5to7',
  '7시간 이상': 'over7',
};

class HabitPage1 extends StatefulWidget {
  final VoidCallback onNext;
  const HabitPage1({Key? key, required this.onNext}) : super(key: key);

  @override
  State<HabitPage1> createState() => _HabitPage1State();
}

class _HabitPage1State extends State<HabitPage1> {
  String? usualBedTime,
      usualWakeupTime,
      dayActivityType,
      morningSunlightExposure;

  late ScrollController _scrollController;
  final GlobalKey _question5Key = GlobalKey();
  final GlobalKey _question6Key = GlobalKey();
  final GlobalKey _question7Key = GlobalKey();
  final GlobalKey _question8Key = GlobalKey();

  bool get isValid =>
      usualBedTime != null &&
      usualWakeupTime != null &&
      dayActivityType != null &&
      morningSunlightExposure != null;

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
                        Icons.bedtime,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '수면 습관 파악',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '평소 수면 패턴과\n생활 습관을 알려주세요',
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
                'Q5. 평소 취침 시간은 어떻게 되시나요?',
                ['오후 9시 이전', '오후 9시~새벽 12시', '새벽 12시~새벽 2시', '새벽 2시 이후'],
                usualBedTime,
                (v) => setState(() => usualBedTime = v),
                key: _question5Key,
                onTitleTap: () => _scrollToQuestion(_question5Key),
              ),
              _buildQuestionCard(
                'Q6. 평소 기상 시간은 어떻게 되시나요?',
                ['오전 5시 이전', '오전 5시~오전 7시', '오전 7시~오전 9시', '오전 9시 이후'],
                usualWakeupTime,
                (v) => setState(() => usualWakeupTime = v),
                key: _question6Key,
                onTitleTap: () => _scrollToQuestion(_question6Key),
              ),
              _buildQuestionCard(
                'Q7. 하루 중 어느 활동이 더 많은가요?',
                ['실내 활동 시', '실외 활동 시', '비슷함'],
                dayActivityType,
                (v) => setState(() => dayActivityType = v),
                key: _question7Key,
                onTitleTap: () => _scrollToQuestion(_question7Key),
              ),
              _buildQuestionCard(
                'Q8. 평소 아침 햇빛을 쬐는 빈도는 어떻게 되나요?',
                ['1시간 이내', '1~3시간', '3~5시간', '5~7시간', '7시간 이상'],
                morningSunlightExposure,
                (v) => setState(() => morningSunlightExposure = v),
                key: _question8Key,
                onTitleTap: () => _scrollToQuestion(_question8Key),
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

                            m['usualBedtime'] = usualBedtimeMap[usualBedTime];
                            m['usualWakeupTime'] =
                                usualWakeupTimeMap[usualWakeupTime];
                            m['dayActivityType'] =
                                dayActivityTypeMap[dayActivityType];
                            m['morningSunlightExposure'] =
                                morningSunlightExposureMap[morningSunlightExposure];

                            await storage.write(
                              key: 'usualBedtime',
                              value: usualBedtimeMap[usualBedTime] ?? '',
                            );
                            await storage.write(
                              key: 'usualWakeupTime',
                              value: usualWakeupTimeMap[usualWakeupTime] ?? '',
                            );
                            await storage.write(
                              key: 'dayActivityType',
                              value: dayActivityTypeMap[dayActivityType] ?? '',
                            );
                            await storage.write(
                              key: 'morningSunlightExposure',
                              value:
                                  morningSunlightExposureMap[morningSunlightExposure] ??
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
