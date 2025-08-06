import 'package:flutter/material.dart';

class HumidifierControlPage extends StatefulWidget {
  const HumidifierControlPage({super.key});

  @override
  State<HumidifierControlPage> createState() => _HumidifierControlPageState();
}

class _HumidifierControlPageState extends State<HumidifierControlPage> {
  bool aiControl = true;
  bool smartTimer = true;
  bool autoAdjust = true;
  bool lowWaterAlert = true;

  final int humidity = 40; // 임시값 (나중에 서버/기기 연동 시 업데이트)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("기기 제어")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[100],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSwitchTile(
                title: "AI 스마트 가습기",
                subtitle: "현재 습도에 따라 자동으로 작동하며 쾌적한 실내 환경을 유지해줘요.",
                value: aiControl,
                onChanged: (val) => setState(() => aiControl = val),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 8, bottom: 20),
                child: Row(
                  children: [
                    const Text("현재 습도  ", style: TextStyle(fontSize: 16)),
                    Text("$humidity%", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildSwitchTile(
                title: "스마트 타이머",
                subtitle: "설정한 시간 후 자동으로 가습기가 꺼지거나 켜지도록 예약할 수 있어요.",
                value: smartTimer,
                onChanged: (val) => setState(() => smartTimer = val),
              ),
              _buildSwitchTile(
                title: "자동 조절",
                subtitle: "실내 습도를 감지해 자동으로 가습 세기를 조절해줘요.",
                value: autoAdjust,
                onChanged: (val) => setState(() => autoAdjust = val),
              ),
              _buildSwitchTile(
                title: "수분 부족 알림",
                subtitle: "물이 부족하면 알림을 보내줘서 제때 보충할 수 있어요.",
                value: lowWaterAlert,
                onChanged: (val) => setState(() => lowWaterAlert = val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
