import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_app/TopNav.dart';
import 'package:my_app/bottomNavigationBar.dart';
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
    final name = await storage.read(key: 'username');
    setState(() {
      username = name ?? '사용자';
      _isLoggedIn = name != null;
    });
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
          return MapEntry(key, score);
        }
      }
      return null;
    });

    final results = await Future.wait(futures);
    final tempScores = {
      'Mon': 0.0,
      'Tue': 0.0,
      'Wed': 0.0,
      'Thu': 0.0,
      'Fri': 0.0,
      'Sat': 0.0,
      'Sun': 0.0,
    };

    for (var result in results) {
      if (result != null) tempScores[result.key] = result.value;
    }

    setState(() {
      scores = tempScores;
      loading = false;
    });
  }

  String _dayToKey(int weekday) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
  }

  String _translateDay(String key) {
    switch (key) {
      case 'Mon':
        return '월요일';
      case 'Tue':
        return '화요일';
      case 'Wed':
        return '수요일';
      case 'Thu':
        return '목요일';
      case 'Fri':
        return '금요일';
      case 'Sat':
        return '토요일';
      case 'Sun':
        return '일요일';
      default:
        return key;
    }
  }

  Widget _buildTab(BuildContext context, String label, bool selected) {
    return GestureDetector(
      onTap: () {
        if (label == 'Days') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => SleepDashboard()),
          );
        } else if (label == 'Months') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MonthlySleepScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    /// 해당 weekOffset의 주(월요일 시작) 월요일 날짜
    DateTime _mondayOfCurrentOffset() {
      final base = DateTime.now().subtract(Duration(days: 7 * weekOffset));
      return base.subtract(Duration(days: base.weekday - DateTime.monday));
    }

    /// 월요일 시작 기준, '몇 주차'인지 계산
    int _weekOfMonth(DateTime date) {
      final firstOfMonth = DateTime(date.year, date.month, 1);
      final offset = (firstOfMonth.weekday - DateTime.monday + 7) % 7; // 0~6
      return ((date.day + offset - 1) ~/ 7) + 1;
    }

    /// 상단에 보여줄 라벨: "YYYY년 M월 N주차 (M.D–M.D)"
    String _currentWeekLabel() {
      final monday = _mondayOfCurrentOffset();
      final sunday = monday.add(const Duration(days: 6));
      final wom = _weekOfMonth(monday);
      String mmdd(DateTime d) => '${d.month}.${d.day}';
      return '${monday.year}년 ${monday.month}월 ${wom}주차  (${mmdd(monday)}–${mmdd(sunday)})';
    }

    final weekLabel = _currentWeekLabel();

    final bestDay =
        scores.entries.isNotEmpty
            ? scores.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : '';
    final worstDay =
        scores.entries.isNotEmpty
            ? scores.entries.reduce((a, b) => a.value < b.value ? a : b).key
            : '';

    final today = DateTime.now().subtract(const Duration(days: 1));
    final todayKey = _dayToKey(today.weekday);

    final isCurrentWeek = weekOffset == 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TopNav(
        isLoggedIn: _isLoggedIn,
        onLogin: () => Navigator.pushReplacementNamed(context, '/login'),
        onLogout: _handleLogout,
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Good Morning',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEBFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          weekLabel,
                          style: const TextStyle(color: Color(0xFF4B4EBD)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTab(context, 'Days', false),
                          _buildTab(context, 'Weeks', true),
                          _buildTab(context, 'Months', false),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '주간 수면 리포트',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  setState(() {
                                    weekOffset += 1;
                                    _fetchWeeklySleep();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed:
                                    weekOffset == 0
                                        ? null
                                        : () {
                                          setState(() {
                                            weekOffset -= 1;
                                            _fetchWeeklySleep();
                                          });
                                        },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:
                              scores.entries.map((e) {
                                final isToday =
                                    isCurrentWeek && e.key == todayKey;

                                return _buildBar(
                                  e.key,
                                  e.value,
                                  highlight: isToday,
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (scores.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Best 수면 요일',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(_translateDay(bestDay)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'Worst 수면 요일',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(_translateDay(worstDay)),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Text(
                        '오늘 수면 점수: $todaySleepScore점',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTap: (idx) {
          if (idx == 0) Navigator.pushReplacementNamed(context, '/real-home');
          if (idx == 2) Navigator.pushReplacementNamed(context, '/sound');
          if (idx == 3) Navigator.pushReplacementNamed(context, '/setting');
        },
      ),
    );
  }

  Widget _buildBar(String day, double height, {bool highlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          height.toInt().toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.blueAccent : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 16,
          height: height,
          color: highlight ? const Color(0xFF8183D9) : const Color(0xFFF6D35F),
        ),
        const SizedBox(height: 4),
        Text(day),
      ],
    );
  }
}
