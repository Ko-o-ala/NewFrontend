import 'package:flutter/material.dart';
import 'sleep_entry.dart';

class SleepEntryScreen extends StatelessWidget {
  final SleepEntry entry;

  const SleepEntryScreen({Key? key, required this.entry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duration = entry.duration;
    final readableType = entry.readableType;

    return Scaffold(
      appBar: AppBar(title: const Text('수면 기록 상세')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('유형: $readableType', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Text('시작 시간: ${entry.start}'),
            Text('종료 시간: ${entry.end}'),
            Text('총 수면 시간: ${duration.inHours}시간 ${duration.inMinutes % 60}분'),
          ],
        ),
      ),
    );
  }
}
