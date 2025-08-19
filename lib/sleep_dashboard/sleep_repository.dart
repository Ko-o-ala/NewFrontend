// ⬇️ sleep_repository.dart (간단 버전)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:health/health.dart';
import 'sleep_entry.dart';

class SleepRepository {
  final String baseUrl;
  final String userId;
  final int cutoffHour; // 1 → 01:00 이전은 전날 조회
  final DateTime? nowForTest;

  const SleepRepository({
    required this.baseUrl,
    required this.userId,
    this.cutoffHour = 1,
    this.nowForTest,
  });

  /// 자정~cutoff 전에 열람하면 전날로 보정
  DateTime computeFetchDate(DateTime selectedDate) {
    final now = (nowForTest ?? DateTime.now()).toLocal();
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final base = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return (isToday && now.hour < cutoffHour)
        ? base.subtract(const Duration(days: 1))
        : base;
  }

  Future<List<SleepEntry>> fetchEntries(DateTime selectedDate) async {
    final fetchDate = computeFetchDate(selectedDate);
    final dateParam = DateFormat('yyyy-MM-dd').format(fetchDate);
    final uri = Uri.parse('$baseUrl/sleep-data/$userId/$dateParam');

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    // 서버 예시: { date, sleepTime:{}, Duration:{}, segments:[{startTime,endTime,stage}], sleepScore }
    final List segs = (decoded['segments'] as List?) ?? const [];

    DateTime _toAbs(String hhmm) {
      // HH:mm 문자열을 fetchDate 기준 실제 날짜/시간으로
      final h = int.parse(hhmm.split(':')[0]);
      final m = int.parse(hhmm.split(':')[1]);
      final day =
          (h >= 18) ? fetchDate.subtract(const Duration(days: 1)) : fetchDate;
      return DateTime(day.year, day.month, day.day, h, m);
    }

    HealthDataType _mapStage(String s) {
      final t = s.toLowerCase();
      if (t == 'awake') return HealthDataType.SLEEP_AWAKE;
      if (t == 'rem') return HealthDataType.SLEEP_REM;
      if (t == 'deep') return HealthDataType.SLEEP_DEEP;
      if (t == 'light') return HealthDataType.SLEEP_LIGHT;
      return HealthDataType.SLEEP_LIGHT;
    }

    return segs.map<SleepEntry>((e) {
      final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
      final start = _toAbs(m['startTime'] as String);
      final end = _toAbs(m['endTime'] as String);
      final type = _mapStage((m['stage'] ?? '').toString());
      return SleepEntry(
        start: start,
        end: end.isBefore(start) ? start : end,
        type: type,
      );
    }).toList();
  }
}
