import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
// import 'package:http/http.dart' as http; // 나중에 서버 연동 시 사용

class SleepRoutineSetupPage extends StatefulWidget {
  const SleepRoutineSetupPage({super.key});

  @override
  State<SleepRoutineSetupPage> createState() => _SleepRoutineSetupPageState();
}

class _SleepRoutineSetupPageState extends State<SleepRoutineSetupPage> {
  TimeOfDay selectedTime = const TimeOfDay(hour: 23, minute: 30);
  final List<String> selectedDays = [];
  final List<String> days = ['일', '월', '화', '수', '목', '금', '토'];

  void _toggleDay(String day) {
    setState(() {
      selectedDays.contains(day)
          ? selectedDays.remove(day)
          : selectedDays.add(day);
    });
  }

  Future<void> sendRoutineData(String time, List<String> days) async {
    final data = {
      'sleepTime': time,
      'routineDays': days,
    };
    print("서버에 보낼 데이터: ${jsonEncode(data)}");

    // 나중에 서버 연결 시 아래 주석 해제
    // final url = Uri.parse('https://your-server.com/api/sleep-routine');
    // final response = await http.post(
    //   url,
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode(data),
    // );
    // if (response.statusCode == 200) {
    //   print('전송 성공');
    // } else {
    //   print('전송 실패: ${response.statusCode}');
    // }
  }

  void _submit() async {
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요일을 한 개 이상 선택해주세요.')),
      );
      return;
    }

    final sleepTime = selectedTime.format(context);
    await sendRoutineData(sleepTime, selectedDays);

    Navigator.pushNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("당신의 수면 시간을 알려주세요",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("입력해주신 시간에 맞춰\n편안한 수면 사운드를 추천드릴게요.",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  height: 180,
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(
                      hours: selectedTime.hour,
                      minutes: selectedTime.minute,
                    ),
                    onTimerDurationChanged: (Duration newDuration) {
                      setState(() {
                        selectedTime = TimeOfDay(
                          hour: newDuration.inHours,
                          minute: newDuration.inMinutes % 60,
                        );
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text("어떤 요일에\n수면 루틴을 적용할까요?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("일주일 중 어느 날에 수면 사운드를 듣고 싶으신가요?",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: days.map((day) {
                  final selected = selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () => _toggleDay(day),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Text(
                        day,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text("편안한 밤 시작하기"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
