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

DateTime _parseTs(dynamic v) {
  // null 체크 추가
  if (v == null) {
    throw FormatException('DateTime 값이 null입니다');
  }

  if (v is int) {
    // epoch(ms) 가정
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
  }
  if (v is String) {
    if (v.trim().isEmpty) {
      throw FormatException('DateTime 문자열이 비어있습니다: "$v"');
    }
    final p = DateTime.tryParse(v);
    if (p != null) return p.toLocal();
    final asInt = int.tryParse(v);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true).toLocal();
    }
  }
  throw FormatException('Invalid datetime: $v (타입: ${v.runtimeType})');
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
/// 원형 파이 차트 Painter
/// =======================

class SleepPieChartPainter extends CustomPainter {
  final Map<SleepStage, Duration> byStage;
  final Duration total;

  SleepPieChartPainter({required this.byStage, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.8;

    if (total.inMinutes == 0) return;

    double startAngle = -pi / 2; // 12시 방향부터 시작

    for (final stage in SleepStage.values) {
      final duration = byStage[stage] ?? Duration.zero;
      if (duration.inMinutes == 0) continue;

      final sweepAngle = (duration.inMinutes / total.inMinutes) * 2 * pi;

      final paint =
          Paint()
            ..color = stageColor(stage)
            ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // 중앙 원형 구멍
    final centerPaint =
        Paint()
          ..color = const Color(0xFF0A0E21)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant SleepPieChartPainter oldDelegate) {
    return oldDelegate.byStage != byStage || oldDelegate.total != total;
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
        raw.startsWith(RegExp(r'Bearer\\s', caseSensitive: false))
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

      final apiDay = _apiDate(widget.selectedDate);
      final dateStr = _ymd(apiDay);

      debugPrint('[SLEEP] 선택된 날짜(표시용): ${_ymd(widget.selectedDate)}');
      debugPrint('[SLEEP] API 조회 날짜(전날): $dateStr');
      debugPrint('[SLEEP] 사용자 ID: $_userId');

      final url = Uri.parse(
        'https://kooala.tassoo.uk/sleep-data/${Uri.encodeComponent(_userId!)}/$dateStr',
      );

      debugPrint('[SLEEP] API URL: $url');

      final headers = await _headers();
      debugPrint('[SLEEP] Headers: $headers');

      final resp = await http.get(url, headers: headers);
      // 디버그 로그
      debugPrint('[SLEEP] GET $url -> ${resp.statusCode}');
      debugPrint('[SLEEP] Response body: ${resp.body}');

      if (resp.statusCode == 401) {
        throw Exception('인증 만료됨(401). 다시 로그인해주세요.');
      }
      if (resp.statusCode == 404) {
        // 데이터 없을 때는 빈 배열 처리
        debugPrint('[SLEEP] 404 - 데이터가 없습니다');
        setState(() {
          _logs = [];
          _loading = false;
        });
        return;
      }
      if (resp.statusCode != 200) {
        throw Exception(
          'HTTP ${resp.statusCode}: ${resp.body.isNotEmpty ? resp.body : 'Unknown error'}',
        );
      }

      final decoded = json.decode(resp.body);
      debugPrint('[SLEEP] 디코딩된 응답: $decoded');

      // API 응답 구조에 맞게 파싱
      final dataList = decoded['data'] as List? ?? [];
      debugPrint('[SLEEP] 데이터 리스트: $dataList');
      debugPrint('[SLEEP] 데이터 개수: ${dataList.length}');

      final List<SleepLog> logs = [];
      Duration? totalSleepDuration; // 서버의 totalSleepDuration 저장

      for (int i = 0; i < dataList.length; i++) {
        try {
          final sleepData = dataList[i] as Map<String, dynamic>;
          debugPrint('[SLEEP] 수면 데이터 $i: $sleepData');

          // totalSleepDuration 가져오기 (수면분석과 동일한 값 사용)
          if (totalSleepDuration == null) {
            final durationBlock =
                sleepData['Duration'] as Map<String, dynamic>?;
            if (durationBlock != null) {
              final totalMinutes =
                  durationBlock['totalSleepDuration'] as int? ?? 0;
              final awakeMinutes = durationBlock['awakeDuration'] as int? ?? 0;
              // 수면분석과 동일하게: 실제 수면시간 + 깨어있는 시간
              final inBedMinutes = totalMinutes + awakeMinutes;
              totalSleepDuration = Duration(minutes: inBedMinutes);
              debugPrint(
                '[SLEEP] totalSleepDuration: $totalMinutes분, awakeDuration: $awakeMinutes분, inBedTotal: $inBedMinutes분',
              );
            }
          }

          // segments 배열에서 각 수면 단계별 정보 파싱
          final segments = sleepData['segments'] as List? ?? [];
          debugPrint('[SLEEP] segments 개수: ${segments.length}');

          for (int j = 0; j < segments.length; j++) {
            try {
              final segment = segments[j] as Map<String, dynamic>;
              debugPrint('[SLEEP] segment $j: $segment');

              final startTimeStr = segment['startTime'] as String?;
              final endTimeStr = segment['endTime'] as String?;
              final stageStr = segment['stage'] as String?;

              if (startTimeStr == null ||
                  endTimeStr == null ||
                  stageStr == null) {
                debugPrint('[SLEEP] segment $j: 필수 필드가 null입니다');
                continue;
              }

              debugPrint(
                '[SLEEP] segment $j: startTime=$startTimeStr, endTime=$endTimeStr, stage=$stageStr',
              );

              // 날짜 정보 가져오기 (API 응답의 date 필드 사용)
              final dateStr = sleepData['date'] as String?;
              if (dateStr == null) {
                debugPrint('[SLEEP] date 필드가 null입니다');
                continue;
              }

              final date = DateTime.parse(dateStr);
              debugPrint('[SLEEP] 파싱된 날짜: $date');

              // 시간 문자열을 DateTime으로 변환
              final start = _parseTimeWithDate(startTimeStr, date);
              final end = _parseTimeWithDate(endTimeStr, date);
              final stage = _parseStage(stageStr);

              debugPrint(
                '[SLEEP] 변환된 시간: start=$start, end=$end, stage=$stage',
              );

              // 수면 시간이 유효한지 확인
              if (end.isAfter(start)) {
                logs.add(SleepLog(start: start, end: end, stage: stage));
                debugPrint(
                  '[SLEEP] 유효한 수면 로그 추가: ${start} ~ ${end} (${stage})',
                );
              } else {
                debugPrint('[SLEEP] 유효하지 않은 수면 시간: ${start} ~ ${end}');
              }
            } catch (e) {
              debugPrint('[SLEEP] segment $j 파싱 실패: $e');
              continue;
            }
          }
        } catch (e) {
          debugPrint('[SLEEP] 수면 데이터 $i 파싱 실패: $e');
          continue;
        }
      }

      if (!mounted) return;
      setState(() {
        _logs = logs..sort((a, b) => a.start.compareTo(b.start));
        _totalSleepDuration = totalSleepDuration;
        _loading = false;
      });

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
    // 서버의 totalSleepDuration을 우선 사용 (수면분석과 동일한 값)
    if (_totalSleepDuration != null) {
      debugPrint(
        '[SLEEP] totalSleepDuration 사용: ${_totalSleepDuration!.inMinutes}분',
      );
      return _totalSleepDuration!;
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

    final totalInBed = _logs.fold(Duration.zero, (sum, e) => sum + e.duration);
    final awakeTime = _byStage[SleepStage.awake] ?? Duration.zero;

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
                            ),
                            const SizedBox(height: 20),
                            _SummaryCard(
                              total: _totalSleep,
                              efficiency: _sleepEfficiency,
                            ),
                            const SizedBox(height: 24),
                            _PieChartCard(
                              byStage: _byStage,
                              total: _totalSleep,
                            ),
                            const SizedBox(height: 24),
                            _StageBreakdown(byStage: _byStage),
                            const SizedBox(height: 24),
                            _QualityHints(
                              byStage: _byStage,
                              total: _totalSleep,
                            ),
                            if (_logs.isEmpty) ...[
                              const SizedBox(height: 24),
                              _EmptyHint(
                                originalDate: d,
                                adjustedDate: adjustedDate,
                              ),
                            ] else ...[
                              const SizedBox(height: 24),
                            ],
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

  const _DateHeader({required this.originalDate, required this.adjustedDate});

  @override
  Widget build(BuildContext context) {
    final w = ['일', '월', '화', '수', '목', '금', '토'][originalDate.weekday % 7];
    final adjustedW =
        ['일', '월', '화', '수', '목', '금', '토'][adjustedDate.weekday % 7];

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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                '${originalDate.year}년 ${originalDate.month}월 ${originalDate.day}일 ($w)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

class _PieChartCard extends StatelessWidget {
  final Map<SleepStage, Duration> byStage;
  final Duration total;

  const _PieChartCard({required this.byStage, required this.total});

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.pie_chart, color: Colors.white70, size: 24),
              SizedBox(width: 8),
              Text(
                '수면 단계 분포',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: SleepPieChartPainter(byStage: byStage, total: total),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Legend(),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = const [
      {'name': '깊은 수면', 'stage': SleepStage.deep},
      {'name': 'REM 수면', 'stage': SleepStage.rem},
      {'name': '코어 수면', 'stage': SleepStage.light},
      {'name': '깨어있음', 'stage': SleepStage.awake},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children:
          items.map((e) {
            final s = e['stage'] as SleepStage;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: stageColor(s),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e['name'] as String,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            );
          }).toList(),
    );
  }
}

class _StageBreakdown extends StatelessWidget {
  final Map<SleepStage, Duration> byStage;
  const _StageBreakdown({required this.byStage});

  @override
  Widget build(BuildContext context) {
    final total = byStage.values.fold(Duration.zero, (p, e) => p + e);
    List<Widget> rows = [];
    for (final s in SleepStage.values) {
      final d = byStage[s] ?? Duration.zero;
      final pct =
          total.inMinutes > 0
              ? (d.inMinutes / total.inMinutes * 100).round()
              : 0;
      if (d == Duration.zero) continue;

      rows.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E21),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stageColor(s).withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 50,
                        decoration: BoxDecoration(
                          color: stageColor(s),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: stageColor(s).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stageName(s),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${d.inHours}시간 ${d.inMinutes % 60}분',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: stageColor(s).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: stageColor(s).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stageColor(s),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [stageColor(s), stageColor(s).withOpacity(0.8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: stageColor(s).withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              Icon(Icons.analytics, color: Colors.white70, size: 24),
              SizedBox(width: 8),
              Text(
                '수면 단계별 분석',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...rows,
        ],
      ),
    );
  }

  String _stageName(SleepStage s) {
    switch (s) {
      case SleepStage.deep:
        return '깊은 수면';
      case SleepStage.rem:
        return 'REM 수면';
      case SleepStage.light:
        return '코어 수면';

      case SleepStage.awake:
        return '깨어있음';
    }
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.bedtime_outlined,
              color: Colors.blue,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '수면 데이터가 없습니다',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_ymd(originalDate)} 날짜의 수면 기록이 없습니다.\n수면을 측정해보세요!',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              'API 호출: ${_ymd(adjustedDate)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
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
