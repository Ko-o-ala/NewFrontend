import 'package:flutter/material.dart';
import 'sleep_entry.dart';
import 'package:health/health.dart';
import 'sleep_segment.dart';

import 'sleep_segment_painter.dart'; // <-- 여기에 painter 따로 분리하면 좋음

class SleepChartScreen extends StatelessWidget {
  final List<SleepEntry> entries;
  final DateTime selectedDate;

  const SleepChartScreen({
    Key? key,
    required this.entries,
    required this.selectedDate,
  }) : super(key: key);

  List<SleepSegment> _convertToSegments(
    List<SleepEntry> entries,
    DateTime baseTime,
  ) {
    return entries.map((entry) {
      final start = entry.start.difference(baseTime).inMinutes.toDouble();
      final end = entry.end.difference(baseTime).inMinutes.toDouble();

      final stage =
          {
            HealthDataType.SLEEP_AWAKE: SleepStage.awake,
            HealthDataType.SLEEP_LIGHT: SleepStage.light,
            HealthDataType.SLEEP_REM: SleepStage.rem,
            HealthDataType.SLEEP_DEEP: SleepStage.deep,
          }[entry.type] ??
          SleepStage.light;

      return SleepSegment(startMinute: start, endMinute: end, stage: stage);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final d = selectedDate; // ← 선택한 날짜
    final baseTime = DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(const Duration(hours: 6));

    Duration totalSleep = Duration.zero;
    for (var e in entries) {
      totalSleep += e.duration;
    }
    final segments = _convertToSegments(entries, baseTime);

    return Scaffold(
      appBar: AppBar(title: const Text('수면 단계')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${totalSleep.inHours}시간 ${totalSleep.inMinutes % 60}분',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            /// ✅ 커스텀 페인터 적용
            SizedBox(
              height: 200,
              width: double.infinity,
              child: InteractiveViewer(
                constrained: false,
                scaleEnabled: true,
                panEnabled: true,
                minScale: 1,
                maxScale: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 그래프
                    SizedBox(
                      width: 1080, // 12시간 * 60분 = 720px
                      height: 150,
                      child: CustomPaint(
                        painter: SleepSegmentPainter(segments: segments),
                      ),
                    ),

                    // 시간 라벨 (가로축)
                    SizedBox(
                      width: 1080,
                      height: 24,
                      child: Stack(
                        children: List.generate(7, (i) {
                          final tickTime = baseTime.add(Duration(hours: i * 3));

                          final hour = (18 + i * 3) % 24;
                          final label = '${hour.toString().padLeft(2, '0')}:00';
                          final left = (i / 6.0) * 1080; // 6 구간 → 7 tick
                          return Positioned(
                            left: left - 14,
                            top: 0,
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
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
