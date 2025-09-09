import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// =======================
/// 모델 & 유틸
/// =======================

enum SleepStage { deep, rem, light, awake }

class SleepLog {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  SleepLog({required this.start, required this.end, required this.stage});

  Duration get duration => end.difference(start);
}

String _ymd(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime _parseTimeWithDate(String timeStr, DateTime date) {
  final parts = timeStr.split(":");
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  final dt = DateTime(date.year, date.month, date.day, hour, minute);

  // 수정된 시간 계산 로직
  // 12시 이후(12:00~23:59)는 그 날짜 그대로, 12시 이전(00:00~11:59)은 다음 날짜로
  if (hour < 12) {
    // 00:00~11:59는 다음 날로 처리
    debugPrint(
      '[TIME] $timeStr -> 다음 날로 처리: ${dt.add(const Duration(days: 1))}',
    );
    return dt.add(const Duration(days: 1));
  } else {
    // 12:00~23:59는 그 날 그대로
    debugPrint('[TIME] $timeStr -> 그 날 그대로: $dt');
    return dt;
  }
}

SleepStage _parseStage(dynamic v) {
  if (v == null) {
    debugPrint('[SLEEP] 수면 단계가 null입니다. 기본값 light 사용');
    return SleepStage.light;
  }

  final s = v.toString().toUpperCase();
  debugPrint('[SLEEP] 수면 단계 파싱: "$v" -> "$s"');

  if (s.contains('DEEP')) return SleepStage.deep;
  if (s.contains('REM')) return SleepStage.rem;
  if (s.contains('AWAKE') || s == 'WAKE') return SleepStage.awake;

  // HealthDataType.SLEEP_LIGHT / SLEEP_ASLEEP / LIGHT 등은 light로
  return SleepStage.light;
}

Color stageColor(SleepStage s) {
  switch (s) {
    case SleepStage.deep:
      return const Color(0xFF1565C0); // 코어 수면 - 짙은 파란색
    case SleepStage.rem:
      return const Color(0xFF5E35B1); // REM 수면 - 보라색
    case SleepStage.light:
      return const Color(0xFF42A5F5); // 얕은 수면 - 연한 파란색
    case SleepStage.awake:
      return const Color(0xFFEF5350); // 깨어있음 - 빨간색
  }
}

/// =======================
/// 메인 화면
/// =======================

class SleepChartScreen extends StatefulWidget {
  final DateTime selectedDate;

  const SleepChartScreen({Key? key, required this.selectedDate})
    : super(key: key);

  @override
  State<SleepChartScreen> createState() => _SleepChartScreenState();
}

class _SleepChartScreenState extends State<SleepChartScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  String? _error;
  List<SleepLog> _logs = [];
  String? _userId;
  Duration? _totalSleepDuration; // 서버의 totalSleepDuration 저장
  Duration? _awakeDuration; // 서버의 awakeDuration 저장
  bool _fallbackFromTwoDaysAgo = false; // 이틀 전 데이터 사용 여부
  DateTime? _actualDataDate; // 실제 가져온 데이터의 날짜

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _bootstrap();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<bool> _fetchForDate(DateTime apiDay) async {
    try {
      final dateStr = _ymd(apiDay);
      final uid =
          _userId ??
          await _storage.read(key: 'userID') ??
          await _storage.read(key: 'userId');
      if (uid == null || uid.trim().isEmpty) {
        if (mounted) setState(() => _error = '로그인이 필요합니다. (userID 없음)');
        return false;
      }

      final url = Uri.parse(
        'https://kooala.tassoo.uk/sleep-data/${Uri.encodeComponent(uid)}/$dateStr',
      );
      final headers = await _headers();

      debugPrint('[SLEEP] TRY $dateStr -> $url');

      final resp = await http.get(url, headers: headers);
      debugPrint('[SLEEP] GET $url -> ${resp.statusCode}');
      debugPrint('[SLEEP] body: ${resp.body}');

      if (resp.statusCode == 401) {
        if (mounted) setState(() => _error = '인증 만료됨(401). 다시 로그인해주세요.');
        return false;
      }
      if (resp.statusCode == 404) {
        // 해당 날짜 데이터 없음 → 폴백 후보
        return false;
      }
      if (resp.statusCode != 200) {
        if (mounted) {
          setState(
            () =>
                _error =
                    'HTTP ${resp.statusCode}: ${resp.body.isNotEmpty ? resp.body : 'Unknown error'}',
          );
        }
        return false;
      }

      final decoded = json.decode(resp.body);
      final dataList = decoded['data'] as List? ?? [];

      // 파싱
      final List<SleepLog> logs = [];
      Duration? totalSleepDuration;

      for (final item in dataList) {
        if (item is! Map<String, dynamic>) continue;

        // 총 수면시간(수면분석과 동일: 실제수면 + 깨어있음)
        totalSleepDuration ??= () {
          final dur = item['Duration'] as Map<String, dynamic>?;
          if (dur == null) return null;
          final total = (dur['totalSleepDuration'] as int?) ?? 0;
          return Duration(minutes: total);
        }();

        // 깨어있던 시간도 별도 저장
        _awakeDuration ??= () {
          final dur = item['Duration'] as Map<String, dynamic>?;
          if (dur == null) return null;
          final awake = (dur['awakeDuration'] as int?) ?? 0;
          return Duration(minutes: awake);
        }();

        final segments = item['segments'] as List? ?? [];
        final dateStr = item['date'] as String?;
        if (dateStr == null) continue;

        final baseDate = DateTime.parse(dateStr);

        for (final seg in segments) {
          if (seg is! Map<String, dynamic>) continue;
          final startTimeStr = seg['startTime'] as String?;
          final endTimeStr = seg['endTime'] as String?;
          final stageStr = seg['stage'] as String?;
          if (startTimeStr == null || endTimeStr == null || stageStr == null)
            continue;

          final start = _parseTimeWithDate(startTimeStr, baseDate);
          final end = _parseTimeWithDate(endTimeStr, baseDate);
          if (!end.isAfter(start)) continue;

          logs.add(
            SleepLog(start: start, end: end, stage: _parseStage(stageStr)),
          );
        }
      }

      // 데이터가 완전히 비면 false (폴백 대상)
      final hasAny =
          logs.isNotEmpty ||
          (totalSleepDuration != null && totalSleepDuration.inMinutes > 0);
      if (!hasAny) return false;

      // 성공적으로 불러온 경우 화면 상태 갱신
      if (mounted) {
        setState(() {
          _logs = logs..sort((a, b) => a.start.compareTo(b.start));
          _totalSleepDuration = totalSleepDuration;
          _actualDataDate = apiDay; // 실제 데이터 날짜 저장
          _error = null;
        });
      }
      return true;
    } catch (e) {
      debugPrint('[SLEEP] _fetchForDate error: $e');
      return false;
    }
  }

  Future<void> _bootstrap() async {
    try {
      debugPrint('[SLEEP] 부트스트랩 시작');

      final uid =
          await _storage.read(key: 'userID') ??
          await _storage.read(key: 'userId');

      debugPrint('[SLEEP] 저장소에서 읽은 userID: $uid');

      if (uid == null || uid.trim().isEmpty) {
        throw Exception('로그인이 필요합니다. (userID 없음)');
      }

      setState(() => _userId = uid.trim());
      debugPrint('[SLEEP] 사용자 ID 설정 완료: $_userId');

      await _fetch();
    } catch (e) {
      debugPrint('[SLEEP] 부트스트랩 에러: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, String>> _headers() async {
    final raw = await _storage.read(key: 'jwt');
    if (raw == null || raw.trim().isEmpty) {
      throw Exception('토큰이 없습니다. 다시 로그인해주세요.');
    }
    final tokenOnly =
        raw.startsWith(RegExp(r'Bearer\\s+', caseSensitive: false))
            ? raw.split(' ').last
            : raw;

    return {
      'Authorization': 'Bearer $tokenOnly',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
  }

  DateTime _apiDate(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(const Duration(days: 1));

  Future<void> _fetch() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final apiDay1 = _apiDate(widget.selectedDate); // 선택일 - 1일

      final ok1 = await _fetchForDate(apiDay1);

      if (!ok1) {
        // 전날 없으면 → 이틀 전
        final apiDay2 = apiDay1.subtract(const Duration(days: 1));

        final ok2 = await _fetchForDate(apiDay2);
        if (mounted) setState(() => _fallbackFromTwoDaysAgo = ok2);
      } else {
        if (mounted) setState(() => _fallbackFromTwoDaysAgo = false);
      }

      if (!mounted) return;
      setState(() => _loading = false);

      // 애니메이션 시작
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// baseTime = 선택 날짜의 00:00 - 6시간 (전날 18시) ~ 다음날 12:00 까지 18시간 윈도우
  /// 예: 21일을 선택하면 20일 18시 ~ 22일 12시까지의 수면 데이터를 표시
  Duration get _totalSleep {
    // 서버의 totalSleepDuration + awakeDuration을 우선 사용 (수면분석과 동일한 값)
    if (_totalSleepDuration != null && _awakeDuration != null) {
      final totalInBed = _totalSleepDuration! + _awakeDuration!;
      debugPrint(
        '[SLEEP] 서버 데이터 사용: totalSleep=${_totalSleepDuration!.inMinutes}분 + awake=${_awakeDuration!.inMinutes}분 = ${totalInBed.inMinutes}분',
      );
      return totalInBed;
    }
    // fallback: segments 기반 계산
    final calculated = _logs.fold(Duration.zero, (sum, e) => sum + e.duration);
    debugPrint('[SLEEP] segments 기반 계산 사용: ${calculated.inMinutes}분');
    return calculated;
  }

  Map<SleepStage, Duration> get _byStage {
    final Map<SleepStage, Duration> m = {};
    for (final l in _logs) {
      m[l.stage] = (m[l.stage] ?? Duration.zero) + l.duration;
    }
    return m;
  }

  double get _sleepEfficiency {
    if (_totalSleep.inMinutes == 0) return 0.0;

    // 서버 데이터가 있으면 서버의 awakeDuration 사용, 없으면 segments 기반 계산
    final awakeTime =
        _awakeDuration ?? (_byStage[SleepStage.awake] ?? Duration.zero);
    final totalInBed =
        _totalSleep; // 이미 totalSleepDuration + awakeDuration으로 계산됨

    if (totalInBed.inMinutes == 0) return 0.0;

    return ((totalInBed.inMinutes - awakeTime.inMinutes) /
            totalInBed.inMinutes *
            100)
        .clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.selectedDate;
    // 수면이 시작된 시간을 기준으로 -6시간을 해서 그 날짜로 데이터 가져오기
    final adjustedDate = d.subtract(const Duration(hours: 6));

    // 디버그 로그 추가
    debugPrint('[SLEEP] 빌드 시 데이터 상태:');
    debugPrint('[SLEEP] _logs 개수: ${_logs.length}');
    debugPrint('[SLEEP] _loading: $_loading');
    debugPrint('[SLEEP] _error: $_error');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '수면차트',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _fetch,
            tooltip: '새로고침',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '수면 데이터를 불러오는 중...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _fetch)
              : RefreshIndicator(
                color: const Color(0xFF6C63FF),
                backgroundColor: const Color(0xFF1D1E33),
                onRefresh: _fetch,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DateHeader(
                              originalDate: d,
                              adjustedDate: adjustedDate,
                              actualDataDate: _actualDataDate,
                              fallbackFromTwoDaysAgo: _fallbackFromTwoDaysAgo,
                            ),
                            const SizedBox(height: 20),
                            // Apple Watch 안내 메시지 (수면 데이터가 없을 때만 표시)
                            if (_logs.isEmpty) ...[
                              _EmptyHint(
                                originalDate: d,
                                adjustedDate: adjustedDate,
                              ),
                              const SizedBox(height: 20),
                            ],
                            _SummaryCard(
                              total: _totalSleep,
                              efficiency: _sleepEfficiency,
                            ),
                            const SizedBox(height: 24),
                            _SleepChartCard(logs: _logs, total: _totalSleep),
                            const SizedBox(height: 24),
                            _QualityHints(
                              byStage: _byStage,
                              total: _totalSleep,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}

/// =======================
/// 위젯 모음 (깔끔한 UI)
/// =======================

class _DateHeader extends StatelessWidget {
  final DateTime originalDate;
  final DateTime adjustedDate;
  final DateTime? actualDataDate;
  final bool fallbackFromTwoDaysAgo;

  const _DateHeader({
    required this.originalDate,
    required this.adjustedDate,
    this.actualDataDate,
    this.fallbackFromTwoDaysAgo = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    if (fallbackFromTwoDaysAgo) {
      // 이틀 전 데이터 사용 중
      startDate = now.subtract(const Duration(days: 2));
      endDate = now.subtract(const Duration(days: 1));
    } else {
      // 일반적인 어제 데이터
      startDate = now.subtract(const Duration(days: 1));
      endDate = now;
    }

    final startW = ['일', '월', '화', '수', '목', '금', '토'][startDate.weekday % 7];
    final endW = ['일', '월', '화', '수', '목', '금', '토'][endDate.weekday % 7];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${startDate.year}년 ${startDate.month}월 ${startDate.day}일 ($startW) ~ ${endDate.month}월 ${endDate.day}일 ($endW)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Duration total;
  final double efficiency;

  const _SummaryCard({required this.total, required this.efficiency});

  String get _quality {
    final h = total.inHours;
    if (h >= 7 && h <= 9) return '💯 최적의 수면';
    if (h >= 6) return '😊 양호한 수면';
    if (h >= 5) return '😐 부족한 수면';
    if (h > 9) return '😴 과다한 수면';
    return '😟 매우 부족한 수면';
  }

  @override
  Widget build(BuildContext context) {
    final h = total.inHours;
    final m = total.inMinutes % 60;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bedtime, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                '총 수면 시간',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$h',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                '시간 ',
                style: TextStyle(fontSize: 20, color: Colors.white70),
              ),
              Text(
                '$m',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                '분',
                style: TextStyle(fontSize: 20, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _quality,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '효율 ${efficiency.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
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
  }
}

class _SleepChartCard extends StatelessWidget {
  final List<SleepLog> logs;
  final Duration total;

  const _SleepChartCard({required this.logs, required this.total});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1E33), Color(0xFF2A2D3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '수면 분석 차트',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sleep Analysis Charts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 원형 차트
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A90E2).withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CustomPaint(
                painter: SleepPieChartPainter(logs: logs, total: total),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 막대 차트
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B68EE).withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CustomPaint(
                painter: SleepBarChartPainter(logs: logs),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ChartLegend(),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = const [
      {'name': '깊은 수면', 'stage': SleepStage.deep, 'icon': Icons.nights_stay},
      {'name': 'REM 수면', 'stage': SleepStage.rem, 'icon': Icons.psychology},
      {'name': '코어 수면', 'stage': SleepStage.light, 'icon': Icons.bedtime},
      {'name': '깨어있음', 'stage': SleepStage.awake, 'icon': Icons.visibility},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        children:
            items.map((e) {
              final s = e['stage'] as SleepStage;
              final icon = e['icon'] as IconData;
              final color = stageColor(s);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e['name'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

class SleepPieChartPainter extends CustomPainter {
  final List<SleepLog> logs;
  final Duration total;

  SleepPieChartPainter({required this.logs, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) * 0.75;

    // 수면 단계별 시간 계산
    final Map<SleepStage, Duration> byStage = {};
    for (final log in logs) {
      byStage[log.stage] = (byStage[log.stage] ?? Duration.zero) + log.duration;
    }

    if (byStage.isEmpty) return;

    double startAngle = -pi / 2; // 12시 방향부터 시작

    for (final stage in SleepStage.values) {
      final duration = byStage[stage] ?? Duration.zero;
      if (duration.inMinutes == 0) continue;

      final sweepAngle = (duration.inMinutes / total.inMinutes) * 2 * pi;

      // 그라디언트 페인트
      final paint =
          Paint()
            ..style = PaintingStyle.fill
            ..shader = RadialGradient(
              colors: [
                _getStageColor(stage),
                _getStageColor(stage).withOpacity(0.7),
              ],
              stops: const [0.0, 1.0],
            ).createShader(Rect.fromCircle(center: center, radius: radius));

      // 호 그리기
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // 테두리 그리기
      final strokePaint =
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        strokePaint,
      );

      // 섹션 라벨 추가
      if (sweepAngle > 0.1) {
        // 너무 작은 섹션은 라벨 생략
        final labelAngle = startAngle + sweepAngle / 2;
        final labelRadius = radius * 0.6;
        final labelX = center.dx + cos(labelAngle) * labelRadius;
        final labelY = center.dy + sin(labelAngle) * labelRadius;

        final labelText = _getStageLabel(stage);
        final labelTextPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              color: _getStageColor(stage),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        labelTextPainter.layout();
        labelTextPainter.paint(
          canvas,
          Offset(
            labelX - labelTextPainter.width / 2,
            labelY - labelTextPainter.height / 2,
          ),
        );
      }

      startAngle += sweepAngle;
    }

    // 중앙 원형 구멍 (그라디언트)
    final centerPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFF2D2D3A), const Color(0xFF1A1A2E)],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 0.4));
    canvas.drawCircle(center, radius * 0.4, centerPaint);

    // 중앙 테두리
    final centerBorderPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius * 0.4, centerBorderPaint);

    // 중앙 텍스트 (그라디언트)
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(total.inHours)}h\n${(total.inMinutes % 60)}m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          shadows: [
            Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 5,
      ),
    );
  }

  Color _getStageColor(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return const Color(0xFF4A90E2);
      case SleepStage.rem:
        return const Color(0xFF7B68EE);
      case SleepStage.light:
        return const Color(0xFF87CEEB);
      case SleepStage.awake:
        return const Color(0xFFFF6B6B);
    }
  }

  String _getStageLabel(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return '깊은';
      case SleepStage.rem:
        return 'REM';
      case SleepStage.light:
        return '코어';
      case SleepStage.awake:
        return '깸';
    }
  }

  @override
  bool shouldRepaint(covariant SleepPieChartPainter oldDelegate) {
    return oldDelegate.logs != logs || oldDelegate.total != total;
  }
}

class SleepBarChartPainter extends CustomPainter {
  final List<SleepLog> logs;

  SleepBarChartPainter({required this.logs});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    // 수면 단계별 시간 계산
    final Map<SleepStage, Duration> byStage = {};
    for (final log in logs) {
      byStage[log.stage] = (byStage[log.stage] ?? Duration.zero) + log.duration;
    }

    if (byStage.isEmpty) return;

    final stages =
        SleepStage.values
            .where((s) => (byStage[s]?.inMinutes ?? 0) > 0)
            .toList();
    if (stages.isEmpty) return;

    final maxDuration = byStage.values.fold(
      Duration.zero,
      (a, b) => a.inMinutes > b.inMinutes ? a : b,
    );
    if (maxDuration.inMinutes == 0) return;

    const padding = 30.0;
    final chartWidth = size.width - (padding * 2);
    final chartHeight = size.height - (padding * 2);
    final barWidth = chartWidth / stages.length * 0.7;
    final barSpacing = chartWidth / stages.length;

    for (int i = 0; i < stages.length; i++) {
      final stage = stages[i];
      final duration = byStage[stage]!;
      final barHeight =
          (duration.inMinutes / maxDuration.inMinutes) * chartHeight;

      final x = padding + (barSpacing * i) + (barSpacing - barWidth) / 2;
      final y = padding + chartHeight - barHeight;

      // 그라디언트 바 (더 세련된 그라디언트)
      final paint =
          Paint()
            ..style = PaintingStyle.fill
            ..shader = LinearGradient(
              colors: [
                _getStageColor(stage),
                _getStageColor(stage).withOpacity(0.8),
                _getStageColor(stage).withOpacity(0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        paint,
      );

      // 내부 하이라이트
      final highlightPaint =
          Paint()
            ..style = PaintingStyle.fill
            ..shader = LinearGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight * 0.4));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight * 0.4),
          const Radius.circular(12),
        ),
        highlightPaint,
      );

      // 테두리 (더 세련된)
      final strokePaint =
          Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        strokePaint,
      );

      // 수면 단계 라벨 (더 예쁘게)
      final labelText = _getStageLabel(stage);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: _getStageColor(stage),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, y + barHeight + 8),
      );

      // 시간 라벨 (더 예쁘게)
      final timeText = '${duration.inHours}h ${duration.inMinutes % 60}m';
      final timeTextPainter = TextPainter(
        text: TextSpan(
          text: timeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      timeTextPainter.layout();
      timeTextPainter.paint(
        canvas,
        Offset(x + (barWidth - timeTextPainter.width) / 2, y - 25),
      );
    }
  }

  Color _getStageColor(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return const Color(0xFF4A90E2);
      case SleepStage.rem:
        return const Color(0xFF7B68EE);
      case SleepStage.light:
        return const Color(0xFF87CEEB);
      case SleepStage.awake:
        return const Color(0xFFFF6B6B);
    }
  }

  String _getStageLabel(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return '깊은';
      case SleepStage.rem:
        return 'REM';
      case SleepStage.light:
        return '코어';
      case SleepStage.awake:
        return '깸';
    }
  }

  @override
  bool shouldRepaint(covariant SleepBarChartPainter oldDelegate) {
    return oldDelegate.logs != logs;
  }
}

class SleepChartPainter extends CustomPainter {
  final List<SleepLog> logs;

  SleepChartPainter({required this.logs});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withOpacity(0.4);

    // 시간 범위 계산
    final startTime = logs.first.start;
    final endTime = logs.last.end;
    final totalDuration = endTime.difference(startTime).inMinutes;

    if (totalDuration == 0) return;

    // 차트 영역 설정
    const chartPadding = 30.0;
    final chartWidth = size.width - (chartPadding * 2);
    final chartHeight = size.height - 60;

    // 배경 그리기
    final backgroundPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.fill;

    final backgroundRect = Rect.fromLTWH(
      chartPadding,
      chartPadding,
      chartWidth,
      chartHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(8)),
      backgroundPaint,
    );

    // 각 로그를 시간대별로 그리기
    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      final startOffset = startTime.difference(log.start).inMinutes.abs();
      final duration = log.duration.inMinutes;

      final x = chartPadding + (startOffset / totalDuration) * chartWidth;
      final width = (duration / totalDuration) * chartWidth;
      final y = chartPadding;
      final height = chartHeight;

      // 수면 단계별 색상
      final stageColor = _getStageColor(log.stage);

      // 그라디언트 적용
      final rect = Rect.fromLTWH(x, y, width, height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      // 그라디언트 셰이더 생성
      final shader = LinearGradient(
        colors: [stageColor, stageColor.withOpacity(0.7)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

      paint.shader = shader;
      canvas.drawRRect(rrect, paint);
      paint.shader = null;

      // 테두리 그리기
      canvas.drawRRect(rrect, strokePaint);

      // 시간 라벨 (1시간 간격)
      if (i % 4 == 0 && width > 30) {
        final timeText =
            '${log.start.hour.toString().padLeft(2, '0')}:${log.start.minute.toString().padLeft(2, '0')}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: timeText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y + height + 8));
      }
    }

    // 시간축 그리기
    final axisPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.4)
          ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(chartPadding, chartPadding + chartHeight),
      Offset(chartPadding + chartWidth, chartPadding + chartHeight),
      axisPaint,
    );

    // Y축 그리기
    canvas.drawLine(
      Offset(chartPadding, chartPadding),
      Offset(chartPadding, chartPadding + chartHeight),
      axisPaint,
    );

    // 수면 단계 라벨 추가
    _drawStageLabels(canvas, chartPadding, chartHeight);
  }

  Color _getStageColor(SleepStage stage) {
    switch (stage) {
      case SleepStage.deep:
        return const Color(0xFF4A90E2); // 깊은 수면 - 짙은 파란색
      case SleepStage.rem:
        return const Color(0xFF7B68EE); // REM 수면 - 보라색
      case SleepStage.light:
        return const Color(0xFF87CEEB); // 얕은 수면 - 연한 파란색
      case SleepStage.awake:
        return const Color(0xFFFF6B6B); // 깨어있음 - 빨간색
    }
  }

  void _drawStageLabels(
    Canvas canvas,
    double chartPadding,
    double chartHeight,
  ) {
    final labels = ['깊은', 'REM', '코어', '깨어'];
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF5E35B1),
      const Color(0xFF42A5F5),
      const Color(0xFFEF5350),
    ];

    for (int i = 0; i < labels.length; i++) {
      final y = chartPadding + (chartHeight / 4) * i + 10;

      // 색상 점
      final dotPaint =
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(chartPadding - 15, y), 4, dotPaint);

      // 라벨 텍스트
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: colors[i],
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartPadding - 25, y - 6));
    }
  }

  @override
  bool shouldRepaint(covariant SleepChartPainter oldDelegate) {
    return oldDelegate.logs != logs;
  }
}

class _QualityHints extends StatelessWidget {
  final Map<SleepStage, Duration> byStage;
  final Duration total;

  const _QualityHints({required this.byStage, required this.total});

  @override
  Widget build(BuildContext context) {
    final deep = byStage[SleepStage.deep] ?? Duration.zero;
    final rem = byStage[SleepStage.rem] ?? Duration.zero;
    final light = byStage[SleepStage.light] ?? Duration.zero;
    final awake = byStage[SleepStage.awake] ?? Duration.zero;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.insights, color: Colors.white70, size: 24),
              SizedBox(width: 8),
              Text(
                '수면 품질 지표',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _qualityItem(
            title: '깊은 수면',
            value: '${deep.inHours}시간 ${deep.inMinutes % 60}분',
            status: deep.inMinutes >= 90 ? '좋음' : '개선 필요',
            color: deep.inMinutes >= 90 ? Colors.green : Colors.orange,
            icon: Icons.nights_stay,
            description: '90분 이상 권장',
          ),
          const SizedBox(height: 16),
          _qualityItem(
            title: 'REM 수면',
            value: '${rem.inHours}시간 ${rem.inMinutes % 60}분',
            status: rem.inMinutes >= 60 ? '적절함' : '부족',
            color: rem.inMinutes >= 60 ? Colors.blue : Colors.orange,
            icon: Icons.psychology,
            description: '60분 이상 권장',
          ),
          const SizedBox(height: 16),
          _qualityItem(
            title: '코어 수면',
            value: '${light.inHours}시간 ${light.inMinutes % 60}분',
            status: light.inMinutes >= 120 ? '적절함' : '부족',
            color: light.inMinutes >= 120 ? Colors.cyan : Colors.orange,
            icon: Icons.bedtime,
            description: '120분 이상 권장',
          ),
          const SizedBox(height: 16),
          _qualityItem(
            title: '수면 중 깨어있던 시간',
            value: '${awake.inMinutes}분',
            status: awake.inMinutes < 30 ? '양호' : '많음',
            color: awake.inMinutes < 30 ? Colors.green : Colors.red,
            icon: Icons.visibility,
            description: '30분 이하 권장',
          ),
        ],
      ),
    );
  }

  Widget _qualityItem({
    required String title,
    required String value,
    required String status,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.4), width: 1),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final DateTime originalDate;
  final DateTime adjustedDate;

  const _EmptyHint({required this.originalDate, required this.adjustedDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D1E33), Color(0xFF2A2D3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Apple Watch 아이콘
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.watch, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),

          // 메인 제목
          Text(
            'Apple Watch가 필요해요',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 설명 텍스트
          Text(
            '수면 데이터는 Apple Watch로 측정됩니다.\nApple Watch를 차고 자지 않으면\n수면 데이터가 수집되지 않아요.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '오류가 발생했습니다',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
