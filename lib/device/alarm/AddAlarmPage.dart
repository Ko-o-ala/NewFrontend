import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:my_app/device/alarm/alarm_model.dart'; // AlarmModel 경로 확인
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'alarm_provider.dart';

class AddAlarmPage extends StatefulWidget {
  const AddAlarmPage({super.key});

  @override
  State<AddAlarmPage> createState() => _AddAlarmPageState();
}

class _AddAlarmPageState extends State<AddAlarmPage> {
  TimeOfDay selectedTime = const TimeOfDay(hour: 6, minute: 0);
  Set<String> selectedDays = {'M', 'T', 'W', 'T', 'F'}; // 기본 평일 선택
  bool skipHolidays = false;
  bool alarmSound = true;
  bool vibration = true;
  bool snooze = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveAlarm,
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _pickTime,
                child: Text(
                  selectedTime.format(context),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _formattedDate(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                return ChoiceChip(
                  label: Text(day),
                  selected: selectedDays.contains(day),
                  onSelected: (selected) {
                    setState(() {
                      selected
                          ? selectedDays.add(day)
                          : selectedDays.remove(day);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('공휴일에는 알람 끄기'),
                Switch(
                  value: skipHolidays,
                  onChanged: (val) => setState(() => skipHolidays = val),
                )
              ],
            ),
            const Divider(height: 24),
            _buildSwitchTile('Alarm sound', 'Homecoming', alarmSound,
                    (val) => setState(() => alarmSound = val)),
            _buildSwitchTile('Vibration', 'Basic call', vibration,
                    (val) => setState(() => vibration = val)),
            _buildSwitchTile(
                'Snooze', '5 minutes, 3 times', snooze, (val) => setState(() => snooze = val)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final day = DateFormat.EEEE().format(tomorrow);
    final date = DateFormat('d MMM').format(tomorrow);
    return "Tomorrow - $day, $date";
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  void _saveAlarm() {
    final alarm = AlarmModel(
      hour: selectedTime.hour,
      minute: selectedTime.minute,
      repeatDays: selectedDays.toList(),
      alarmSound: alarmSound,
      vibration: vibration,
      snooze: snooze,
    );

    // ✅ 기존 Hive 직접 저장 ❌ → Provider를 통해 저장 ⭕

    context.read<AlarmProvider>().addAlarm(alarm);
    Navigator.pop(context);
  }
}
