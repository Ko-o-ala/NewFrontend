// ✅ 필요한 import 유지
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/TopNav.dart';

import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MonthlySleepScreen extends StatefulWidget {
  const MonthlySleepScreen({super.key});
  @override
  State<MonthlySleepScreen> createState() => _MonthlySleepScreenState();
}

class _MonthlySleepScreenState extends State<MonthlySleepScreen> {
  final storage = const FlutterSecureStorage();
  String username = '사용자';
  bool _isLoggedIn = false;

  /// 보고 있는 달(년/월 단위)
  DateTime _cursorMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await storage.read(key: 'username');
    setState(() {
      username = name ?? '사용자';
      _isLoggedIn = name != null;
    });
  }

  /// ⬇️ 이번(커서) 달의 평균 수면(분) / 평균 점수
  Future<Map<String, int?>> fetchMonthlyAverageData(DateTime month) async {
    final userId = await storage.read(key: 'userID');
    final token = await storage.read(key: 'jwt');
    if (userId == null) return {};

    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    final uri = Uri.parse(
      'https://kooala.tassoo.uk/sleep-data/$userId/month-avg',
    );

    try {
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) {
        debugPrint('[month-avg] status ${res.statusCode}');
        return {};
      }
      final body = json.decode(res.body);
      final List dataList = body['data'] ?? [];
      final monthStr = DateFormat('yyyy-MM').format(month);

      final item = dataList.cast<Map>().firstWhere(
        (e) => e['month'] == monthStr,
        orElse: () => {},
      );

      if (item.isNotEmpty) {
        final avgDuration = item['avgTotalSleepDuration'];
        final avgScore = item['avgSleepScore'];
        return {
          'duration': (avgDuration is num) ? avgDuration.round() : null,
          'score': (avgScore is num) ? avgScore.round() : null,
        };
      }
    } catch (e) {
      debugPrint('[month-avg] error: $e');
    }
    return {};
  }

  /// ⬇️ 커서 달의 날짜별 기록(분, 점수)
  Future<Map<DateTime, Map<String, dynamic>>> fetchSleepData(
    DateTime month,
  ) async {
    final userId = await storage.read(key: 'userID');
    final token = await storage.read(key: 'jwt');
    if (userId == null) return {};

    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    final year = month.year;
    final mon = month.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, mon);

    final futures = List.generate(daysInMonth, (i) async {
      final date = DateTime(year, mon, i + 1);
      final ymd = DateFormat('yyyy-MM-dd').format(date);
      final uri = Uri.parse('https://kooala.tassoo.uk/sleep-data/$userId/$ymd');

      try {
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) return null; // 데이터 없는 날

        final body = json.decode(res.body);
        Map<String, dynamic>? record;

        if (body['data'] is List && (body['data'] as List).isNotEmpty) {
          record = Map<String, dynamic>.from((body['data'] as List).first);
        } else if (body is Map &&
            (body['userID'] != null || body['date'] != null)) {
          record = Map<String, dynamic>.from(body);
        }
        if (record == null) return null;

        final durationBlock = record['Duration'] ?? record['duration'];
        final total = _asInt(durationBlock?['totalSleepDuration']);
        final score = _asInt(record['sleepScore']);
        if (total == null || score == null) return null;

        return MapEntry(date, {'duration': total, 'score': score});
      } catch (e) {
        debugPrint('[sleep-month] $ymd -> error $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(
      results.whereType<MapEntry<DateTime, Map<String, dynamic>>>(),
    );
  }

  int? _asInt(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Future<void> _handleLogout() async {
    await storage.deleteAll();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  /// 달 이동: delta -1(이전), +1(다음)
  void _changeMonth(int delta) {
    final next = DateTime(_cursorMonth.year, _cursorMonth.month + delta);
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month);
    if (next.isAfter(nowMonth)) return; // 미래 달 금지
    setState(() => _cursorMonth = next);
  }

  bool get _canGoNext {
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month);
    return _cursorMonth.isBefore(nowMonth);
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy년 M월').format(_cursorMonth);

    return Scaffold(
      appBar: TopNav(
        isLoggedIn: _isLoggedIn,
        onLogin: () => Navigator.pushNamed(context, '/login'),
        onLogout: _handleLogout,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Good Morning',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTab('Days', false),
                  const SizedBox(width: 8),
                  _buildTab('Weeks', false),
                  const SizedBox(width: 8),
                  _buildTab('Months', true),
                ],
              ),
              const SizedBox(height: 16),

              // 🔁 수면 기록 달력 카드
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 360,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ✅ 달력 헤더(이전/다음 화살표 + 월)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                            tooltip: '이전 달',
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                monthLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed:
                                _canGoNext ? () => _changeMonth(1) : null,
                            tooltip: '다음 달',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0x11000000)),

                    // ✅ 달력 내용
                    Expanded(
                      child: FutureBuilder<Map<DateTime, Map<String, dynamic>>>(
                        future: fetchSleepData(_cursorMonth),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snap.hasData || snap.hasError) {
                            return const Center(
                              child: Text('수면 데이터를 불러오지 못했어요.'),
                            );
                          }
                          return Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: _buildCalendar(_cursorMonth, snap.data!),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 🔁 평균 수면 시간/점수 (커서 달 기준)
              FutureBuilder<Map<String, int?>>(
                future: fetchMonthlyAverageData(_cursorMonth),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('이 달의 평균 데이터를 불러올 수 없어요.');
                  }

                  final duration = snapshot.data!['duration'];
                  final score = snapshot.data!['score'];
                  if (duration == null || score == null) {
                    return const Text('이 달의 평균 데이터가 부족해요.');
                  }

                  final hrs = duration ~/ 60;
                  final mins = duration % 60;

                  return Column(
                    children: [
                      Text(
                        '$username님은 ${_cursorMonth.month}월에 ...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '평균 ${hrs}시간 ${mins}분을 주무셨어요.\n수면 점수는 평균 ${score}점이에요.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        if (label == 'Days') Navigator.pushReplacementNamed(context, '/sleep');
        if (label == 'Weeks')
          Navigator.pushReplacementNamed(context, '/weekly');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8183D9) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatHM2Lines(dynamic minutes) {
    if (minutes == null || minutes is! int) return '-';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hrs}H\n${mins}M';
  }

  Widget _buildCalendar(
    DateTime month,
    Map<DateTime, Map<String, dynamic>> sleepData,
  ) {
    const double kCellHeight = 90;
    const BorderRadius kRadius = BorderRadius.all(Radius.circular(12));

    final firstDay = DateTime(month.year, month.month, 1);
    final firstWd = firstDay.weekday; // 1=Mon ... 7=Sun
    final totalDays = DateUtils.getDaysInMonth(month.year, month.month);

    const weekHeaders = ['일', '월', '화', '수', '목', '금', '토'];
    final rows = <Widget>[
      Row(
        children:
            weekHeaders
                .map((d) => Expanded(child: Center(child: Text(d))))
                .toList(),
      ),
    ];

    int dayCounter = 1 - (firstWd % 7); // Sun-start 보정
    while (dayCounter <= totalDays) {
      final week = <Widget>[];
      for (int wd = 0; wd < 7; wd++, dayCounter++) {
        if (dayCounter < 1 || dayCounter > totalDays) {
          week.add(const Expanded(child: SizedBox()));
        } else {
          final d = DateTime(month.year, month.month, dayCounter);
          final data = sleepData[d];
          week.add(
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                height: kCellHeight,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: data != null ? Colors.black : Colors.transparent,
                  borderRadius: kRadius,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '$dayCounter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: data != null ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (data != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatHM2Lines(data['duration']),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${data['score']}점',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
      }
      rows.add(Row(children: week));
    }

    return Column(children: rows);
  }
}
