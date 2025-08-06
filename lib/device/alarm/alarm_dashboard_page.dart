import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'alarm_provider.dart';
import 'AddAlarmPage.dart';
import 'bedtime_setting_page.dart';
import 'bedtime_provider.dart';

class AlarmDashboardPage extends StatelessWidget {
  const AlarmDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alarms = context.watch<AlarmProvider>().alarms;
    final bedtimeData = context.watch<BedtimeModel>();

    final formattedBedtime = bedtimeData.bedtime.format(context);
    final formattedWakeup = bedtimeData.wakeup.format(context);
    final selectedDays = bedtimeData.selectedDays.join(', ');
    final bedtimeDuration = Duration(
      hours: bedtimeData.wakeup.hour - bedtimeData.bedtime.hour,
      minutes: bedtimeData.wakeup.minute - bedtimeData.bedtime.minute,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FC),
      appBar: AppBar(
        title: const Text('알람 대시보드'),
        backgroundColor: const Color(0xFFF6F7FC),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text("Bedtime", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const Text(" On track", style: TextStyle(color: Colors.green)),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
                Text('$formattedBedtime ~ $formattedWakeup',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${bedtimeDuration.inHours.abs().toString().padLeft(2, '0')} hrs '
                      '${(bedtimeDuration.inMinutes.abs() % 60).toString().padLeft(2, '0')} min',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BedtimeSettingPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text("Set bedtime"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Text("Alarm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),
          ...alarms.map((alarm) => Dismissible(
            key: Key('${alarm.hashCode}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('정말 삭제하시겠습니까?'),
                  content: const Text('이 알람은 복구할 수 없습니다.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('삭제')),
                  ],
                ),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) {
              context.read<AlarmProvider>().deleteAlarm(alarm);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                          final isSelected = alarm.repeatDays.contains(day);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Text(
                              day,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.grey,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Switch(
                    value: alarm.isEnabled,
                    onChanged: (_) {
                      context.read<AlarmProvider>().toggleAlarm(alarm);
                    },
                    activeColor: Colors.deepPurple,
                  )

                ],
              ),
            ),
          )),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 36),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAlarmPage()),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
