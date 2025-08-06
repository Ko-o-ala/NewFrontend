import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CompletePage extends StatelessWidget {
  final VoidCallback onSubmit;
  const CompletePage({Key? key, required this.onSubmit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('lib/assets/koala.png', width: 130),
              const SizedBox(height: 24),
              const Text(
                '🎉 모든 준비가 완료됐어요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '알라야가 곧 수면 분석 리포트를 보여드릴게요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  final storage = FlutterSecureStorage();
                  final token = await storage.read(key: 'jwt');

                  final surveyKeys = [
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
                    'sleepIssues',
                    'emotionalSleepInterference',
                    'preferredSleepSound',
                    'calmingSoundType',
                    'sleepDevicesUsed',
                    'soundAutoOffType',
                    'timeToFallAsleep',
                    'caffeineIntakeLevel',
                    'exerciseFrequency',
                    'screenTimeBeforeSleep',
                    'stressLevel',
                    'sleepGoal',
                    'preferredFeedbackFormat',
                  ];

                  final listKeys = [
                    'sleepIssues',
                    'emotionalSleepInterference',
                    'sleepDevicesUsed',
                  ];

                  final surveyData = <String, dynamic>{};
                  for (var key in surveyKeys) {
                    final val = await storage.read(key: key);
                    if (val != null) {
                      if (listKeys.contains(key)) {
                        try {
                          surveyData[key] = jsonDecode(val); // 👈 여기가 문제였음
                        } catch (e) {
                          print('⚠️ JSON 파싱 실패 - key: $key, value: $val');
                          surveyData[key] = []; // 혹은 적절한 기본값
                        }
                      } else {
                        surveyData[key] = val;
                      }
                    }
                  }

                  final resp = await http.patch(
                    Uri.parse('https://kooala.tassoo.uk/users/survey'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: jsonEncode(surveyData),
                  );

                  if (resp.statusCode == 200) {
                    print('✅ 설문 저장 성공');
                    Navigator.pushReplacementNamed(context, '/real-home');
                  } else {
                    print('❌ 설문 저장 실패: ${resp.statusCode}');
                    print(resp.body);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('설문 저장 실패: ${resp.statusCode}')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8183D9),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '고마워!',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
