import 'package:flutter/material.dart';

/// 수면 단계 열거형
enum SleepStage { awake, light, rem, deep }

/// 수면 구간 정보
class SleepSegment {
  final double startMinute;
  final double endMinute;
  final SleepStage stage;

  SleepSegment({
    required this.startMinute,
    required this.endMinute,
    required this.stage,
  });
}
