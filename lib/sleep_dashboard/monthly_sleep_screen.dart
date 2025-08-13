// ✅ 필요한 import 유지
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/TopNav.dart';
import 'package:my_app/bottomNavigationBar.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MonthlySleepScreen extends StatefulWidget {
  const MonthlySleepScreen({super.key});

  @override
  State<MonthlySleepScreen> createState() => _MonthlySleepScreenState();
}

class _MonthlySleepScreenState extends State<MonthlySleepScreen> {
  final storage = FlutterSecureStorage();
  String username = '사용자';
  bool _isLoggedIn = false;

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

  Future<Map<String, int?>> fetchMonthlyAverageData() async {
    final userId = await storage.read(key: 'userID');
    final token = await storage.read(key: 'jwt');

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

      final now = DateTime.now();
      final currentMonthStr = DateFormat('yyyy-MM').format(now);

      final thisMonth = dataList.firstWhere(
        (e) => e['month'] == currentMonthStr,
        orElse: () => null,
      );

      if (thisMonth != null) {
        final avgDuration = thisMonth['avgTotalSleepDuration'];
        final avgScore = thisMonth['avgSleepScore'];
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

  Future<Map<DateTime, Map<String, dynamic>>> fetchSleepData() async {
    final userId = await storage.read(key: 'userID');
    final token = await storage.read(key: 'jwt'); // ✅ 통일

    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    final futures = List.generate(daysInMonth, (i) async {
      final date = DateTime(year, month, i + 1);
      final ymd = DateFormat('yyyy-MM-dd').format(date);
      final uri = Uri.parse('https://kooala.tassoo.uk/sleep-data/$userId/$ymd');

      try {
        final res = await http.get(uri, headers: headers);
        if (res.statusCode != 200) {
          debugPrint('[sleep-month] $ymd -> ${res.statusCode}');
          return null;
        }

        final body = json.decode(res.body);
        Map<String, dynamic>? record;

        if (body['data'] is List && (body['data'] as List).isNotEmpty) {
          record = (body['data'] as List).first;
        } else if (body['userID'] != null || body['date'] != null) {
          record = body.cast<String, dynamic>();
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
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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

              // 🔁 수면 기록 달력
              Expanded(
                child: FutureBuilder<Map<DateTime, Map<String, dynamic>>>(
                  future: fetchSleepData(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (!snap.hasData || snap.hasError) {
                      return const Center(child: Text('수면 데이터를 불러오지 못했어요.'));
                    }
                    return _buildCalendar(now, snap.data!);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 🔁 평균 수면 시간
              FutureBuilder<Map<String, int?>>(
                future: fetchMonthlyAverageData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('이번 달 평균 데이터를 불러올 수 없어요.');
                  }

                  final duration = snapshot.data!['duration'];
                  final score = snapshot.data!['score'];

                  if (duration == null || score == null) {
                    return const Text('이번 달 평균 데이터가 부족해요.');
                  }

                  final hrs = duration ~/ 60;
                  final mins = duration % 60;

                  return Column(
                    children: [
                      Text(
                        '$username님은 ${now.month}월에 ...',
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
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) Navigator.pushReplacementNamed(context, '/real-home');
          if (i == 2) Navigator.pushReplacementNamed(context, '/sound');
          if (i == 3) Navigator.pushReplacementNamed(context, '/setting');
        },
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

  Widget _buildCalendar(
    DateTime now,
    Map<DateTime, Map<String, dynamic>> sleepData,
  ) {
    final currentMonth = DateTime(now.year, now.month);
    final firstWd = DateTime(currentMonth.year, currentMonth.month, 1).weekday;
    final totalDays = DateUtils.getDaysInMonth(now.year, now.month);

    const weekHeaders = ['일', '월', '화', '수', '목', '금', '토'];
    final rows = <Widget>[
      Row(
        children:
            weekHeaders
                .map((d) => Expanded(child: Center(child: Text(d))))
                .toList(),
      ),
    ];

    int dayCounter = 1 - (firstWd % 7);
    while (dayCounter <= totalDays) {
      final week = <Widget>[];
      for (int wd = 0; wd < 7; wd++, dayCounter++) {
        if (dayCounter < 1 || dayCounter > totalDays) {
          week.add(const Expanded(child: SizedBox()));
        } else {
          final d = DateTime(now.year, now.month, dayCounter);
          final data = sleepData[d];
          week.add(
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: data != null ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '$dayCounter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: data != null ? Colors.white : Colors.black,
                      ),
                    ),
                    if (data != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(data['duration']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '${data['score']}점',
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

  String _formatDuration(dynamic minutes) {
    if (minutes == null || minutes is! int) return '-';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hrs}H ${mins}M';
  }
}
