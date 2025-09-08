// ✅ 필요한 import 유지
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MonthlySleepScreen extends StatefulWidget {
  const MonthlySleepScreen({super.key});
  @override
  State<MonthlySleepScreen> createState() => _MonthlySleepScreenState();
}

class _MonthlySleepScreenState extends State<MonthlySleepScreen> {
  final storage = const FlutterSecureStorage();
  String username = '사용자';
  bool _isLoggedIn = false;

  /// 보고 있는 달(년/월 단위) - 전날 기준으로 설정
  DateTime _cursorMonth = DateTime(
    DateTime.now().subtract(const Duration(days: 1)).year,
    DateTime.now().subtract(const Duration(days: 1)).month,
  );

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _checkProfileUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지 진입 시마다 데이터 새로고침
    setState(() {});
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

  Future<void> _checkProfileUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileUpdated = prefs.getBool('profileUpdated') ?? false;

      if (profileUpdated) {
        // 프로필이 업데이트된 경우 사용자 이름 다시 로드
        await _loadUsername();
        // 플래그 제거
        await prefs.remove('profileUpdated');
        debugPrint('[MonthlySleepScreen] 프로필 업데이트 감지 - 사용자 이름 새로고침');
      }
    } catch (e) {
      debugPrint('[MonthlySleepScreen] 프로필 업데이트 체크 실패: $e');
    }
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
        if (res.statusCode != 200) return null;

        final body = json.decode(res.body);
        final List dataList = body['data'] ?? [];
        if (dataList.isEmpty) return null;

        final item = dataList.first;
        return MapEntry(date, {
          'duration': item['Duration']?['totalSleepDuration'] ?? 0,
          'score': item['sleepScore'] ?? 0,
        });
      } catch (e) {
        debugPrint('[fetchSleepData] error for $ymd: $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    final Map<DateTime, Map<String, dynamic>> data = {};
    for (final result in results) {
      if (result != null) data[result.key] = result.value;
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '월간 수면 현황',
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
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: const Color(0xFF6C63FF),
        backgroundColor: const Color(0xFF1D1E33),
        child: SingleChildScrollView(
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
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${username}님의 월간 수면',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '이번 달 수면 패턴을 확인해보세요',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 월 선택 컨트롤
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
                          _cursorMonth = DateTime(
                            _cursorMonth.year,
                            _cursorMonth.month - 1,
                          );
                        });
                      },
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy년 M월').format(_cursorMonth),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _cursorMonth = DateTime(
                            _cursorMonth.year,
                            _cursorMonth.month + 1,
                          );
                        });
                      },
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 월간 통계 카드
              FutureBuilder<Map<String, int?>>(
                future: fetchMonthlyAverageData(_cursorMonth),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? {};
                  final avgDuration = data['duration'];
                  final avgScore = data['score'];

                  return Container(
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
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.analytics,
                                color: Color(0xFF4CAF50),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "월간 평균 통계",
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
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    '평균 수면 시간',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    avgDuration != null
                                        ? '${(avgDuration / 60).toStringAsFixed(1)}시간'
                                        : '데이터 없음',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text(
                                    '평균 수면 점수',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    avgScore != null
                                        ? '${avgScore}점'
                                        : '데이터 없음',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6C63FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // 월간 캘린더 차트
              FutureBuilder<Map<DateTime, Map<String, dynamic>>>(
                future: fetchSleepData(_cursorMonth),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final year = _cursorMonth.year;
                  final month = _cursorMonth.month;
                  final daysInMonth = DateUtils.getDaysInMonth(year, month);
                  final firstDayOfMonth = DateTime(year, month, 1);
                  final firstWeekday = firstDayOfMonth.weekday;

                  return Container(
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
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.calendar_view_month,
                                color: Color(0xFF6C63FF),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "월간 수면 캘린더",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 요일 헤더
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children:
                              ['월', '화', '수', '목', '금', '토', '일']
                                  .map(
                                    (day) => SizedBox(
                                      width: 40,
                                      child: Text(
                                        day,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),

                        const SizedBox(height: 16),

                        // 캘린더 그리드
                        ...List.generate(
                          ((firstWeekday - 1 + daysInMonth) / 7).ceil(),
                          (weekIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: List.generate(7, (dayIndex) {
                                  final dayOfWeek = dayIndex + 1;
                                  final weekOffset = weekIndex * 7;
                                  final dayOfMonth =
                                      weekOffset +
                                      dayIndex -
                                      (firstWeekday - 1) +
                                      1;

                                  if (dayOfMonth < 1 ||
                                      dayOfMonth > daysInMonth) {
                                    return const SizedBox(
                                      width: 40,
                                      height: 40,
                                    );
                                  }

                                  final date = DateTime(
                                    year,
                                    month,
                                    dayOfMonth,
                                  );
                                  final dayData = data[date];
                                  final score = dayData?['score'] ?? 0;
                                  final duration = dayData?['duration'] ?? 0;

                                  Color getColor() {
                                    if (score >= 80)
                                      return const Color(0xFF4CAF50);
                                    if (score >= 60)
                                      return const Color(0xFFFFA726);
                                    if (score > 0)
                                      return const Color(0xFFEF5350);
                                    return Colors.transparent;
                                  }

                                  return Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: getColor(),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dayOfMonth.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  score > 0
                                                      ? Colors.white
                                                      : Colors.white70,
                                            ),
                                          ),
                                          if (score > 0)
                                            Text(
                                              '${score.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // 범례
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendItem(
                              '우수 (80점+)',
                              const Color(0xFF4CAF50),
                            ),
                            _buildLegendItem(
                              '보통 (60-79점)',
                              const Color(0xFFFFA726),
                            ),
                            _buildLegendItem(
                              '미흡 (1-59점)',
                              const Color(0xFFEF5350),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),

              // 액션 버튼들
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/weekly'),
                      icon: const Icon(Icons.calendar_view_week),
                      label: const Text('주간 보기'),
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
                      onPressed: () => Navigator.pushNamed(context, '/sleep'),
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
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
