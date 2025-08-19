import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'sleep_segment.dart';
import 'sleep_segment_pager.dart';

class SleepSegmentPagerRemote extends StatefulWidget {
  final String baseUrl; // 예: https://api.example.com
  final String userId;
  final int cutoffHour; // 1이면 01:00 이전은 전날로 간주
  final DateTime? nowForTest; // 테스트용(주입 없으면 DateTime.now())

  const SleepSegmentPagerRemote({
    Key? key,
    required this.baseUrl,
    required this.userId,
    this.cutoffHour = 1,
    this.nowForTest,
  }) : super(key: key);

  @override
  State<SleepSegmentPagerRemote> createState() =>
      _SleepSegmentPagerRemoteState();
}

class _SleepSegmentPagerRemoteState extends State<SleepSegmentPagerRemote> {
  late Future<List<SleepSegment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSegments();
  }

  Future<List<SleepSegment>> _fetchSegments() async {
    final now = (widget.nowForTest ?? DateTime.now()).toLocal();
    final todayLocalMidnight = DateTime(now.year, now.month, now.day);
    final fetchDate =
        (now.hour < widget.cutoffHour)
            ? todayLocalMidnight.subtract(const Duration(days: 1))
            : todayLocalMidnight;

    final dateParam = DateFormat('yyyy-MM-dd').format(fetchDate);
    final uri = Uri.parse(
      '${widget.baseUrl}/sleep-data/${widget.userId}/$dateParam',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    // API가 배열을 직접 주거나 { segments: [...] } 형태를 모두 허용
    final List list =
        (decoded is List) ? decoded : (decoded['segments'] as List? ?? []);

    return list.map<SleepSegment>((e) => _segmentFromJson(e)).toList();
  }

  // ⬇️ SleepSegmentPagerRemote 안의 _segmentFromJson 만 교체
  SleepSegment _segmentFromJson(dynamic e) {
    final m = (e as Map).map((k, v) => MapEntry(k.toString(), v));
    final stageStr =
        (m['stage'] ?? m['sleepStage'] ?? m['type'] ?? '').toString();
    final stage = _stageFromString(stageStr);

    double _hmToMinuteFromBase(String hhmm) {
      // "HH:mm" → 18:00을 0으로 하는 분 오프셋
      final parts = hhmm.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (h >= 18) {
        // 전날 18:00~24:00
        return ((h - 18) * 60 + m).toDouble();
      } else {
        // 00:00~17:59 → 6시간을 더한 위치
        return ((6 * 60) + h * 60 + m).toDouble();
      }
    }

    // 서버 형식: startTime/endTime 가 "HH:mm"
    if (m['startTime'] != null && m['endTime'] != null) {
      final start = _hmToMinuteFromBase(m['startTime'].toString());
      final end = _hmToMinuteFromBase(m['endTime'].toString());
      return SleepSegment(stage: stage, startMinute: start, endMinute: end);
    }

    // 과거 포맷 호환(있으면)
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final start = _toDouble(
      m['startMinute'] ?? m['start_minute'] ?? m['start'] ?? 0,
    );
    final end = _toDouble(
      m['endMinute'] ?? m['end_minute'] ?? m['end'] ?? start,
    );
    return SleepSegment(stage: stage, startMinute: start, endMinute: end);
  }

  SleepStage _stageFromString(String s) {
    final t = s.trim().toLowerCase();
    switch (t) {
      case 'awake':
      case '깨어있음':
      case 'wake':
        return SleepStage.awake;
      case 'light':
      case '얕은 수면':
      case 'core':
      case '코어 수면':
        return SleepStage.light;
      case 'rem':
      case 'rem 수면':
        return SleepStage.rem;
      case 'deep':
      case '깊은 수면':
        return SleepStage.deep;
      default:
        // 모르는 값은 일단 'light'로 폴백
        return SleepStage.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SleepSegment>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 160,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }
        if (snap.hasError) {
          return _ErrorBox(message: '수면 데이터를 불러오지 못했어요.\n${snap.error}');
        }
        return SleepSegmentPager(segments: snap.data ?? const []);
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
