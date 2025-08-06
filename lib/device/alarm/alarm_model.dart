import 'package:hive/hive.dart';

part 'alarm_model.g.dart'; // 어댑터 자동 생성용

@HiveType(typeId: 0)
class AlarmModel extends HiveObject {
  @HiveField(0)
  final int hour;

  @HiveField(1)
  final int minute;

  @HiveField(2)
  final List<String> repeatDays;

  @HiveField(3)
  final bool alarmSound;

  @HiveField(4)
  final bool vibration;

  @HiveField(5)
  final bool snooze;

  @HiveField(6)
  bool isEnabled; // ❗ final 제거

  AlarmModel({
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.alarmSound,
    required this.vibration,
    required this.snooze,
    this.isEnabled = true, // ✅ 기본값 설정
  });
}
