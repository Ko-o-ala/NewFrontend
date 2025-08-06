import 'package:flutter/material.dart';

class LightControlPage extends StatefulWidget {
  const LightControlPage({super.key});

  @override
  State<LightControlPage> createState() => _LightControlPageState();
}

class _LightControlPageState extends State<LightControlPage> {
  double brightness = 60;
  String colorTemperature = '따뜻한';
  bool autoDimEnabled = true;
  bool alarmSyncEnabled = false;
  bool timerEnabled = false;
  int timerMinutes = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('조명 설정')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              '조명 색 온도',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ToggleButtons(
              isSelected: [colorTemperature == '따뜻한', colorTemperature == '중간', colorTemperature == '차가운'],
              onPressed: (index) {
                setState(() {
                  colorTemperature = ['따뜻한', '중간', '차가운'][index];
                });
              },
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('따뜻한')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('중간')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('차가운')),
              ],
            ),
            const SizedBox(height: 24),
            const Text('밝기 조절'),
            Slider(
              value: brightness,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${brightness.toInt()}%',
              onChanged: (value) {
                setState(() => brightness = value);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('자동 조도 전환'),
              subtitle: const Text('밤 10시에 자동으로 어두워짐'),
              value: autoDimEnabled,
              onChanged: (value) => setState(() => autoDimEnabled = value),
            ),
            SwitchListTile(
              title: const Text('알람과 함께 켜짐'),
              subtitle: const Text('알람 시간에 맞춰 조명이 점점 밝아짐'),
              value: alarmSyncEnabled,
              onChanged: (value) => setState(() => alarmSyncEnabled = value),
            ),
            SwitchListTile(
              title: const Text('타이머 종료'),
              subtitle: Text('$timerMinutes분 후 조명 끄기'),
              value: timerEnabled,
              onChanged: (value) => setState(() => timerEnabled = value),
            ),
            if (timerEnabled)
              Slider(
                value: timerMinutes.toDouble(),
                min: 10,
                max: 60,
                divisions: 5,
                label: '$timerMinutes분',
                onChanged: (value) {
                  setState(() => timerMinutes = value.toInt());
                },
              ),
          ],
        ),
      ),
    );
  }
}
