// lib/sleep_dashboard/sleep_segment_painter.dart
import 'package:flutter/material.dart';
import 'sleep_segment.dart';

class SleepSegmentPainter extends CustomPainter {
  final List<SleepSegment> segments;
  SleepSegmentPainter({required this.segments});

  static const double totalMinutes = 18 * 60.0; // 18시간 = 1080분

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round;

    // 필요하면 가이드 그리드(디버그용)
    // _drawGrid(canvas, size);

    for (final s in segments) {
      // 0~1080 범위로 클램프
      final startMin = s.startMinute.clamp(0, totalMinutes);
      final endMin = s.endMinute.clamp(0, totalMinutes);
      if (endMin <= 0 || startMin >= totalMinutes || endMin <= startMin) {
        continue; // 화면 밖이거나 길이 0이면 스킵
      }

      final startX = (startMin / totalMinutes) * size.width;
      final endX = (endMin / totalMinutes) * size.width;
      final y = _yForStage(s.stage, size.height);

      paint.color = _colorForStage(s.stage);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  double _yForStage(SleepStage stage, double h) {
    // 위에서 아래로 간격 균일 (원하면 수치 미세조정)
    switch (stage) {
      case SleepStage.deep:
        return h * 0.20;
      case SleepStage.rem:
        return h * 0.45;
      case SleepStage.light:
        return h * 0.70;
      case SleepStage.awake:
        return h * 0.90;
    }
  }

  Color _colorForStage(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return Colors.indigo;
      case SleepStage.rem:
        return Colors.lightBlue;
      case SleepStage.light:
        return Colors.blue;
      case SleepStage.awake:
        return Colors.redAccent;
    }
  }

  // 디버그용 가이드 (원하면 주석 해제)
  // void _drawGrid(Canvas canvas, Size size) {
  //   final p = Paint()
  //     ..color = Colors.grey.withOpacity(0.2)
  //     ..strokeWidth = 1;
  //   for (int i = 0; i <= 6; i++) {
  //     final dx = size.width * (i / 6);
  //     canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), p);
  //   }
  //   for (int i = 0; i <= 4; i++) {
  //     final dy = size.height * (i / 4);
  //     canvas.drawLine(Offset(0, dy), Offset(size.width, dy), p);
  //   }
  // }

  @override
  bool shouldRepaint(covariant SleepSegmentPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
