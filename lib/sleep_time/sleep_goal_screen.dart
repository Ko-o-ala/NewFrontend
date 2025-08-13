import 'package:flutter/material.dart';
import 'weekday_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SleepGoalScreen extends StatefulWidget {
  @override
  State<SleepGoalScreen> createState() => _SleepGoalScreenState();
}

class _SleepGoalScreenState extends State<SleepGoalScreen> {
  bool isWakeUpMode = false;
  TimeOfDay? bedTime;
  TimeOfDay? wakeTime;
  Set<int> selectedDays = {};

  String formatTime(TimeOfDay time) {
    return '${time.hour}시 ${time.minute}분';
  }

  Future<void> _saveSleepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final duration = calculateSleepDuration();

    if (duration != null) {
      for (final day in selectedDays) {
        // day: 0(Sunday) ~ 6(Saturday)
        prefs.setInt('sleepGoal_$day', duration.inMinutes);
      }
    }
  }

  Duration? calculateSleepDuration() {
    if (bedTime == null || wakeTime == null) return null;
    final bed = Duration(hours: bedTime!.hour, minutes: bedTime!.minute);
    final wake = Duration(hours: wakeTime!.hour, minutes: wakeTime!.minute);
    return wake >= bed ? wake - bed : Duration(hours: 24) - bed + wake;
  }

  void _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          isWakeUpMode
              ? (wakeTime ?? TimeOfDay.now())
              : (bedTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isWakeUpMode) {
          wakeTime = picked;
        } else {
          bedTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sleepDuration = calculateSleepDuration();
    final durationText =
        sleepDuration != null
            ? '${sleepDuration.inHours}시간 ${sleepDuration.inMinutes % 60}분'
            : '0시간 0분';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('목표 수면 시간 수정', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 예쁜 토글
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => isWakeUpMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isWakeUpMode
                                    ? Colors.grey.shade200
                                    : const Color(0xFFB0AEF4),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Go to bed at',
                            style: TextStyle(
                              color: isWakeUpMode ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => isWakeUpMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isWakeUpMode
                                    ? const Color(0xFFB0AEF4)
                                    : Colors.grey.shade200,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Wake up at',
                            style: TextStyle(
                              color: isWakeUpMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 배너
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF08063D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isWakeUpMode
                      ? '$durationText 수면을 취하실 수 있습니다'
                      : '오늘 주무실 시간을 선택해주세요',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 15),

              // 시간 선택 필드
              GestureDetector(
                onTap: () => _selectTime(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: TextEditingController(
                      text:
                          (isWakeUpMode ? wakeTime : bedTime)?.format(
                            context,
                          ) ??
                          '',
                    ),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: '시간 선택',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Center(
                // ✅ 텍스트도 가운데 정렬
                child: Text(
                  '목표를 달성하고 싶은 요일을 알려주세요',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 16),
              WeekdaySelector(
                selectedDays: selectedDays,
                onDayToggle: (index) {
                  setState(() {
                    if (selectedDays.contains(index)) {
                      selectedDays.remove(index);
                    } else {
                      selectedDays.add(index);
                    }
                  });
                },
              ),

              const SizedBox(height: 40),

              // 저장 버튼
              ElevatedButton(
                onPressed:
                    (bedTime != null && wakeTime != null)
                        ? () async {
                          await _saveSleepGoal();
                          final sleepDuration = calculateSleepDuration();
                          Navigator.pop(context, sleepDuration);
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB0AEF4),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  '저장하기',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // ✅ 글자색을 검정으로 설정
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
