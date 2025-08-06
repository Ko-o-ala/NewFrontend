import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:health/health.dart';
import 'sleep_entry.dart';

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
    print('🛠️ SleepChartScreen build 실행됨');
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
            Text(
              DateFormat('yyyy년 M월 d일').format(selectedDate),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              width: double.infinity,
              child:
                  entries.isEmpty
                      ? const Center(child: Text('수면 데이터가 없습니다.'))
                      : CustomPaint(
                        painter: SleepGraphPainter(entries, baseTime),
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

class SleepGraphPainter extends CustomPainter {
  final List<SleepEntry> entries;
  final DateTime baseTime;

  SleepGraphPainter(this.entries, this.baseTime);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final totalMinutes = 18 * 60;
    print('🖼️ 그래프 그리는 중, entry 개수: ${entries.length}');

    for (var entry in entries) {
      print('${entry.readableType}: ${entry.start} ~ ${entry.end}');
      final startMin = entry.start
          .difference(baseTime)
          .inMinutes
          .clamp(0, totalMinutes);
      final endMin = entry.end
          .difference(baseTime)
          .inMinutes
          .clamp(0, totalMinutes);
      var xStart = size.width * (startMin / totalMinutes);
      var xEnd = size.width * (endMin / totalMinutes);

      // 너무 좁은 바는 일정 너비로 보정
      if ((xEnd - xStart).abs() < 2.0) {
        xEnd = xStart + 2.0;
      }
      final y = _getY(entry.type, size.height);

      paint.color = _getColor(entry.type);

      canvas.drawRect(Rect.fromLTRB(xStart, y - 10, xEnd, y + 10), paint);
      print('▶️ ${entry.readableType}: xStart=$xStart, xEnd=$xEnd');
    }
  }

  double _getY(HealthDataType type, double height) {
    switch (type) {
      case HealthDataType.SLEEP_AWAKE:
        return height * 0.2;
      case HealthDataType.SLEEP_REM:
        return height * 0.4;
      case HealthDataType.SLEEP_LIGHT:
        return height * 0.6;
      case HealthDataType.SLEEP_DEEP:
        return height * 0.8;
      default:
        return height * 0.5;
    }
  }

  Color _getColor(HealthDataType type) {
    switch (type) {
      case HealthDataType.SLEEP_AWAKE:
        return Colors.redAccent;
      case HealthDataType.SLEEP_REM:
        return Colors.lightBlue;
      case HealthDataType.SLEEP_LIGHT:
        return Colors.blue;
      case HealthDataType.SLEEP_DEEP:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
