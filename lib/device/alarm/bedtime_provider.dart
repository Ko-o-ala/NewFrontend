import 'package:flutter/material.dart';

class BedtimeModel with ChangeNotifier {
  TimeOfDay bedtime = const TimeOfDay(hour: 23, minute: 45);
  TimeOfDay wakeup = const TimeOfDay(hour: 6, minute: 15);
  Set<String> selectedDays = {};

  void update({
    required TimeOfDay newBedtime,
    required TimeOfDay newWakeup,
    required Set<String> newDays,
  }) {
    bedtime = newBedtime;
    wakeup = newWakeup;
    selectedDays = newDays;
    notifyListeners();
  }
}
