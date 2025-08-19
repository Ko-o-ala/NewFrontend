import 'package:flutter/material.dart';
import 'sleep_segment.dart';
import 'dart:ui' as ui;

class SleepSegmentPainter extends CustomPainter {
  final List<SleepSegment> segments;
  SleepSegmentPainter({required this.segments});

  static const double totalMinutes = 18 * 60.0; // 18시간 = 1080분

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGridLines(canvas, size);
    _drawSleepSegments(canvas, size);
    _drawStageLabels(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint =
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [
            const Color(0xFF0A0E21).withOpacity(0.5),
            const Color(0xFF1D1E33).withOpacity(0.3),
          ]);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..strokeWidth = 1;

    for (int i = 0; i <= 6; i++) {
      final x = (i / 6) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (int i = 0; i < 4; i++) {
      final y = _yForStage(SleepStage.values[i], size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawSleepSegments(Canvas canvas, Size size) {
    for (final segment in segments) {
      final startMin = segment.startMinute.clamp(0, totalMinutes);
      final endMin = segment.endMinute.clamp(0, totalMinutes);
      if (endMin <= 0 || startMin >= totalMinutes || endMin <= startMin) {
        continue;
      }

      final startX = (startMin / totalMinutes) * size.width;
      final endX = (endMin / totalMinutes) * size.width;
      final y = _yForStage(segment.stage, size.height);

      _drawSegmentWithGlow(canvas, startX, endX, y, segment.stage);
    }
  }

  void _drawSegmentWithGlow(
    Canvas canvas,
    double startX,
    double endX,
    double y,
    SleepStage stage,
  ) {
    final color = _colorForStage(stage);

    final glowPaint =
        Paint()
          ..color = color.withOpacity(0.3)
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawLine(Offset(startX, y), Offset(endX, y), glowPaint);

    final segmentPaint =
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(startX, y - 5),
            Offset(startX, y + 5),
            [color.withOpacity(0.9), color, color.withOpacity(0.9)],
          )
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(startX, y), Offset(endX, y), segmentPaint);

    final capRadius = 5.0;
    final capPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(startX, y), capRadius, capPaint);
    canvas.drawCircle(Offset(endX, y), capRadius, capPaint);
  }

  void _drawStageLabels(Canvas canvas, Size size) {
    final stages = [
      {'stage': SleepStage.deep, 'label': '깊은'},
      {'stage': SleepStage.rem, 'label': 'REM'},
      {'stage': SleepStage.light, 'label': '얕은'},
      {'stage': SleepStage.awake, 'label': '깨어있음'},
    ];

    for (final item in stages) {
      final stage = item['stage'] as SleepStage;
      final label = item['label'] as String;
      final y = _yForStage(stage, size.height);
      final color = _colorForStage(stage);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width - 8, y - textPainter.height / 2),
      );
    }
  }

  double _yForStage(SleepStage stage, double h) {
    switch (stage) {
      case SleepStage.deep:
        return h * 0.20;
      case SleepStage.rem:
        return h * 0.40;
      case SleepStage.light:
        return h * 0.60;
      case SleepStage.awake:
        return h * 0.80;
    }
  }

  Color _colorForStage(SleepStage stage) {
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

  @override
  bool shouldRepaint(covariant SleepSegmentPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
