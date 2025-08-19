import 'package:flutter/material.dart';
import 'package:my_app/sleep_dashboard/sleep_chart_screen.dart';
import 'package:my_app/sleep_dashboard/sleep_entry.dart';
import 'package:health/health.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SleepEntry> entries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchSleepData();
  }

  Future<void> fetchSleepData() async {
    final health = Health();
    final types = [
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_LIGHT,
    ];
    final permissions = List.filled(types.length, HealthDataAccess.READ);

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(hours: 6));
    final end = DateTime(now.year, now.month, now.day, 12);

    final authorized = await health.requestAuthorization(
      types,
      permissions: permissions,
    );
    if (!authorized) {
      print('❌ 건강 앱 접근 거부됨');
      return;
    }

    try {
      final rawData = await health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );

      final result =
          rawData
              .map(
                (d) =>
                    SleepEntry(start: d.dateFrom, end: d.dateTo, type: d.type),
              )
              .toList();

      setState(() {
        entries = result;
        loading = false;
      });
    } catch (e) {
      print('⚠️ 오류 발생: $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text('로그인 화면 가기'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/sleep');
                      },
                      child: const Text('수면 대시보드 가기'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/time-set');
                      },
                      child: const Text('수면 목표 설정 가기'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/test');
                      },
                      child: const Text('테스트 화면 바로가기'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/start');
                      },
                      child: const Text('시작하기'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/sound');
                      },
                      child: const Text('사운드 화면 가기'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (entries.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('수면 데이터가 없습니다.')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SleepChartScreen(
                                  entries: entries,
                                  selectedDate: DateTime.now().subtract(
                                    const Duration(hours: 6),
                                  ),
                                ),
                          ),
                        );
                      },
                      child: const Text('수면 차트 보기'),
                    ),
                  ],
                ),
              ),
    );
  }
}
