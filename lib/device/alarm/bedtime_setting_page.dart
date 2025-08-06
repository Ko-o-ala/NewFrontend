import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import 'package:provider/provider.dart';
import 'package:my_app/device/alarm/bedtime_provider.dart';

class BedtimeSettingPage extends StatefulWidget {
  const BedtimeSettingPage({super.key});

  @override
  State<BedtimeSettingPage> createState() => _BedtimeSettingPageState();
}

class _BedtimeSettingPageState extends State<BedtimeSettingPage> {
  TimeOfDay bedtime = const TimeOfDay(hour: 23, minute: 45);
  TimeOfDay wakeup = const TimeOfDay(hour: 6, minute: 15);
  List<int> reminderMinutes = [5, 10, 15, 20];
  Set<int> selectedReminders = {};
  Set<String> selectedDays = {};
  bool skipHolidays = false;

  Future<void> _selectTime(BuildContext context, bool isBedtime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isBedtime ? bedtime : wakeup,
    );
    if (picked != null) {
      setState(() {
        if (isBedtime) {
          bedtime = picked;
        } else {
          wakeup = picked;
        }
      });
    }
  }

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
            onPressed: () {
              context.read<BedtimeModel>().update(
                newBedtime: bedtime,
                newWakeup: wakeup,
                newDays: selectedDays,
              );
              Navigator.pop(context);
            },
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const SizedBox(height: 12),
            _buildTimeSection('Bedtime', bedtime, true),
            const SizedBox(height: 12),
            _buildTimeSection('Wake up', wakeup, false),
            const SizedBox(height: 24),
            const Text('Reminder notification', style: TextStyle(fontWeight: FontWeight.bold)),
            ...reminderMinutes.map((min) => SwitchListTile(
              title: Text('$min minutes before'),
              value: selectedReminders.contains(min),
              onChanged: (val) => setState(() {
                val ? selectedReminders.add(min) : selectedReminders.remove(min);
              }),
            )),
            const Divider(height: 32),
            const Text('알람 요일 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                return ChoiceChip(
                  label: Text(day),
                  selected: selectedDays.contains(day),
                  selectedColor: Colors.deepPurple[100], // 선택됐을 때 색
                  onSelected: (selected) {
                    setState(() {
                      selected ? selectedDays.add(day) : selectedDays.remove(day);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('공휴일에는 알림 끄기'),
                Switch(
                  value: skipHolidays,
                  onChanged: (val) => setState(() => skipHolidays = val),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection(String title, TimeOfDay time, bool isBedtime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectTime(context, isBedtime),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              time.format(context),
              style: const TextStyle(fontSize: 20),
            ),
          ),
        )
      ],
    );
  }
}
