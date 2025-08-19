import 'package:flutter/material.dart';
import 'sleep_entry.dart';
import 'package:health/health.dart';
import 'sleep_segment.dart';
import 'sleep_segment_painter.dart';

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
    final d = selectedDate;
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
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '수면 분석',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(d),
              const SizedBox(height: 20),
              _buildSleepSummaryCard(totalSleep),
              const SizedBox(height: 24),

              _buildChartCard(segments, baseTime),
              const SizedBox(height: 24),
              _buildStageBreakdown(entries),
              const SizedBox(height: 24),
              _buildSleepQualityIndicators(entries),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekday = weekdays[date.weekday % 7];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepSummaryCard(Duration totalSleep) {
    final hours = totalSleep.inHours;
    final minutes = totalSleep.inMinutes % 60;
    final quality = _calculateSleepQuality(totalSleep);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF),
            const Color(0xFF4B47BD),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                '총 수면 시간',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$hours',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                '시간 ',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              Text(
                '$minutes',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                '분',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              quality,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<SleepSegment> segments, DateTime baseTime) {
    return Container(
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
          Row(
            children: [
              Icon(Icons.timeline, color: Colors.white70, size: 24),
              const SizedBox(width: 8),
              const Text(
                '수면 단계 타임라인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E21),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                constrained: false,
                scaleEnabled: true,
                panEnabled: true,
                minScale: 1,
                maxScale: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 1080,
                        height: 140,
                        child: CustomPaint(
                          painter: SleepSegmentPainter(segments: segments),
                        ),
                      ),
                      SizedBox(
                        width: 1080,
                        height: 28,
                        child: Stack(
                          children: List.generate(7, (i) {
                            final hour = (18 + i * 3) % 24;
                            final label = '${hour.toString().padLeft(2, '0')}:00';
                            final left = (i / 6.0) * 1080;
                            return Positioned(
                              left: left - 20,
                              top: 0,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final stages = [
      {'name': '깊은 수면', 'color': const Color(0xFF5E35B1)},
      {'name': 'REM 수면', 'color': const Color(0xFF29B6F6)},
      {'name': '얕은 수면', 'color': const Color(0xFF42A5F5)},
      {'name': '깨어있음', 'color': const Color(0xFFEF5350)},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: stages.map((stage) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: stage['color'] as Color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              stage['name'] as String,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStageBreakdown(List<SleepEntry> entries) {
    final Map<String, Duration> summary = {};
    for (var e in entries) {
      final key = e.readableType;
      summary[key] = (summary[key] ?? Duration.zero) + e.duration;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.white70, size: 24),
              const SizedBox(width: 8),
              const Text(
                '수면 단계별 분석',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...summary.entries.map((e) => _buildStageRow(e.key, e.value, summary)),
        ],
      ),
    );
  }

  Widget _buildStageRow(String stage, Duration duration, Map<String, Duration> total) {
    final totalDuration = total.values.fold<Duration>(
      Duration.zero,
      (prev, element) => prev + element,
    );
    final percentage = totalDuration.inMinutes > 0
        ? (duration.inMinutes / totalDuration.inMinutes * 100).round()
        : 0;

    final color = _getStageColor(stage);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${duration.inHours}시간 ${duration.inMinutes % 60}분',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildSleepQualityIndicators(List<SleepEntry> entries) {
    final deepSleep = entries
        .where((e) => e.type == HealthDataType.SLEEP_DEEP)
        .fold<Duration>(Duration.zero, (sum, e) => sum + e.duration);
    
    final remSleep = entries
        .where((e) => e.type == HealthDataType.SLEEP_REM)
        .fold<Duration>(Duration.zero, (sum, e) => sum + e.duration);
    
    final awakeTime = entries
        .where((e) => e.type == HealthDataType.SLEEP_AWAKE)
        .fold<Duration>(Duration.zero, (sum, e) => sum + e.duration);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.white70, size: 24),
              const SizedBox(width: 8),
              const Text(
                '수면 품질 지표',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildQualityIndicator(
            '깊은 수면',
            '${deepSleep.inHours}시간 ${deepSleep.inMinutes % 60}분',
            deepSleep.inMinutes > 90 ? '좋음' : '개선 필요',
            deepSleep.inMinutes > 90 ? Colors.green : Colors.orange,
            Icons.nights_stay,
          ),
          const SizedBox(height: 12),
          _buildQualityIndicator(
            'REM 수면',
            '${remSleep.inHours}시간 ${remSleep.inMinutes % 60}분',
            remSleep.inMinutes > 60 ? '적절함' : '부족',
            remSleep.inMinutes > 60 ? Colors.blue : Colors.orange,
            Icons.psychology,
          ),
          const SizedBox(height: 12),
          _buildQualityIndicator(
            '수면 중 깨어있던 시간',
            '${awakeTime.inMinutes}분',
            awakeTime.inMinutes < 30 ? '양호' : '많음',
            awakeTime.inMinutes < 30 ? Colors.green : Colors.red,
            Icons.visibility,
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(
    String title,
    String value,
    String status,
    Color statusColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateSleepQuality(Duration totalSleep) {
    final hours = totalSleep.inHours;
    if (hours >= 7 && hours <= 9) {
      return '💯 최적의 수면';
    } else if (hours >= 6 && hours < 7) {
      return '😊 양호한 수면';
    } else if (hours >= 5 && hours < 6) {
      return '😐 부족한 수면';
    } else if (hours > 9) {
      return '😴 과다한 수면';
    } else {
      return '😟 매우 부족한 수면';
    }
  }

  Color _getStageColor(String type) {
    return {
      '깨어있음': const Color(0xFFEF5350),
      'REM 수면': const Color(0xFF29B6F6),
      '코어 수면': const Color(0xFF42A5F5),
      '깊은 수면': const Color(0xFF5E35B1),
      '수면': const Color(0xFF66BB6A),
    }[type] ?? Colors.grey;
  }
}
