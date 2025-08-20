import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// =======================
/// 모델 & 유틸
/// =======================

enum SleepStage { deep, rem, light, core, awake }

class SleepLog {
  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  SleepLog({required this.start, required this.end, required this.stage});

  Duration get duration => end.difference(start);
}

class SleepSegment {
  final double startMinute; // baseTime으로부터 분
  final double endMinute;
  final SleepStage stage;

  SleepSegment({
    required this.startMinute,
    required this.endMinute,
    required this.stage,
  });
}

String _ymd(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

DateTime _parseTs(dynamic v) {
  if (v is int) {
    // epoch(ms) 가정
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
  }
  if (v is String) {
    final p = DateTime.tryParse(v);
    if (p != null) return p.toLocal();
    final asInt = int.tryParse(v);
    if (asInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true).toLocal();
    }
  }
  throw FormatException('Invalid datetime: $v');
}

SleepStage _parseStage(dynamic v) {
  final s = v.toString().toUpperCase();
  if (s.contains('DEEP')) return SleepStage.deep;
  if (s.contains('REM')) return SleepStage.rem;
  if (s.contains('AWAKE') || s == 'WAKE') return SleepStage.awake;
  if (s.contains('CORE')) return SleepStage.core;
  // HealthDataType.SLEEP_LIGHT / SLEEP_ASLEEP / LIGHT 등은 light로
  return SleepStage.light;
}

Color stageColor(SleepStage s) {
  switch (s) {
    case SleepStage.deep:
      return const Color(0xFF5E35B1);
    case SleepStage.rem:
      return const Color(0xFF29B6F6);
    case SleepStage.light:
      return const Color(0xFF42A5F5);
    case SleepStage.core:
      return const Color(0xFF66BB6A);
    case SleepStage.awake:
      return const Color(0xFFEF5350);
  }
}

/// =======================
/// 차트 Painter
/// =======================

class SleepTimelinePainter extends CustomPainter {
  final List<SleepSegment> segments;
  final double totalWidth; // px 기준 전체 가로폭 (예: 1080)
  final double trackHeight;

  SleepTimelinePainter({
    required this.segments,
    required this.totalWidth,
    this.trackHeight = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, totalWidth, trackHeight),
      const Radius.circular(8),
    );

    // 바탕 트랙
    final basePaint =
        Paint()
          ..color = const Color(0xFF12152A)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRect, basePaint);

    // 구간 칠하기
    for (final seg in segments) {
      final left = max(0.0, seg.startMinute / (60 * 12) * totalWidth);
      final right = min(totalWidth, seg.endMinute / (60 * 12) * totalWidth);
      if (right <= left) continue;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, right - left, trackHeight),
        const Radius.circular(6),
      );
      final paint = Paint()..color = stageColor(seg.stage);
      canvas.drawRRect(rrect, paint);
    }

    // 격자/눈금선 (3시간 간격)
    final gridPaint =
        Paint()
          ..color = Colors.white10
          ..strokeWidth = 1;
    for (int i = 0; i <= 6; i++) {
      final x = (i / 6) * totalWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, trackHeight), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SleepTimelinePainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.totalWidth != totalWidth ||
        oldDelegate.trackHeight != trackHeight;
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

class _SleepChartScreenState extends State<SleepChartScreen> {
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  String? _error;
  List<SleepLog> _logs = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final uid =
          await _storage.read(key: 'userID') ??
          await _storage.read(key: 'userId');
      if (uid == null || uid.trim().isEmpty) {
        throw Exception('로그인이 필요합니다. (userID 없음)');
      }
      setState(() => _userId = uid.trim());
      await _fetch();
    } catch (e) {
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

  Future<void> _fetch() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final dateStr = _ymd(widget.selectedDate);
      final url = Uri.parse(
        'https://kooala.tassoo.uk/sleep-data/${Uri.encodeComponent(_userId!)}/$dateStr',
      );

      final resp = await http.get(url, headers: await _headers());
      // 디버그 로그
      // debugPrint('[SLEEP] GET $url -> ${resp.statusCode} ${resp.body}');

      if (resp.statusCode == 401) {
        throw Exception('인증 만료됨(401). 다시 로그인해주세요.');
      }
      if (resp.statusCode == 404) {
        // 데이터 없을 때는 빈 배열 처리
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

      // 유연한 파싱: data/items/top-level list 중 존재하는 걸 사용
      final rawList =
          (decoded is List)
              ? decoded
              : (decoded['data'] ?? decoded['items'] ?? decoded['sleep'] ?? []);

      final List<SleepLog> logs = [];
      for (final item in (rawList as List)) {
        final m = (item as Map).map((k, v) => MapEntry(k.toString(), v));
        final start = _parseTs(m['start'] ?? m['startTime'] ?? m['from']);
        final end = _parseTs(m['end'] ?? m['endTime'] ?? m['to']);
        final stage = _parseStage(m['type'] ?? m['stage'] ?? m['sleepType']);
        if (end.isAfter(start)) {
          logs.add(SleepLog(start: start, end: end, stage: stage));
        }
      }

      if (!mounted) return;
      setState(() {
        _logs = logs..sort((a, b) => a.start.compareTo(b.start));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// baseTime = 선택 날짜의 00:00 - 6시간 (전날 18시) ~ 다음날 12:00 까지 18시간 윈도우
  DateTime _baseTime(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(const Duration(hours: 6));

  List<SleepSegment> _toSegments(List<SleepLog> logs, DateTime base) {
    return logs.map((e) {
      final s = e.start.difference(base).inMinutes.toDouble();
      final ed = e.end.difference(base).inMinutes.toDouble();
      return SleepSegment(startMinute: s, endMinute: ed, stage: e.stage);
    }).toList();
  }

  Duration get _totalSleep =>
      _logs.fold(Duration.zero, (sum, e) => sum + e.duration);

  Map<SleepStage, Duration> get _byStage {
    final Map<SleepStage, Duration> m = {};
    for (final l in _logs) {
      m[l.stage] = (m[l.stage] ?? Duration.zero) + l.duration;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.selectedDate;
    final base = _baseTime(d);
    final segments = _toSegments(_logs, base);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '수면 분석',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetch,
            tooltip: '새로고침',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _fetch)
              : RefreshIndicator(
                color: const Color(0xFF6C63FF),
                backgroundColor: const Color(0xFF1D1E33),
                onRefresh: _fetch,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DateHeader(date: d),
                        const SizedBox(height: 20),
                        _SummaryCard(total: _totalSleep),
                        const SizedBox(height: 24),
                        _TimelineCard(segments: segments, baseTime: base),
                        const SizedBox(height: 24),
                        _StageBreakdown(byStage: _byStage),
                        const SizedBox(height: 24),
                        _QualityHints(byStage: _byStage, total: _totalSleep),
                        if (_logs.isEmpty) ...[
                          const SizedBox(height: 24),
                          _EmptyHint(date: d),
                        ],
                      ],
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
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final w = ['일', '월', '화', '수', '목', '금', '토'][date.weekday % 7];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            '${date.year}년 ${date.month}월 ${date.day}일 ($w)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Duration total;
  const _SummaryCard({required this.total});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final List<SleepSegment> segments;
  final DateTime baseTime;

  const _TimelineCard({required this.segments, required this.baseTime});

  @override
  Widget build(BuildContext context) {
    const width = 1080.0; // 가로 스크롤 기준 총 폭(픽셀)
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
              Icon(Icons.timeline, color: Colors.white70, size: 24),
              SizedBox(width: 8),
              Text(
                '수면 단계 타임라인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: const Color(0xFF0A0E21),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: width,
                        height: 24,
                        child: CustomPaint(
                          painter: SleepTimelinePainter(
                            segments: segments,
                            totalWidth: width,
                            trackHeight: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: width,
                        height: 24,
                        child: Stack(
                          children: List.generate(7, (i) {
                            // 18시 기준 3시간 간격
                            final hour = (18 + i * 3) % 24;
                            final label =
                                '${hour.toString().padLeft(2, '0')}:00';
                            final left = (i / 6) * width;
                            return Positioned(
                              left: left - 18,
                              top: 0,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
      {'name': '얕은 수면', 'stage': SleepStage.light},
      {'name': '코어 수면', 'stage': SleepStage.core},
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: stageColor(s),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stageName(s),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.inHours}시간 ${d.inMinutes % 60}분',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: stageColor(s).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: stageColor(s),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(stageColor(s)),
                minHeight: 6,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pie_chart, color: Colors.white70, size: 24),
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
          const SizedBox(height: 14),
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
        return '얕은 수면';
      case SleepStage.core:
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
    final awake = byStage[SleepStage.awake] ?? Duration.zero;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 16),
          _qualityItem(
            title: '깊은 수면',
            value: '${deep.inHours}시간 ${deep.inMinutes % 60}분',
            status: deep.inMinutes >= 90 ? '좋음' : '개선 필요',
            color: deep.inMinutes >= 90 ? Colors.green : Colors.orange,
            icon: Icons.nights_stay,
          ),
          const SizedBox(height: 12),
          _qualityItem(
            title: 'REM 수면',
            value: '${rem.inHours}시간 ${rem.inMinutes % 60}분',
            status: rem.inMinutes >= 60 ? '적절함' : '부족',
            color: rem.inMinutes >= 60 ? Colors.blue : Colors.orange,
            icon: Icons.psychology,
          ),
          const SizedBox(height: 12),
          _qualityItem(
            title: '수면 중 깨어있던 시간',
            value: '${awake.inMinutes}분',
            status: awake.inMinutes < 30 ? '양호' : '많음',
            color: awake.inMinutes < 30 ? Colors.green : Colors.red,
            icon: Icons.visibility,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final DateTime date;
  const _EmptyHint({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_ymd(date)} 수면 데이터가 없습니다.',
              style: const TextStyle(color: Colors.white70),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
