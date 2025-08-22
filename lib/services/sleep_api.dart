// lib/services/sleep_api.dart
import 'package:intl/intl.dart';
import 'api_client.dart';

class SleepApi {
  SleepApi(this._client);
  final ApiClient _client;

  // 월 평균
  Future<Map<String, int?>> fetchMonthlyAverage({
    required String userId,
    required DateTime month,
  }) async {
    final body = await _client.getJson('/sleep-data/$userId/month-avg');
    final List dataList = body['data'] ?? [];
    final monthKey = DateFormat('yyyy-MM').format(month);

    final thisMonth = dataList.firstWhere(
      (e) => e['month'] == monthKey,
      orElse: () => null,
    );

    if (thisMonth == null) return {};
    final avgDuration = thisMonth['avgTotalSleepDuration'];
    final avgScore = thisMonth['avgSleepScore'];
    return {
      'duration': (avgDuration is num) ? avgDuration.round() : null,
      'score': (avgScore is num) ? avgScore.round() : null,
    };
  }

  // 특정 날짜
  Future<Map<String, dynamic>?> fetchDaily({
    required String userId,
    required DateTime date,
  }) async {
    final ymd = DateFormat('yyyy-MM-dd').format(date);
    final body = await _client.getJson('/sleep-data/$userId/$ymd');

    Map<String, dynamic>? record;
    if (body['data'] is List && (body['data'] as List).isNotEmpty) {
      record = (body['data'] as List).first as Map<String, dynamic>;
    } else if (body['userID'] != null || body['date'] != null) {
      record = Map<String, dynamic>.from(body);
    }
    if (record == null) return null;

    final durationBlock = record['Duration'] ?? record['duration'];
    final total = _asInt(durationBlock?['totalSleepDuration']);
    final score = _asInt(record['sleepScore']);
    if (total == null && score == null) return null;

    return {'date': ymd, 'duration': total, 'score': score};
  }

  int? _asInt(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
