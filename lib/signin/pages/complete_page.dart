import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../onboarding_data.dart';
import 'package:http/http.dart' as http;

class CompletePage extends StatelessWidget {
  const CompletePage({super.key}); // ← 추가
  @override
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
                        Icons.celebration,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '🎉 모든 준비가 완료됐어요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '알라야가 곧 수면 분석 리포트를\n보여드릴게요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.4,
                      ),
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
                  width: 150,
                  height: 150,
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
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 완료 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final storage = const FlutterSecureStorage();
                    final token = await storage.read(key: 'jwt');

                    // --- helpers ---
                    Future<List<String>?> _readList(String key) async {
                      final raw = await storage.read(key: key);
                      if (raw != null) {
                        try {
                          final v = jsonDecode(raw);
                          if (v is List)
                            return v.map((e) => e.toString()).toList();
                        } catch (_) {
                          // 단일 문자열로 저장되어 있던 경우 ["value"]로 감싸기
                          if (raw.trim().isNotEmpty) return [raw.trim()];
                        }
                      }
                      // 저장소가 없으면 메모리(OnboardingData) 폴백
                      final mem = OnboardingData.answers[key];
                      if (mem is List)
                        return mem.map((e) => e.toString()).toList();
                      if (mem is String && mem.isNotEmpty) return [mem];
                      return null;
                    }

                    String? _readString(String key) =>
                        OnboardingData.answers[key] as String?;
                    Future<String?> _readStringWithStorageFirst(
                      String key,
                    ) async {
                      final s = await storage.read(key: key);
                      return s ?? _readString(key);
                    }

                    List<String> _normalizeNone(List<String> arr) =>
                        arr.contains('none') ? const ['none'] : arr;

                    String? _coerceExerciseWhen(String? v) {
                      if (v == null) return null;
                      const m = {
                        '8시 이전': 'before8',
                        '8~12시': '8to12',
                        '12시~16시': '12to16',
                        '16~20시': '16to20',
                        '20~24시': '20to24',
                        '새벽': 'night',
                        '안함': 'none',
                        '8시 ~ 12시': '8to12', // 공백 포함 버전
                        '12시 ~ 16시': '12to16', // 공백 포함 버전
                        '16시 ~ 20시': '16to20', // 공백 포함 버전
                        '20시 ~ 24시': '20to24', // 공백 포함 버전
                        'before8': 'before8',
                      };
                      return m[v];
                    }

                    String? _coerceExerciseFrequency(String? v) {
                      if (v == null) return null;
                      const m = {
                        '하지 않음': 'none',
                        '주2~3회': '2to3week',
                        '매일': 'dailyMorning',
                        '안 함': 'none',
                        '주 2-3회': '2to3week',
                        'none': 'none',
                        '2to3week': '2to3week',
                        'daily': 'dailyMorning',
                      };
                      return m[v];
                    }

                    String? _coerceMostDrowsyTime(String? v) {
                      if (v == null) return null;
                      final vv = v.trim();

                      // 서버가 허용하는 값이면 그대로 반환
                      const allowed = {
                        'morningWakeup',
                        'afterLunch',
                        'afternoon',
                        'afterDinner',
                        'night',
                        'random',
                      };
                      if (allowed.contains(vv)) return vv;

                      // 한글/레거시 라벨 보정
                      const m = {
                        // 현재 UI 라벨
                        '아침 기상 직후': 'morningWakeup',
                        '점심 시간 후': 'afterLunch',
                        '오후 활동 시간': 'afternoon',
                        '저녁 식사 후': 'afterDinner',
                        '밤/늦은 시간': 'night',
                        '일정하지 않음': 'random',
                        // 예전/다른 라벨
                        '일정 없음': 'random',
                        '오전': 'morningWakeup',
                        '오후': 'afternoon',
                        '저녁': 'afterDinner',
                        '새벽': 'night',
                        'morning': 'morningWakeup',
                        'evening': 'afterDinner',
                        'morningWakeUp': 'morningWakeup', // 레거시 값 보정
                      };
                      return m[vv];
                    }

                    String? _coerceCalmingSoundToPreferredSleepSound(
                      String? v,
                    ) {
                      if (v == null) return null;
                      const m = {
                        'rain': 'nature', // 비 오는 소리 -> 자연음
                        'waves': 'nature', // 파도/물소리 -> 자연음
                        'piano': 'music', // 잔잔한 피아노 -> 음악
                        'humanVoice': 'voice', // 사람의 말소리 -> 음성
                        'other': 'nature', // 기타 -> 자연음 (기본값)
                      };
                      return m[v];
                    }

                    List<String> _coerceSleepIssues(List<String> issues) {
                      const m = {
                        '잠들기 어려움': 'fallAsleepHard',
                        '자주 깨요': 'wakeOften',
                        '일찍 깨요': 'wakeEarly',
                        '낮 졸림': 'daySleepy',
                        '악몽/불안': 'nightmares',
                        '수면 중 움직임 많음': 'movesALot',
                        '아침에 개운하지 않음': 'notRested',
                        '수면제/수면 보조제 사용함': 'useSleepingPills',
                        '없음': 'none',
                        'fallAsleepHard': 'fallAsleepHard',
                        'wakeOften': 'wakeOften',
                        'wakeEarly': 'wakeEarly',
                        'daySleepy': 'daySleepy',
                        'nightmares': 'nightmares',
                        'movesALot': 'movesALot',
                        'notRested': 'notRested',
                        'useSleepingPills': 'useSleepingPills',
                        'none': 'none',
                      };
                      return issues.map((issue) => m[issue] ?? issue).toList();
                    }

                    List<String> _coerceEmotionalSleepInterference(
                      List<String> emotions,
                    ) {
                      const m = {
                        '스트레스': 'stress',
                        '불안감': 'anxiety',
                        '외로움': 'loneliness',
                        '긴장': 'tension',
                        '기타': 'other',
                        'stress': 'stress',
                        'anxiety': 'anxiety',
                        'loneliness': 'loneliness',
                        'tension': 'tension',
                        'other': 'other',
                      };
                      return emotions
                          .map((emotion) => m[emotion] ?? emotion)
                          .toList();
                    }
                    // --- /helpers ---

                    // 기존 키들 + 빠졌던 키들 포함
                    final surveyData = <String, dynamic>{};

                    // 이미 잘 들어가던 필드들은 기존 로직 유지 (생략 가능)
                    final directKeys = [
                      'sleepLightUsage',
                      'lightColorTemperature',
                      'noisePreference',
                      'youtubeContentType',
                      'usualBedtime',
                      'usualWakeupTime',
                      'dayActivityType',
                      'morningSunlightExposure',
                      'napFrequency',
                      'napDuration',
                      // 'mostDrowsyTime', // 변환 함수 사용하므로 제외
                      'averageSleepDuration',
                      // 'preferredSleepSound', // 변환 함수 사용하므로 제외
                      'calmingSoundType',

                      'soundAutoOffType',
                      'timeToFallAsleep',
                      'caffeineIntakeLevel',
                      'screenTimeBeforeSleep',
                      'stressLevel',
                      'preferredFeedbackFormat',
                    ];
                    for (final k in directKeys) {
                      final v =
                          await storage.read(key: k) ??
                          (OnboardingData.answers[k]?.toString());
                      if (v != null) surveyData[k] = v;
                    }

                    // ✅ 반드시 배열로 넣어야 하는 것들
                    final sleepIssues =
                        await _readList('sleepIssues') ?? const <String>[];
                    surveyData['sleepIssues'] = _coerceSleepIssues(
                      _normalizeNone(sleepIssues),
                    );

                    final emo =
                        await _readList('emotionalSleepInterference') ??
                        const <String>[];
                    surveyData['emotionalSleepInterference'] =
                        _coerceEmotionalSleepInterference(emo);

                    final sleepDevices =
                        await _readList('sleepDevicesUsed') ?? const <String>[];
                    surveyData['sleepDevicesUsed'] = sleepDevices;

                    // sleepGoal은 단일 값으로 저장됨 (goal_page.dart에서 확인)
                    final sleepGoalRaw = await _readStringWithStorageFirst(
                      'sleepGoal',
                    );
                    if (sleepGoalRaw != null) {
                      // 이미 서버 형식으로 저장되어 있으므로 그대로 사용
                      surveyData['sleepGoal'] = sleepGoalRaw;
                    }

                    // ✅ enum 보정이 필요한 것들
                    final exWhenRaw = await _readStringWithStorageFirst(
                      'exerciseWhen',
                    );
                    const allowed = {
                      'before8',
                      '8to12',
                      '12to16',
                      '16to20',
                      '20to24',
                      'night',
                    };
                    debugPrint('=== exerciseWhen 디버그 ===');
                    debugPrint('원본 값: $exWhenRaw (${exWhenRaw.runtimeType})');
                    if (exWhenRaw != null && allowed.contains(exWhenRaw)) {
                      surveyData['exerciseWhen'] = exWhenRaw;
                      debugPrint('surveyData.exerciseWhen = $exWhenRaw');
                    } else {
                      debugPrint('❌ exerciseWhen 누락/잘못된 값: $exWhenRaw');
                    }

                    final exFreqRaw = await _readStringWithStorageFirst(
                      'exerciseFrequency',
                    );
                    final exFreq = _coerceExerciseFrequency(exFreqRaw);
                    if (exFreq != null)
                      surveyData['exerciseFrequency'] = exFreq;

                    // preferredSleepSound 변환 (calmingSoundType에서 매핑)
                    final calmingSoundRaw = await _readStringWithStorageFirst(
                      'calmingSoundType',
                    );
                    final preferredSound =
                        _coerceCalmingSoundToPreferredSleepSound(
                          calmingSoundRaw,
                        );
                    if (preferredSound != null)
                      surveyData['preferredSleepSound'] = preferredSound;

                    // mostDrowsyTime 변환
                    final mostDrowsyTimeRaw = await _readStringWithStorageFirst(
                      'mostDrowsyTime',
                    );
                    final mostDrowsyTime = _coerceMostDrowsyTime(
                      mostDrowsyTimeRaw,
                    );
                    if (mostDrowsyTime != null)
                      surveyData['mostDrowsyTime'] = mostDrowsyTime;

                    // ✅ 숫자
                    final prefBalStr =
                        await storage.read(key: 'preferenceBalance') ??
                        (OnboardingData.answers['preferenceBalance']
                            ?.toString());
                    if (prefBalStr != null) {
                      final n = num.tryParse(prefBalStr);
                      if (n != null)
                        surveyData['preferenceBalance'] =
                            n is int ? n : n.toDouble();
                    }

                    // 디버그 확인
                    debugPrint(
                      'REQ /users/survey => ${jsonEncode(surveyData)}',
                    );
                    surveyData.forEach(
                      (k, v) => debugPrint('$k => ${v.runtimeType} : $v'),
                    );

                    // 문제가 되는 필드들 특별 확인
                    debugPrint('=== 문제 필드 확인 ===');
                    debugPrint(
                      'preferredSleepSound: ${surveyData['preferredSleepSound']}',
                    );
                    debugPrint('exerciseWhen: ${surveyData['exerciseWhen']}');
                    debugPrint('sleepGoal: ${surveyData['sleepGoal']}');
                    debugPrint('sleepIssues: ${surveyData['sleepIssues']}');
                    debugPrint(
                      'emotionalSleepInterference: ${surveyData['emotionalSleepInterference']}',
                    );
                    debugPrint(
                      'calmingSoundType: ${surveyData['calmingSoundType']}',
                    );
                    debugPrint('==================');

                    final resp = await http.patch(
                      Uri.parse('https://kooala.tassoo.uk/users/survey'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer $token',
                      },
                      body: jsonEncode(surveyData),
                    );

                    if (resp.statusCode == 200) {
                      debugPrint('✅ 설문 저장 성공');

                      // 설문 완료 후 로그인 화면으로 이동
                      // ignore: use_build_context_synchronously
                      Navigator.pushReplacementNamed(context, '/login');
                    } else {
                      debugPrint('❌ 설문 저장 실패: ${resp.statusCode}');
                      debugPrint(resp.body);
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('설문 저장 실패: ${resp.statusCode}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                  child: const Text(
                    '고마워!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
