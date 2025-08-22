import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../onboarding_data.dart';

class CompletePage extends StatelessWidget {
  final VoidCallback onSubmit;
  const CompletePage({Key? key, required this.onSubmit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Center(
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
                  child: Image.asset(
                    'lib/assets/koala.png',
                    width: 130,
                    height: 130,
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
                          '아침': 'morning',
                          '낮': 'day',
                          '밤': 'night',
                          '안 함': 'none',
                          'morning': 'morning',
                          'day': 'day',
                          'night': 'night',
                          'none': 'none',
                        };
                        return m[v];
                      }

                      String? _coerceExerciseFrequency(String? v) {
                        if (v == null) return null;
                        const m = {
                          '안 함': 'none',
                          '주 2-3회': '2to3week',
                          '매일': 'daily',
                          'none': 'none',
                          '2to3week': '2to3week',
                          'daily': 'daily',
                        };
                        return m[v];
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
                        'mostDrowsyTime',
                        'averageSleepDuration',
                        'preferredSleepSound',
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
                      surveyData['sleepIssues'] = _normalizeNone(sleepIssues);

                      final emo =
                          await _readList('emotionalSleepInterference') ??
                          const <String>[];
                      surveyData['emotionalSleepInterference'] = emo;

                      final sleepDevices =
                          await _readList('sleepDevicesUsed') ??
                          const <String>[];
                      surveyData['sleepDevicesUsed'] = sleepDevices;

                      final sleepGoal =
                          await _readList('sleepGoal') ?? const <String>[];
                      surveyData['sleepGoal'] = sleepGoal;

                      // ✅ enum 보정이 필요한 것들
                      final exWhenRaw = await _readStringWithStorageFirst(
                        'exerciseWhen',
                      );
                      final exWhen = _coerceExerciseWhen(exWhenRaw);
                      if (exWhen != null) surveyData['exerciseWhen'] = exWhen;

                      final exFreqRaw = await _readStringWithStorageFirst(
                        'exerciseFrequency',
                      );
                      final exFreq = _coerceExerciseFrequency(exFreqRaw);
                      if (exFreq != null)
                        surveyData['exerciseFrequency'] = exFreq;

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
                        // ignore: use_build_context_synchronously
                        Navigator.pushReplacementNamed(context, '/real-home');
                      } else {
                        debugPrint('❌ 설문 저장 실패: ${resp.statusCode}');
                        debugPrint(resp.body);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('설문 저장 실패: ${resp.statusCode}'),
                          ),
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
      ),
    );
  }
}
