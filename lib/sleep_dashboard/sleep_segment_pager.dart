import 'package:flutter/material.dart';
import 'sleep_segment_painter.dart';
import 'sleep_segment.dart';

class SleepSegmentPager extends StatelessWidget {
  final List<SleepSegment> segments;

  const SleepSegmentPager({Key? key, required this.segments}) : super(key: key);

  String _stageToLabel(SleepStage stage) {
    switch (stage) {
      case SleepStage.awake:
        return '깨어있음';
      case SleepStage.light:
        return '얕은 수면';
      case SleepStage.rem:
        return 'REM 수면';
      case SleepStage.deep:
        return '깊은 수면';
    }
  }

  String _formatTime(double minutes) {
    final total = minutes.toInt();
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}시간 ${m}분' : '${m}분';
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bedtime_off, size: 48, color: Colors.white30),
              const SizedBox(height: 12),
              Text(
                '수면 데이터가 없습니다',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E21),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.format_list_bulleted,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '수면 단계 상세',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: segments.length,
              itemBuilder: (context, index) {
                final segment = segments[index];
                final color = _getStageColor(segment.stage);
                final duration = segment.endMinute - segment.startMinute;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E21),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      _stageToLabel(segment.stage),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '지속 시간: ${_formatTime(duration)}',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_formatMinutesToTime(segment.startMinute)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutesToTime(double minutes) {
    final baseHour = 18;
    final totalMinutes = minutes.toInt();
    final hours = (baseHour + totalMinutes ~/ 60) % 24;
    final mins = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  Color _getStageColor(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return const Color(0xFF5E35B1);
      case SleepStage.rem:
        return const Color(0xFF29B6F6);
      case SleepStage.light:
        return const Color(0xFF42A5F5);
      case SleepStage.awake:
        return const Color(0xFFEF5350);
    }
  }
}
