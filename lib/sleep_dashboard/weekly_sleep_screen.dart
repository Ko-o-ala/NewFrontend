import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_app/sleep_dashboard/monthly_sleep_screen.dart';
import 'package:my_app/sleep_dashboard/sleep_dashboard.dart';

class WeeklySleepScreen extends StatefulWidget {
  const WeeklySleepScreen({super.key});

  @override
  State<WeeklySleepScreen> createState() => _WeeklySleepScreenState();
}

class _WeeklySleepScreenState extends State<WeeklySleepScreen> {
  final storage = FlutterSecureStorage();
  final Health health = Health();

  bool _isLoggedIn = true;
  String username = '사용자';
  bool loading = true;
  int weekOffset = 0;
  Map<String, double> scores = {};
  int todaySleepScore = 0;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadTodayScore();
    _fetchWeeklySleep();
  }

  Future<void> _loadUsername() async {
    try {
      final token = await storage.read(key: 'jwt');
      if (token == null) {
        setState(() {
          username = '사용자';
          _isLoggedIn = false;
        });
        return;
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final response = await http.get(
        Uri.parse('https://kooala.tassoo.uk/users/profile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (userData['success'] == true && userData['data'] != null) {
          final name = userData['data']['name'] ?? '사용자';
          setState(() {
            username = name;
            _isLoggedIn = true;
          });
        } else {
          setState(() {
            username = '사용자';
            _isLoggedIn = false;
          });
        }
      } else {
        setState(() {
          username = '사용자';
          _isLoggedIn = false;
        });
      }
    } catch (e) {
      debugPrint('[USERNAME] Error fetching username: $e');
      setState(() {
        username = '사용자';
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _loadTodayScore() async {
    final userId = await storage.read(key: 'userID');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final formattedDate =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(
      'https://kooala.tassoo.uk/sleep-data/$userId/$formattedDate',
    );
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final records = data['data'];
      if (records != null && records is List && records.isNotEmpty) {
        final record = records[0];
        final score = (record['sleepScore'] ?? 0).toDouble();
        setState(() => todaySleepScore = score.toInt());
      }
    } else {
      print('❗ 오늘 수면 점수 불러오기 실패');
    }
  }

  Future<void> _handleLogout() async {
    await storage.delete(key: 'username');
    setState(() {
      username = '사용자';
      _isLoggedIn = false;
    });
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _fetchWeeklySleep() async {
    setState(() => loading = true);

    final now = DateTime.now().subtract(Duration(days: 7 * weekOffset));
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final userId = await storage.read(key: 'userID');

    final futures = List.generate(7, (i) async {
      final date = monday.add(Duration(days: i));
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse(
        'https://kooala.tassoo.uk/sleep-data/$userId/$formattedDate',
      );

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['data'];
        if (records != null && records is List && records.isNotEmpty) {
          final record = records[0];
          final score = (record['sleepScore'] ?? 0).toDouble();
          final key = _dayToKey(date.weekday);
          return <String, double>{key: score};
        }
      }
      return <String, double>{};
    });

    final results = await Future.wait(futures);
    final newScores = <String, double>{};
    for (final result in results) {
      newScores.addAll(result);
    }

    setState(() {
      scores = newScores;
      loading = false;
    });
  }

  String _dayToKey(int weekday) {
    switch (weekday) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      case 6:
        return '토';
      case 7:
        return '일';
      default:
        return '';
    }
  }

  String _getWeekRange() {
    final now = DateTime.now().subtract(Duration(days: 7 * weekOffset));
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}';
  }

  double _getAverageScore() {
    if (scores.isEmpty) return 0;
    final sum = scores.values.reduce((a, b) => a + b);
    return sum / scores.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '주간 수면 현황',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          loading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 헤더 섹션
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.calendar_view_week,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${username}님의 주간 수면',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '이번 주 수면 패턴을 확인해보세요',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 주간 선택 컨트롤
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                weekOffset++;
                              });
                              _fetchWeeklySleep();
                            },
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          Text(
                            _getWeekRange(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed:
                                weekOffset > 0
                                    ? () {
                                      setState(() {
                                        weekOffset--;
                                      });
                                      _fetchWeeklySleep();
                                    }
                                    : null,
                            icon: Icon(
                              Icons.chevron_right,
                              color:
                                  weekOffset > 0
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 평균 점수 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF4CAF50,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.trending_up,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "주간 평균 점수",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '평균 점수',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_getAverageScore().toStringAsFixed(1)}점',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    '오늘 점수',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${todaySleepScore}점',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 주간 차트
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.bar_chart,
                                  color: Color(0xFF6C63FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "일별 수면 점수",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            height: 200,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children:
                                  ['월', '화', '수', '목', '금', '토', '일'].map((
                                    day,
                                  ) {
                                    final score = scores[day] ?? 0.0;
                                    final height =
                                        score > 0 ? (score / 100) * 150 : 10.0;
                                    final color =
                                        score >= 80
                                            ? const Color(0xFF4CAF50)
                                            : score >= 60
                                            ? const Color(0xFFFFA726)
                                            : const Color(0xFFEF5350);

                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          score > 0
                                              ? score.toStringAsFixed(0)
                                              : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                score > 0
                                                    ? Colors.white
                                                    : Colors.white54,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 30,
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          day,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 액션 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => Navigator.pushNamed(context, '/monthly'),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('월간 보기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => Navigator.pushNamed(context, '/sleep'),
                            icon: const Icon(Icons.bedtime),
                            label: const Text('수면 대시보드'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D1E33),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}
