import 'package:flutter/material.dart';
import 'weekday_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // ✅ jsonEncode / jsonDecode 제공

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

  @override
  void initState() {
    super.initState();
    _loadPreviousSettings(); // ✅ 이전 설정 불러오기
  }

  Future<void> _loadPreviousSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 🔁 취침/기상 시간 불러오기
    final bedHour = prefs.getInt('bedHour');
    final bedMin = prefs.getInt('bedMin');
    final wakeHour = prefs.getInt('wakeHour');
    final wakeMin = prefs.getInt('wakeMin');

    // 🔁 선택한 요일들 불러오기 (기본값: 빈 Set)
    final selectedList = prefs.getStringList('selectedDays');
    final daySet =
        selectedList?.map(int.parse).toSet() ?? <int>{}; // 저장된 것이 없으면 빈 Set

    setState(() {
      if (bedHour != null && bedMin != null) {
        bedTime = TimeOfDay(hour: bedHour, minute: bedMin);
      }
      if (wakeHour != null && wakeMin != null) {
        wakeTime = TimeOfDay(hour: wakeHour, minute: wakeMin);
      }
      selectedDays = daySet;
    });
  }

  Future<void> _saveSleepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final duration = calculateSleepDuration();

    // 모든 요일 목표 시간 초기화
    for (int i = 1; i <= 7; i++) {
      await prefs.remove('sleep_goal_weekday_$i');
      await prefs.remove('sleep_goal_enabled_$i');
    }

    // 선택 요일(0=일~6=토) → 1=월~7=일로 변환
    final selectedWeekdays =
        selectedDays.map((day) => day == 0 ? 7 : day).toSet();

    // 선택된 요일에만 목표 시간 저장
    if (duration != null) {
      for (final wd in selectedWeekdays) {
        await prefs.setInt('sleep_goal_weekday_$wd', duration.inMinutes);
      }
    }

    // ✅ 활성 요일 키도 함께 저장 (A/B 둘 다 지원)
    await prefs.setString(
      'sleep_goal_enabled_days',
      jsonEncode(selectedWeekdays.toList()),
    );
    for (int i = 1; i <= 7; i++) {
      await prefs.setBool(
        'sleep_goal_enabled_$i',
        selectedWeekdays.contains(i),
      );
    }

    // 취침/기상 시각 저장
    if (bedTime != null && wakeTime != null) {
      await prefs.setInt('bedHour', bedTime!.hour);
      await prefs.setInt('bedMin', bedTime!.minute);
      await prefs.setInt('wakeHour', wakeTime!.hour);
      await prefs.setInt('wakeMin', wakeTime!.minute);
    }

    // 선택한 요일(원본 0~6)도 계속 보존
    await prefs.setStringList(
      'selectedDays',
      selectedDays.map((e) => e.toString()).toList(),
    );
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
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '목표 수면 시간 수정',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D1E33), Color(0xFF0A0E21)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 헤더 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.bedtime,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '목표 수면 시간',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '건강한 수면을 위한 목표를 설정하세요',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 모드 선택 토글
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.swap_horiz,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '수면 모드 선택',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E21),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap:
                                      () =>
                                          setState(() => isWakeUpMode = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isWakeUpMode
                                              ? Colors.transparent
                                              : const Color(0xFF6C63FF),
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                            left: Radius.circular(30),
                                          ),
                                      boxShadow:
                                          isWakeUpMode
                                              ? null
                                              : [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF6C63FF,
                                                  ).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                    ),
                                    child: Text(
                                      '목표 취침 시간',
                                      style: TextStyle(
                                        color:
                                            isWakeUpMode
                                                ? Colors.white70
                                                : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap:
                                      () => setState(() => isWakeUpMode = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isWakeUpMode
                                              ? const Color(0xFF6C63FF)
                                              : Colors.transparent,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                            right: Radius.circular(30),
                                          ),
                                      boxShadow:
                                          isWakeUpMode
                                              ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF6C63FF,
                                                  ).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                              : null,
                                    ),
                                    child: Text(
                                      '목표 기상 시간',
                                      style: TextStyle(
                                        color:
                                            isWakeUpMode
                                                ? Colors.white
                                                : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 현재 수면시간 표시 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            sleepDuration != null && sleepDuration.inHours >= 7
                                ? [
                                  const Color(0xFF6C63FF),
                                  const Color(0xFF4B47BD),
                                ] // 충분한 수면 (7시간 이상)
                                : sleepDuration != null &&
                                    sleepDuration.inHours >= 6
                                ? [
                                  const Color(0xFFFF9800),
                                  const Color(0xFFE65100),
                                ] // 보통 수면 (6-7시간)
                                : [
                                  const Color(0xFF2C2C72),
                                  const Color(0xFF1F1F4C),
                                ], // 부족한 수면 (6시간 미만)
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (sleepDuration != null &&
                                      sleepDuration.inHours >= 7
                                  ? const Color(0xFF6C63FF)
                                  : sleepDuration != null &&
                                      sleepDuration.inHours >= 6
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF2C2C72))
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                sleepDuration != null &&
                                        sleepDuration.inHours >= 7
                                    ? Icons
                                        .check_circle_outline // 충분한 수면
                                    : sleepDuration != null &&
                                        sleepDuration.inHours >= 6
                                    ? Icons
                                        .warning_amber_outlined // 보통 수면
                                    : Icons.info_outline, // 부족한 수면
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '현재 설정된 수면시간',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    durationText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  if (bedTime != null && wakeTime != null) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.bedtime,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '취침 ${formatTime(bedTime!)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.wb_sunny,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '기상 ${formatTime(wakeTime!)}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isWakeUpMode && sleepDuration != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      sleepDuration.inHours >= 7
                                          ? Icons.thumb_up
                                          : sleepDuration.inHours >= 6
                                          ? Icons.thumbs_up_down
                                          : Icons.thumb_down,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      sleepDuration.inHours >= 7
                                          ? '충분한 수면시간입니다!'
                                          : sleepDuration.inHours >= 6
                                          ? '적당한 수면시간입니다'
                                          : '수면시간이 부족합니다',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        sleepDuration.inHours >= 7
                                            ? const Color(
                                              0xFF6C63FF,
                                            ).withOpacity(0.3)
                                            : sleepDuration.inHours >= 6
                                            ? Colors.orange.withOpacity(0.3)
                                            : Colors.red.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    sleepDuration.inHours >= 7
                                        ? '좋음'
                                        : sleepDuration.inHours >= 6
                                        ? '보통'
                                        : '부족',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 시간 선택 필드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.access_time,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '시간 선택',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => _selectTime(context),
                          child: AbsorbPointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0E21),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: TextEditingController(
                                  text:
                                      (isWakeUpMode ? wakeTime : bedTime)
                                          ?.format(context) ??
                                      '',
                                ),
                                readOnly: true,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: '시간을 선택해주세요',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  suffixIcon: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF6C63FF,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF6C63FF),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 요일 선택 섹션
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '요일 선택',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '목표를 달성하고 싶은 요일을 알려주세요',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 저장 버튼
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed:
                          (bedTime != null && wakeTime != null)
                              ? () async {
                                await _saveSleepGoal();
                                final sleepDuration = calculateSleepDuration();
                                Navigator.pop(context, sleepDuration);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '저장하기',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
