import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'sleep_entry.dart';
import 'package:health/health.dart';

// 수면 단계에 숫자 매핑 함수
double stageToValue(HealthDataType type) {
  switch (type) {
    case HealthDataType.SLEEP_AWAKE:
      return 0;
    case HealthDataType.SLEEP_LIGHT:
      return 1;
    case HealthDataType.SLEEP_REM:
      return 2;
    case HealthDataType.SLEEP_DEEP:
      return 3;
    default:
      return -1;
  }
}

class SleepChartScreen extends StatelessWidget {
  final List<SleepEntry> entries;
  final DateTime selectedDate;

  const SleepChartScreen({
    Key? key,
    required this.entries,
    required this.selectedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalSleep = entries.fold<Duration>(
      Duration.zero,
      (prev, e) => prev + e.duration,
    );

    final now = DateTime.now();
    final baseTime = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(hours: 6));

    final spots = <FlSpot>[];

    for (var entry in entries) {
      final startMin = entry.start.difference(baseTime).inMinutes.toDouble();
      final endMin = entry.end.difference(baseTime).inMinutes.toDouble();
      final y = stageToValue(entry.type).toDouble();

      // ✅ 같은 y 값을 가진 시작, 종료 두 점 추가
      spots.add(FlSpot(startMin, y));
      spots.add(FlSpot(endMin, y));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('수면 단계 (Line Chart)')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${totalSleep.inHours}시간 ${totalSleep.inMinutes % 60}분',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('yyyy년 M월 d일').format(selectedDate),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              width: double.infinity,
              child:
                  spots.isEmpty
                      ? const Center(child: Text('수면 데이터가 없습니다.'))
                      : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 18 * 60.0, // 18시간 기준
                          minY: 0,
                          maxY: 3,
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, _) {
                                  const labels = [
                                    'Awake',
                                    'Light',
                                    'REM',
                                    'Deep',
                                  ];
                                  return Text(
                                    labels[val.toInt()],
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                                interval: 1,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 180,
                                getTitlesWidget: (val, _) {
                                  final h = (val / 60).floor();
                                  final m = (val % 60).toInt();
                                  return Text(
                                    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true, // ✅ 곡선으로 변경!
                              barWidth: 4,
                              color: Colors.indigo,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      ),
            ),
            const Divider(),
            _buildSummary(entries),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<SleepEntry> entries) {
    final Map<String, Duration> summary = {};
    for (var e in entries) {
      final key = e.readableType;
      summary[key] = (summary[key] ?? Duration.zero) + e.duration;
    }
    return Column(
      children:
          summary.entries.map((e) {
            return ListTile(
              leading: _getDot(e.key),
              title: Text(e.key),
              trailing: Text('${e.value.inHours}시간 ${e.value.inMinutes % 60}분'),
            );
          }).toList(),
    );
  }

  Widget _getDot(String type) {
    final color =
        {
          '깨어있음': Colors.redAccent,
          'REM 수면': Colors.lightBlue,
          '코어 수면': Colors.blue,
          '깊은 수면': Colors.indigo,
        }[type] ??
        Colors.grey;

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
