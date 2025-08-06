import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'alarm_model.dart';

class AlarmProvider with ChangeNotifier {
  final List<AlarmModel> _alarms = [];

  List<AlarmModel> get alarms => _alarms;

  AlarmProvider() {
    loadAlarms(); // 앱 시작 시 알람 로딩
  }

  Future<void> loadAlarms() async {
    final box = await Hive.openBox<AlarmModel>('alarms');
    _alarms.clear();
    _alarms.addAll(box.values);
    notifyListeners();
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    final box = Hive.box<AlarmModel>('alarms');
    await box.add(alarm);
    _alarms.add(alarm);
    notifyListeners();
  }

  Future<void> deleteAlarm(AlarmModel alarm) async {
    final box = Hive.box<AlarmModel>('alarms');
    final key = box.keys.firstWhere(
          (k) => box.get(k) == alarm,
      orElse: () => null,
    );
    if (key != null) {
      await box.delete(key);
      _alarms.remove(alarm);
      notifyListeners();
    }
  }

  Future<void> toggleAlarm(AlarmModel alarm) async {
    final index = _alarms.indexOf(alarm);
    if (index != -1) {
      _alarms[index].isEnabled = !_alarms[index].isEnabled;

      final box = Hive.box<AlarmModel>('alarms');
      final key = box.keys.firstWhere(
            (k) => box.get(k) == alarm,
        orElse: () => null,
      );
      if (key != null) {
        await box.put(key, _alarms[index]); // Hive에서도 상태 업데이트
      }
      notifyListeners();
    }
  }
}
