// lib/sleep_dashboard/sleep_score_details.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:health/health.dart';

class SleepScoreArgs {
  final List<HealthDataPoint> data;
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final Duration goalSleepDuration;
  final int finalScore;

  SleepScoreArgs({
    required this.data,
    required this.sleepStart,
    required this.sleepEnd,
    required this.goalSleepDuration,
    required this.finalScore,
  });
}

class SleepScoreDetailsPage extends StatefulWidget {
  final List<HealthDataPoint> data;
  final DateTime sleepStart; // 점수계산에 사용한 시작
  final DateTime sleepEnd; // 점수계산에 사용한 끝
  final Duration goalSleepDuration; // 목표 수면시간
  final int finalScore; // 최종 점수(원화면 표시값)

  const SleepScoreDetailsPage({
    Key? key,
    required this.data,
    required this.sleepStart,
    required this.sleepEnd,
    required this.goalSleepDuration,
    required this.finalScore,
  }) : super(key: key);

  @override
  State<SleepScoreDetailsPage> createState() => _SleepScoreDetailsPageState();
}

class _SleepScoreDetailsPageState extends State<SleepScoreDetailsPage> {
  // 원본 계산과 동일한 지표들
  int deepMin = 0, remMin = 0, lightMin = 0, awakeMin = 0;
  int wakeEpisodes = 0, transitions = 0, longDeepSegments = 0;

  // 파생값/페널티
  late int totalSleepMin; // deep+rem+light
  late int inBedMinutes; // (참고용) 화면에 보여줄 총 체류시간 = totalSleepMin + awakeMin
  late int timePenalty,
      structurePenalty,
      earlyDeepPenalty,
      wakePenalty,
      transitionPenalty,
      deepSegPenalty;
  late int recomputedScore;

  double deepPct = 0, remPct = 0, lightPct = 0;
  double earlyDeepRatio = 0;
  double transitionRate = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  bool _isSleepType(HealthDataType t) =>
      t == HealthDataType.SLEEP_ASLEEP ||
      t == HealthDataType.SLEEP_LIGHT ||
      t == HealthDataType.SLEEP_DEEP ||
      t == HealthDataType.SLEEP_REM;

  void _compute() {
    // 1) 정렬
    final data = [...widget.data]
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    // 2) 기본 합계/카운트
    HealthDataPoint? prev;
    for (final d in data) {
      final minutes = d.dateTo.difference(d.dateFrom).inMinutes;
      switch (d.type) {
        case HealthDataType.SLEEP_DEEP:
          deepMin += minutes;
          if (minutes >= 30) longDeepSegments++;
          break;
        case HealthDataType.SLEEP_REM:
          remMin += minutes;
          break;
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_ASLEEP:
          lightMin += minutes;
          break;
        case HealthDataType.SLEEP_AWAKE:
          awakeMin += minutes;
          wakeEpisodes++;
          break;
        default:
          break;
      }
      if (prev != null && prev.type != d.type) transitions++;
      prev = d;
    }

    totalSleepMin = deepMin + remMin + lightMin;
    inBedMinutes = totalSleepMin + awakeMin;

    // 3) 시간 감점 (현재 구현 로직 그대로)
    final totalMinutes =
        widget.sleepEnd.difference(widget.sleepStart).inMinutes;
    final goalMinutes = widget.goalSleepDuration.inMinutes;
    int timeDeficit = max(0, goalMinutes - totalMinutes);
    timePenalty = (((timeDeficit) / 60).ceil() * 20).clamp(0, 40);

    // 4) 수면 구조 감점
    if (totalSleepMin > 0) {
      deepPct = deepMin / totalSleepMin;
      remPct = remMin / totalSleepMin;
      lightPct = lightMin / totalSleepMin;
      final diffSum =
          (deepPct - 0.2).abs() + (remPct - 0.2).abs() + (lightPct - 0.6).abs();
      structurePenalty = ((diffSum / 0.1).round() * 10).clamp(0, 30);
    } else {
      structurePenalty = 30; // 데이터가 전무하면 최대로 본다
    }

    // 5) 초반 40% deep 분포
    final sleepDur = widget.sleepEnd.difference(widget.sleepStart);
    final earlyEnd = widget.sleepStart.add(sleepDur * 0.4);
    int earlyDeepMin = 0;
    for (final d in data) {
      if (d.type == HealthDataType.SLEEP_DEEP &&
          d.dateFrom.isBefore(earlyEnd)) {
        final end = d.dateTo.isAfter(earlyEnd) ? earlyEnd : d.dateTo;
        earlyDeepMin += end.difference(d.dateFrom).inMinutes.clamp(0, 1 << 31);
      }
    }
    earlyDeepRatio = deepMin > 0 ? earlyDeepMin / deepMin : 0;
    earlyDeepPenalty = earlyDeepRatio < 0.8 ? 8 : 0;

    // 6) 깸 에피소드 감점
    wakePenalty = (wakeEpisodes * 5).clamp(0, 10);

    // 7) 전환율 감점
    final hours = totalSleepMin / 60.0;
    transitionRate = hours > 0 ? transitions / hours : 0;
    transitionPenalty = transitionRate >= 5 ? 5 : 0;

    // 8) 긴 deep 세그먼트 부재 감점
    deepSegPenalty = (longDeepSegments == 0) ? 10 : 0;

    // 9) 최종 점수
    recomputedScore = (100 -
            timePenalty -
            structurePenalty -
            earlyDeepPenalty -
            wakePenalty -
            transitionPenalty -
            deepSegPenalty)
        .clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final hInBed = inBedMinutes ~/ 60, mInBed = inBedMinutes % 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('수면점수 자세히 보기'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 헤더: 점수
            _ScoreHeader(
              finalScoreFromCaller: widget.finalScore,
              recomputedScore: recomputedScore,
            ),
            const SizedBox(height: 16),

            // 요약칩
            _SummaryChips(
              inBedText: '${hInBed}시간 ${mInBed}분',
              deepMin: deepMin,
              remMin: remMin,
              lightMin: lightMin,
              awakeMin: awakeMin,
              goalText:
                  '${widget.goalSleepDuration.inHours}시간 ${widget.goalSleepDuration.inMinutes % 60}분',
            ),
            const SizedBox(height: 20),

            // 감점 내역
            _PenaltyCard(
              title: '시간(목표 대비) 감점',
              subtitle: '목표보다 부족한 시간 1시간당 20점, 최대 40점',
              value: -timePenalty,
            ),
            _StructureCard(
              deepPct: deepPct,
              remPct: remPct,
              lightPct: lightPct,
              penalty: structurePenalty,
            ),
            _PenaltyCard(
              title: '초반 깊은수면 분포',
              subtitle: '첫 40% 구간의 deep 비중이 80% 미만이면 -8',
              value: -earlyDeepPenalty,
              extra:
                  '초반 deep 비중: ${(earlyDeepRatio * 100).toStringAsFixed(0)}%',
            ),
            _PenaltyCard(
              title: '깸(awake) 에피소드',
              subtitle: '에피소드 1회당 -5, 최대 -10',
              value: -wakePenalty,
              extra: '깸 횟수: $wakeEpisodes 회',
            ),
            _PenaltyCard(
              title: '수면 단계 전환 빈도',
              subtitle: '시간당 전환수 ≥ 5 이면 -5',
              value: -transitionPenalty,
              extra: '전환율: ${transitionRate.toStringAsFixed(1)} 회/시간',
            ),
            _PenaltyCard(
              title: '긴 깊은수면(≥30분) 부재',
              subtitle: '없으면 -10',
              value: -deepSegPenalty,
              extra: '30분↑ deep 세그먼트: $longDeepSegments 개',
            ),
            const SizedBox(height: 20),

            // 안내
            _Hint(),
          ],
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final int finalScoreFromCaller;
  final int recomputedScore;
  const _ScoreHeader({
    required this.finalScoreFromCaller,
    required this.recomputedScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('오늘의 수면점수', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$finalScoreFromCaller',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(재계산: $recomputedScore)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  final String inBedText;
  final int deepMin, remMin, lightMin, awakeMin;
  final String goalText;

  const _SummaryChips({
    required this.inBedText,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.awakeMin,
    required this.goalText,
  });

  String _fmt(int m) => '${m ~/ 60}시간 ${m % 60}분';

  @override
  Widget build(BuildContext context) {
    Widget chip(Color c, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(const Color(0xFF29B6F6), '총 체류시간 $inBedText'),
        chip(const Color(0xFF5E35B1), '깊은수면 ${_fmt(deepMin)}'),
        chip(const Color(0xFF29B6F6), 'REM ${_fmt(remMin)}'),
        chip(const Color(0xFF42A5F5), '얕은수면 ${_fmt(lightMin)}'),
        chip(const Color(0xFFEF5350), '깨어있음 ${_fmt(awakeMin)}'),
        chip(const Color(0xFFFFD54F), '목표 $goalText'),
      ],
    );
  }
}

class _StructureCard extends StatelessWidget {
  final double deepPct, remPct, lightPct;
  final int penalty;
  const _StructureCard({
    required this.deepPct,
    required this.remPct,
    required this.lightPct,
    required this.penalty,
  });

  Widget _row(String name, double pct, double target, Color c) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$name ${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Text(
              '목표 ${(target * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0, 1),
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(c),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PenaltyShell(
      title: '수면 구조 감점',
      subtitle: '목표 분포: 깊 20% / REM 20% / 얕음 60%',
      value: -penalty,
      child: Column(
        children: [
          _row('깊은수면', deepPct, 0.20, const Color(0xFF5E35B1)),
          _row('REM', remPct, 0.20, const Color(0xFF29B6F6)),
          _row('얕은수면', lightPct, 0.60, const Color(0xFF42A5F5)),
        ],
      ),
    );
  }
}

class _PenaltyCard extends StatelessWidget {
  final String title, subtitle;
  final int value;
  final String? extra;
  const _PenaltyCard({
    required this.title,
    required this.subtitle,
    required this.value,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return _PenaltyShell(
      title: title,
      subtitle: subtitle,
      value: value,
      child:
          extra == null
              ? const SizedBox.shrink()
              : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  extra!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
    );
  }
}

class _PenaltyShell extends StatelessWidget {
  final String title, subtitle;
  final int value; // 음수로 표기
  final Widget child;
  const _PenaltyShell({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = value == 0 ? Colors.green : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.remove_circle_outline, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  '$value점',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        '참고: 이 점수는 앱 내부 규칙 기반(휴리스틱) 계산이에요. 실제 임상 수면지표와 동일하지 않을 수 있어요. '
        '또한 현재 “시간 감점”은 수면 윈도우 길이를 기준으로 하므로 실제 총수면시간과 차이가 날 수 있습니다.',
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
    );
  }
}
