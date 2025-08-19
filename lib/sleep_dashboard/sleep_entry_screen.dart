import 'package:flutter/material.dart';
import 'sleep_entry.dart';
import 'package:intl/intl.dart';

class SleepEntryScreen extends StatelessWidget {
  final SleepEntry entry;

  const SleepEntryScreen({Key? key, required this.entry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final duration = entry.duration;
    final readableType = entry.readableType;
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MM월 dd일');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '수면 기록 상세',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTypeCard(readableType),
            const SizedBox(height: 20),
            _buildTimeInfoCard(
              title: '수면 시간',
              icon: Icons.schedule,
              content: Column(
                children: [
                  _buildTimeRow('시작', entry.start, timeFormat, dateFormat),
                  const Divider(color: Colors.white12, height: 24),
                  _buildTimeRow('종료', entry.end, timeFormat, dateFormat),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildDurationCard(duration),
            const SizedBox(height: 20),
            _buildInsightsCard(readableType, duration),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(String type) {
    final color = _getTypeColor(type);
    final icon = _getTypeIcon(type);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '수면 단계',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfoCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildTimeRow(
    String label,
    DateTime time,
    DateFormat timeFormat,
    DateFormat dateFormat,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white54,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeFormat.format(time),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateFormat.format(time),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationCard(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.timer_outlined,
            color: const Color(0xFF6C63FF),
            size: 40,
          ),
          const SizedBox(height: 16),
          const Text(
            '총 지속 시간',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (hours > 0) ...[
                Text(
                  '$hours',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '시간 ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white54,
                  ),
                ),
              ],
              Text(
                '$minutes',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                '분',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(String type, Duration duration) {
    final insights = _getInsights(type, duration);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              const Text(
                '수면 인사이트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<String> _getInsights(String type, Duration duration) {
    final insights = <String>[];
    
    if (type == '깊은 수면') {
      insights.add('깊은 수면은 신체 회복과 면역 체계 강화에 중요합니다.');
      if (duration.inMinutes > 90) {
        insights.add('충분한 깊은 수면을 취하셨습니다!');
      } else {
        insights.add('깊은 수면이 다소 부족합니다. 수면 환경을 개선해보세요.');
      }
    } else if (type == 'REM 수면') {
      insights.add('REM 수면은 기억 통합과 감정 조절에 도움이 됩니다.');
      if (duration.inMinutes > 60) {
        insights.add('적절한 REM 수면을 취하셨습니다.');
      } else {
        insights.add('REM 수면이 부족할 수 있습니다.');
      }
    } else if (type == '코어 수면' || type == '수면') {
      insights.add('얕은 수면은 전체 수면 주기의 중요한 부분입니다.');
      insights.add('적절한 얕은 수면은 자연스러운 수면 패턴을 나타냅니다.');
    } else if (type == '깨어있음') {
      insights.add('수면 중 깨어있던 시간입니다.');
      if (duration.inMinutes > 30) {
        insights.add('기상 시간이 길었습니다. 수면의 질을 개선해보세요.');
      }
    }
    
    return insights;
  }

  Color _getTypeColor(String type) {
    return {
      '깨어있음': const Color(0xFFEF5350),
      'REM 수면': const Color(0xFF29B6F6),
      '코어 수면': const Color(0xFF42A5F5),
      '깊은 수면': const Color(0xFF5E35B1),
      '수면': const Color(0xFF66BB6A),
    }[type] ?? Colors.grey;
  }

  IconData _getTypeIcon(String type) {
    return {
      '깨어있음': Icons.visibility,
      'REM 수면': Icons.psychology,
      '코어 수면': Icons.cloud,
      '깊은 수면': Icons.nights_stay,
      '수면': Icons.bedtime,
    }[type] ?? Icons.hotel;
  }
}
}
