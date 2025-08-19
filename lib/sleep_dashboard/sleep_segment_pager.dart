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
        return '코어 수면';
      case SleepStage.rem:
        return 'REM 수면';
      case SleepStage.deep:
        return '깊은 수면';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          segments.map((s) {
            final color =
                {
                  SleepStage.awake: Colors.redAccent,
                  SleepStage.light: Colors.blue,
                  SleepStage.rem: Colors.lightBlue,
                  SleepStage.deep: Colors.indigo,
                }[s.stage]!;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_stageToLabel(s.stage)}: ${s.startMinute.toInt()}분 ~ ${s.endMinute.toInt()}분',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}
