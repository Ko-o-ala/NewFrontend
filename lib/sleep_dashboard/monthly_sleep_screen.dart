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

  Future<int?> fetchMonthlyAverageSleep() async {
    final userId = await storage.read(key: 'userID');
    if (userId == null) throw Exception('로그인이 필요합니다.');

    final token = await storage.read(key: 'authToken');
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
        return null;
      }
      final body = json.decode(res.body);
      if (body is Map && body['average'] != null) {
        final avg = body['average'];
        if (avg is num) return avg.round();
        if (avg is String) return int.tryParse(avg);
      }
      return null;
    } catch (e) {
      debugPrint('[month-avg] error: $e');
      return null;
    }
  }

  Future<void> _loadUsername() async {
    final name = await storage.read(key: 'username');
    setState(() {
      username = name ?? '사용자';
      _isLoggedIn = name != null;
    });
  }

  Future<Map<DateTime, Map<String, dynamic>>> fetchSleepData() async {
    final userId = await storage.read(key: 'userID');
    if (userId == null) throw Exception('로그인이 필요합니다.');

    final token = await storage.read(key: 'authToken');
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
        if (body is Map &&
            body['data'] is List &&
            (body['data'] as List).isNotEmpty) {
          record = (body['data'] as List).first as Map<String, dynamic>;
        } else if (body is Map &&
            (body['userID'] != null || body['date'] != null)) {
          record = body.cast<String, dynamic>();
        } else {
          debugPrint('[sleep-month] $ymd -> empty schema');
          return null;
        }

        final durationBlock =
            (record['Duration'] ?? record['duration']) as Map<String, dynamic>?;
        if (durationBlock == null) return null;

        // 숫자/문자 모두 수용
        int? asInt(dynamic v) {
          if (v == null) return null;
          if (v is num) return v.round();
          if (v is String) return int.tryParse(v);
          return null;
        }

        final total = asInt(durationBlock['totalSleepDuration']);
        final score = asInt(record['sleepScore']);

        if (total == null || score == null) {
          debugPrint('[sleep-month] $ymd -> missing total/score');
          return null;
        }

        // 서버가 다른 날짜로 저장했는지(앵커 불일치) 확인용
        final serverDateStr =
            (record['date'] ?? record['anchorDate'])?.toString();
        if (serverDateStr != null) {
          try {
            final sd = DateTime.parse(serverDateStr);
            final clientKey = DateTime(year, month, i + 1);
            final serverKey = DateTime(sd.year, sd.month, sd.day);
            if (clientKey != serverKey) {
              debugPrint(
                '[sleep-month] anchor mismatch: query=$ymd, server=${DateFormat('yyyy-MM-dd').format(serverKey)}',
              );
            }
          } catch (_) {}
        }

        // 캘린더 키는 ‘조회일’로 고정(앵커가 다르면 위 로그로 파악)
        return MapEntry(date, {'duration': total, 'score': score});
      } catch (e) {
        debugPrint('[sleep-month] $ymd -> error $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    final map = Map.fromEntries(
      results.whereType<MapEntry<DateTime, Map<String, dynamic>>>(),
    );

    debugPrint('[sleep-month] collected ${map.length}/$daysInMonth days');
    return map;
  }

  Future<void> _handleLogout() async {
    await storage.delete(key: 'username');
    await storage.delete(key: 'authToken');
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
              Expanded(
                child: FutureBuilder<Map<DateTime, Map<String, dynamic>>>(
                  future: fetchSleepData(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snap.hasError) {
                      return Center(child: Text('로딩 실패: ${snap.error}'));
                    }
                    return _buildCalendar(now, snap.data!);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$username님은 ${now.month}월에 ...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<int?>(
                future: fetchMonthlyAverageSleep(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError || snapshot.data == null) {
                    return const Text(
                      '평균 수면 데이터를 불러오는 데 실패했어요.',
                      textAlign: TextAlign.center,
                    );
                  } else {
                    final totalMinutes = snapshot.data!;
                    final hrs = totalMinutes ~/ 60;
                    final mins = totalMinutes % 60;
                    return Text(
                      '평균 ${hrs}시간 ${mins}분을 주무셨어요.\n목표보다 아쉽지만, 점점 안정적인 패턴을 찾아가고 있어요!',
                      textAlign: TextAlign.center,
                    );
                  }
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

  String _formatDuration(dynamic minutes) {
    if (minutes == null || minutes is! int) return '-';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hrs}H ${mins}M';
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
}
