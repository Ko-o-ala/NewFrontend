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

  // 수면 데이터 분석 결과
  late int totalSleepMin, inBedMinutes;
  late double deepPct, remPct, lightPct;
  late int timePenalty,
      structurePenalty,
      earlyDeepPenalty,
      wakePenalty,
      transitionPenalty,
      deepSegPenalty;
  late double earlyDeepRatio, transitionRate;

  @override
  void initState() {
    super.initState();

    // 데이터 확인
    print('=== SleepScoreDetailsPage 초기화 ===');
    print('받은 데이터 개수: ${widget.data.length}');
    print('수면 시작: ${widget.sleepStart}');
    print('수면 종료: ${widget.sleepEnd}');
    print('목표 수면시간: ${widget.goalSleepDuration}');
    print(
      '목표 수면시간 (시간): ${widget.goalSleepDuration.inHours}시간 ${widget.goalSleepDuration.inMinutes % 60}분',
    );
    print('목표 수면시간 (분): ${widget.goalSleepDuration.inMinutes}분');
    print('최종 점수: ${widget.finalScore}');

    // 데이터가 있는 경우에만 계산
    if (widget.data.isNotEmpty) {
      _compute();
    } else {
      print('경고: 수면 데이터가 비어있습니다!');
    }
  }

  @override
  void didUpdateWidget(SleepScoreDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 목표 수면시간이 변경되었는지 확인
    if (oldWidget.goalSleepDuration != widget.goalSleepDuration) {
      print('=== 목표 수면시간 변경 감지 ===');
      print('이전 목표: ${oldWidget.goalSleepDuration}');
      print('새로운 목표: ${widget.goalSleepDuration}');
      print('감점 계산을 다시 수행합니다...');

      // 감점 계산 다시 수행
      _compute();
    }
  }

  bool _isSleepType(HealthDataType t) =>
      t == HealthDataType.SLEEP_ASLEEP ||
      t == HealthDataType.SLEEP_LIGHT ||
      t == HealthDataType.SLEEP_DEEP ||
      t == HealthDataType.SLEEP_REM;

  void _compute() {
    if (widget.data.isEmpty) {
      print('오류: 수면 데이터가 비어있습니다.');
      return;
    }

    if (widget.sleepStart == null || widget.sleepEnd == null) {
      print('오류: 수면 시작/종료 시간이 설정되지 않았습니다.');
      return;
    }

    print('=== 기존 점수 분석 시작 ===');
    print('받은 최종 점수: ${widget.finalScore}점');

    // sleep_dashboard.dart와 동일한 계산 로직 사용
    final data = widget.data;
    int deepMin = 0, remMin = 0, lightMin = 0, awakeMin = 0;
    int wakeEpisodes = 0, transitions = 0;
    int longDeepSegments = 0;
    HealthDataPoint? prev;

    // 1) 수면 단계별 시간 계산
    for (final d in data) {
      final duration = d.dateTo.difference(d.dateFrom).inMinutes;
      switch (d.type) {
        case HealthDataType.SLEEP_DEEP:
          deepMin += duration;
          if (duration >= 30) longDeepSegments++;
          break;
        case HealthDataType.SLEEP_REM:
          remMin += duration;
          break;
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_ASLEEP:
          lightMin += duration;
          break;
        case HealthDataType.SLEEP_AWAKE:
          awakeMin += duration;
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

    print('수면 데이터 분석 결과:');
    print('- 깊은수면: ${deepMin}분');
    print('- REM: ${remMin}분');
    print('- 얕은수면: ${lightMin}분');
    print('- 깨어있음: ${awakeMin}분');
    print('- 총 수면시간: ${totalSleepMin}분');
    print('- 총 체류시간: ${inBedMinutes}분');

    // sleep_dashboard.dart와 동일한 감점 계산 로직
    final totalMinutes =
        widget.sleepEnd!.difference(widget.sleepStart!).inMinutes;
    final goalMinutes = widget.goalSleepDuration.inMinutes;

    int score = 100;

    // 1. 수면 시간 감점 (sleep_dashboard.dart와 동일)
    if (totalMinutes < goalMinutes) {
      final hourDiff = ((goalMinutes - totalMinutes) / 60).ceil();
      score -= (hourDiff * 20).clamp(0, 40);
      timePenalty = (hourDiff * 20).clamp(0, 40);

      print('⚠️ 시간 감점 발생!');
      print(
        '  - 목표: ${goalMinutes}분 (${goalMinutes ~/ 60}시간 ${goalMinutes % 60}분)',
      );
      print(
        '  - 실제: ${totalMinutes}분 (${totalMinutes ~/ 60}시간 ${totalMinutes % 60}분)',
      );
      print('  - 부족: ${goalMinutes - totalMinutes}분');
      print('  - 시간 단위: ${hourDiff}시간');
      print('  - 감점: ${timePenalty}점');
    } else {
      timePenalty = 0;
      print('✅ 목표 시간 달성! 시간 감점 없음');
    }

    // 2. 수면 구조 감점 (sleep_dashboard.dart와 동일)
    if (totalSleepMin > 0) {
      deepPct = deepMin / totalSleepMin;
      remPct = remMin / totalSleepMin;
      lightPct = lightMin / totalSleepMin;
      final diffSum =
          (deepPct - 0.2).abs() + (remPct - 0.2).abs() + (lightPct - 0.6).abs();
      structurePenalty = ((diffSum / 0.1).round() * 10).clamp(0, 30);
      score -= structurePenalty;
    } else {
      structurePenalty = 30;
      score -= structurePenalty;
    }

    // 3. 심층 수면 분포 감점 (sleep_dashboard.dart와 동일)
    final sleepDuration = widget.sleepEnd!.difference(widget.sleepStart!);
    final earlyEnd = widget.sleepStart!.add(sleepDuration * 0.4);
    final earlyDeepMin = data
        .where(
          (d) =>
              d.type == HealthDataType.SLEEP_DEEP &&
              d.dateFrom.isBefore(earlyEnd),
        )
        .fold<int>(
          0,
          (sum, d) => sum + d.dateTo.difference(d.dateFrom).inMinutes,
        );

    earlyDeepRatio = deepMin > 0 ? earlyDeepMin / deepMin : 0;
    if (earlyDeepRatio < 0.8) {
      earlyDeepPenalty = 8;
      score -= 8;
    } else {
      earlyDeepPenalty = 0;
    }

    // 4. 깸 횟수 감점 (sleep_dashboard.dart와 동일)
    wakePenalty = (wakeEpisodes * 5).clamp(0, 10);
    score -= wakePenalty;

    // 5. 수면 통합성 감점 (sleep_dashboard.dart와 동일)
    final hours = totalSleepMin / 60;
    transitionRate = hours > 0 ? transitions / hours : 0;
    if (transitionRate >= 5) {
      transitionPenalty = 5;
      score -= 5;
    } else {
      transitionPenalty = 0;
    }

    if (longDeepSegments == 0) {
      deepSegPenalty = 10;
      score -= 10;
    } else {
      deepSegPenalty = 0;
    }

    final calculatedScore = score.clamp(0, 100);

    print('=== sleep_dashboard.dart와 동일한 로직으로 계산한 결과 ===');
    print('받은 최종 점수: ${widget.finalScore}점');
    print('계산된 점수: ${calculatedScore}점');
    print('점수 차이: ${widget.finalScore - calculatedScore}점');
    print('');
    print('감점 분석 (sleep_dashboard.dart 로직 기준):');
    print(
      '- 시간 감점 (목표 ${goalMinutes}분 vs 실제 ${totalMinutes}분): ${timePenalty}점',
    );
    print(
      '- 수면 구조 감점 (deep: ${(deepPct * 100).toStringAsFixed(1)}%, REM: ${(remPct * 100).toStringAsFixed(1)}%, light: ${(lightPct * 100).toStringAsFixed(1)}%): ${structurePenalty}점',
    );
    print(
      '- 초반 deep 분포 감점 (${(earlyDeepRatio * 100).toStringAsFixed(1)}%): ${earlyDeepPenalty}점',
    );
    print('- 깸 에피소드 감점 (${wakeEpisodes}회): ${wakePenalty}점');
    print(
      '- 전환율 감점 (${transitionRate.toStringAsFixed(1)}/시간): ${transitionPenalty}점',
    );
    print('- deep 세그먼트 감점 (${longDeepSegments}개): ${deepSegPenalty}점');
    print('총 감점: ${100 - calculatedScore}점');
    print('=== 기존 점수 분석 완료 ===');
  }

  // 약점 분석
  List<String> _getWeakPoints() {
    List<String> weakPoints = [];

    if (timePenalty > 0) weakPoints.add('time');
    if (structurePenalty > 0) weakPoints.add('structure');
    if (earlyDeepPenalty > 0) weakPoints.add('earlyDeep');
    if (wakePenalty > 0) weakPoints.add('wake');
    if (transitionPenalty > 0) weakPoints.add('transition');
    if (deepSegPenalty > 0) weakPoints.add('deepSeg');

    return weakPoints;
  }

  @override
  Widget build(BuildContext context) {
    final hInBed = inBedMinutes ~/ 60, mInBed = inBedMinutes % 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('수면점수 상세 분석'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 메인 점수 카드
            _MainScoreCard(finalScore: widget.finalScore),
            const SizedBox(height: 20),

            // 수면 요약 정보
            _SleepSummaryCard(
              inBedText: '${hInBed}시간 ${mInBed}분',
              deepMin: deepMin,
              remMin: remMin,
              lightMin: lightMin,
              awakeMin: awakeMin,
              goalText:
                  '${widget.goalSleepDuration.inHours}시간 ${widget.goalSleepDuration.inMinutes % 60}분',
            ),
            const SizedBox(height: 20),

            // 점수 구성 요소
            _ScoreBreakdownCard(
              timePenalty: timePenalty,
              structurePenalty: structurePenalty,
              earlyDeepPenalty: earlyDeepPenalty,
              wakePenalty: wakePenalty,
              transitionPenalty: transitionPenalty,
              deepSegPenalty: deepSegPenalty,
              totalSleepMin: totalSleepMin,
              goalDuration: widget.goalSleepDuration,
            ),
            const SizedBox(height: 20),

            // 수면 품질 인사이트
            _SleepQualityInsights(
              score: widget.finalScore,
              deepMin: deepMin,
              remMin: remMin,
              lightMin: lightMin,
              totalSleepMin: totalSleepMin,
            ),
          ],
        ),
      ),
    );
  }
}

// 메인 점수 카드
class _MainScoreCard extends StatelessWidget {
  final int finalScore;

  const _MainScoreCard({required this.finalScore});

  String _getGrade(int score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B+';
    if (score >= 60) return 'B';
    if (score >= 50) return 'C+';
    if (score >= 40) return 'C';
    if (score >= 30) return 'D+';
    if (score >= 20) return 'D';
    return 'F';
  }

  Color _getGradeColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6C63FF), const Color(0xFF4B47BD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '수면 점수',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$finalScore',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getGradeColor(finalScore),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getGrade(finalScore),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(5)),
        ],
      ),
    );
  }
}

// 수면 요약 정보 카드
class _SleepSummaryCard extends StatelessWidget {
  final String inBedText;
  final int deepMin, remMin, lightMin, awakeMin;
  final String goalText;

  const _SleepSummaryCard({
    required this.inBedText,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.awakeMin,
    required this.goalText,
  });

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}시간 ${mins}분';
    }
    return '${mins}분';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime, color: Color(0xFF6C63FF), size: 24),
              const SizedBox(width: 12),
              const Text(
                '수면 요약',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 수면 시간 정보
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.access_time,
                  title: '총 체류시간',
                  value: inBedText,
                  color: const Color(0xFF29B6F6),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFFD54F),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _SummaryItem(
                    icon: Icons.flag,
                    title: '목표 시간',
                    value: goalText,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 수면 단계별 정보
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.brightness_1,
                  title: '깊은수면',
                  value: _formatMinutes(deepMin),
                  color: const Color(0xFF5E35B1),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.brightness_2,
                  title: 'REM',
                  value: _formatMinutes(remMin),
                  color: const Color(0xFF29B6F6),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.brightness_3,
                  title: '얕은수면',
                  value: _formatMinutes(lightMin),
                  color: const Color(0xFF42A5F5),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.brightness_4,
                  title: '깨어있음',
                  value: _formatMinutes(awakeMin),
                  color: const Color(0xFFEF5350),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// 점수 구성 요소 카드
class _ScoreBreakdownCard extends StatelessWidget {
  final int timePenalty,
      structurePenalty,
      earlyDeepPenalty,
      wakePenalty,
      transitionPenalty,
      deepSegPenalty;
  final int totalSleepMin;
  final Duration goalDuration;

  const _ScoreBreakdownCard({
    required this.timePenalty,
    required this.structurePenalty,
    required this.earlyDeepPenalty,
    required this.wakePenalty,
    required this.transitionPenalty,
    required this.deepSegPenalty,
    required this.totalSleepMin,
    required this.goalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final totalPenalty =
        timePenalty +
        structurePenalty +
        earlyDeepPenalty +
        wakePenalty +
        transitionPenalty +
        deepSegPenalty;
    final actualScore = 100 - totalPenalty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Color(0xFF6C63FF), size: 24),
              const SizedBox(width: 12),
              const Text(
                '점수 구성',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 기본 점수
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2E3F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 12),
                const Text(
                  '기본 점수',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '100점',
                  style: TextStyle(
                    color: const Color(0xFFFFD54F),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 감점 내역
          if (timePenalty > 0)
            _PenaltyItem(
              title: '시간 부족',
              penalty: timePenalty,
              description: '목표 ${goalDuration.inHours}시간 대비 부족',
              color: const Color(0xFFFF6B6B),
            ),
          if (structurePenalty > 0)
            _PenaltyItem(
              title: '수면 구조',
              penalty: structurePenalty,
              description: '깊은수면, REM, 얕은수면 비율 불균형',
              color: const Color(0xFFFF8E53),
            ),
          if (earlyDeepPenalty > 0)
            _PenaltyItem(
              title: '초반 깊은수면',
              penalty: earlyDeepPenalty,
              description: '수면 초반 깊은수면 부족',
              color: const Color(0xFFFFB74D),
            ),
          if (wakePenalty > 0)
            _PenaltyItem(
              title: '깨어남',
              penalty: wakePenalty,
              description: '수면 중 깨어나는 횟수',
              color: const Color(0xFFFFCC02),
            ),
          if (transitionPenalty > 0)
            _PenaltyItem(
              title: '수면 전환',
              penalty: transitionPenalty,
              description: '수면 단계 전환이 너무 잦음',
              color: const Color(0xFF81C784),
            ),
          if (deepSegPenalty > 0)
            _PenaltyItem(
              title: '깊은수면 세그먼트',
              penalty: deepSegPenalty,
              description: '30분 이상 지속되는 깊은수면 부족',
              color: const Color(0xFF64B5F6),
            ),

          const SizedBox(height: 16),

          // 최종 점수
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2E3F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6C63FF)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 12),
                const Text(
                  '최종 점수',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$actualScore점',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyItem extends StatelessWidget {
  final String title;
  final int penalty;
  final String description;
  final Color color;

  const _PenaltyItem({
    required this.title,
    required this.penalty,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E3F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.remove_circle_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              '-$penalty점',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 수면 품질 인사이트
class _SleepQualityInsights extends StatelessWidget {
  final int score;
  final int deepMin, remMin, lightMin, totalSleepMin;

  const _SleepQualityInsights({
    required this.score,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.totalSleepMin,
  });

  String _getInsight() {
    if (score >= 90) {
      return '매우 건강한 수면 패턴입니다! 깊은 수면과 REM 수면이 충분하고, 수면 구조도 이상적입니다.';
    } else if (score >= 80) {
      return '전반적으로 좋은 수면을 취했습니다. 몇 가지 개선할 점이 있지만 전반적으로 건강한 수면입니다.';
    } else if (score >= 70) {
      return '보통 수준의 수면입니다. 수면 시간과 구조에 개선의 여지가 있습니다.';
    } else if (score >= 60) {
      return '수면 품질이 다소 부족합니다. 수면 환경과 습관을 개선해보세요.';
    } else {
      return '수면 품질이 많이 부족합니다. 전문가와 상담하거나 수면 환경을 전면적으로 개선해보세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deepPct = totalSleepMin > 0 ? (deepMin / totalSleepMin) * 100 : 0;
    final remPct = totalSleepMin > 0 ? (remMin / totalSleepMin) * 100 : 0;
    final lightPct = totalSleepMin > 0 ? (lightMin / totalSleepMin) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFFFD54F), size: 24),
              const SizedBox(width: 12),
              const Text(
                '수면 품질 인사이트',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 전체적인 평가
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2E3F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getInsight(),
              style: const TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 수면 단계별 분석
          Row(
            children: [
              Expanded(
                child: _InsightItem(
                  title: '깊은수면',
                  percentage: deepPct.toDouble(),
                  target: 20,
                  color: const Color(0xFF5E35B1),
                  description: '신체 회복',
                ),
              ),
              Expanded(
                child: _InsightItem(
                  title: 'REM',
                  percentage: remPct.toDouble(),
                  target: 20,
                  color: const Color(0xFF29B6F6),
                  description: '기억 정리',
                ),
              ),
              Expanded(
                child: _InsightItem(
                  title: '얕은수면',
                  percentage: lightPct.toDouble(),
                  target: 60,
                  color: const Color(0xFF42A5F5),
                  description: '수면 유지',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String title;
  final double percentage;
  final int target;
  final Color color;
  final String description;

  const _InsightItem({
    required this.title,
    required this.percentage,
    required this.target,
    required this.color,
    required this.description,
  });

  String _getStatus() {
    final diff = (percentage - target).abs();
    if (diff <= 5) return '적정';
    if (diff <= 10) return '보통';
    return '부족';
  }

  Color _getStatusColor() {
    final diff = (percentage - target).abs();
    if (diff <= 5) return const Color(0xFF4CAF50);
    if (diff <= 10) return const Color(0xFFFFC107);
    return const Color(0xFFFF5722);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '목표: ${target}%',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor().withOpacity(0.4)),
            ),
            child: Text(
              _getStatus(),
              style: TextStyle(
                color: _getStatusColor(),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// 수면 품질 분석 위젯
class _SleepQualityAnalysis extends StatelessWidget {
  final int score;
  final int deepMin, remMin, lightMin, awakeMin;
  final int wakeEpisodes, transitions;
  final double earlyDeepRatio;
  final Duration goalDuration, actualDuration;

  const _SleepQualityAnalysis({
    required this.score,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.awakeMin,
    required this.wakeEpisodes,
    required this.transitions,
    required this.earlyDeepRatio,
    required this.goalDuration,
    required this.actualDuration,
  });

  String _getScoreGrade() {
    if (score >= 90) return 'A+ (우수)';
    if (score >= 80) return 'A (양호)';
    if (score >= 70) return 'B (보통)';
    if (score >= 60) return 'C (미흡)';
    return 'D (부족)';
  }

  String _getScoreMeaning() {
    if (score >= 90)
      return '매우 건강한 수면 패턴입니다! 깊은 수면과 REM 수면이 충분하고, 수면 구조도 이상적입니다.';
    if (score >= 80)
      return '전반적으로 좋은 수면을 취했습니다. 몇 가지 개선할 점이 있지만 전반적으로 건강한 수면입니다.';
    if (score >= 70) return '보통 수준의 수면입니다. 수면 시간과 구조에 개선의 여지가 있습니다.';
    if (score >= 60) return '수면 품질이 다소 부족합니다. 수면 환경과 습관을 개선해보세요.';
    return '수면 품질이 많이 부족합니다. 전문가와 상담하거나 수면 환경을 전면적으로 개선해보세요.';
  }

  String _getDeepSleepQuality() {
    final deepPct = (deepMin / (deepMin + remMin + lightMin)) * 100;
    if (deepPct >= 25) return '매우 좋음 - 충분한 깊은 수면으로 신체 회복이 잘 되었습니다.';
    if (deepPct >= 20) return '좋음 - 적정한 깊은 수면으로 신체 회복이 이루어졌습니다.';
    if (deepPct >= 15) return '보통 - 다소 부족한 깊은 수면으로 회복이 부족할 수 있습니다.';
    return '부족 - 깊은 수면이 부족하여 신체 회복이 제대로 이루어지지 않았습니다.';
  }

  String _getREMSleepQuality() {
    final remPct = (remMin / (deepMin + remMin + lightMin)) * 100;
    if (remPct >= 25) return '매우 좋음 - 충분한 REM 수면으로 기억 정리와 정서 조절이 잘 되었습니다.';
    if (remPct >= 20) return '좋음 - 적정한 REM 수면으로 기억과 정서 조절이 이루어졌습니다.';
    if (remPct >= 15) return '보통 - 다소 부족한 REM 수면으로 기억 정리가 부족할 수 있습니다.';
    return '부족 - REM 수면이 부족하여 기억 정리와 정서 조절이 제대로 되지 않았습니다.';
  }

  String _getSleepEfficiency() {
    final efficiency =
        ((deepMin + remMin + lightMin) /
            (deepMin + remMin + lightMin + awakeMin)) *
        100;
    if (efficiency >= 95) return '매우 좋음 - 거의 깨어있지 않고 효율적으로 수면을 취했습니다.';
    if (efficiency >= 90) return '좋음 - 효율적인 수면을 취했습니다.';
    if (efficiency >= 85) return '보통 - 다소 깨어있는 시간이 있었습니다.';
    return '부족 - 자주 깨어있어 수면 효율이 떨어집니다.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: const Color(0xFF6C63FF), size: 24),
              const SizedBox(width: 12),
              const Text(
                '수면 품질 분석',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 점수 등급과 의미
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2E3F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getScoreGrade(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getScoreMeaning(),
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 수면 단계별 품질
          _QualityRow(
            '깊은 수면 품질',
            _getDeepSleepQuality(),
            const Color(0xFF5E35B1),
          ),
          _QualityRow(
            'REM 수면 품질',
            _getREMSleepQuality(),
            const Color(0xFF29B6F6),
          ),
          _QualityRow('수면 효율성', _getSleepEfficiency(), const Color(0xFF42A5F5)),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  final String title;
  final String description;
  final Color color;

  const _QualityRow(this.title, this.description, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E3F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// 개선 제안 위젯
class _ImprovementSuggestions extends StatelessWidget {
  final int score;
  final List<String> weakPoints;
  final int deepMin, remMin, lightMin, awakeMin;
  final int wakeEpisodes, transitions;

  const _ImprovementSuggestions({
    required this.score,
    required this.weakPoints,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.awakeMin,
    required this.wakeEpisodes,
    required this.transitions,
  });

  List<String> _getSuggestions() {
    List<String> suggestions = [];

    if (weakPoints.contains('time')) {
      suggestions.add(
        '• 목표 수면 시간을 충족하도록 일정을 조정해보세요. 취침 시간을 30분 앞당기거나 기상 시간을 30분 늦춰보세요.',
      );
    }

    if (weakPoints.contains('structure')) {
      suggestions.add(
        '• 수면 환경을 개선하여 깊은 수면을 늘려보세요. 방을 어둡게 하고, 시원한 온도(18-22°C)를 유지하세요.',
      );
      suggestions.add('• 취침 전 1시간은 스마트폰, TV 등 블루라이트를 피하고, 차분한 활동을 하세요.');
    }

    if (weakPoints.contains('earlyDeep')) {
      suggestions.add('• 취침 전 2-3시간은 격렬한 운동을 피하고, 따뜻한 목욕이나 스트레칭으로 몸을 이완시키세요.');
    }

    if (weakPoints.contains('wake')) {
      suggestions.add('• 수면 중 깨어나는 횟수를 줄이기 위해 방을 어둡고 조용하게 유지하세요.');
      suggestions.add('• 취침 전 카페인, 알코올 섭취를 줄이고, 적당한 수분 섭취를 하세요.');
    }

    if (weakPoints.contains('transition')) {
      suggestions.add('• 수면 단계 전환이 잦은 경우, 수면 환경을 일정하게 유지하고 스트레스를 줄여보세요.');
    }

    if (weakPoints.contains('deepSeg')) {
      suggestions.add('• 깊은 수면을 늘리기 위해 규칙적인 운동(하루 30분)을 하고, 취침 전 이완 활동을 하세요.');
    }

    // 일반적인 수면 개선 팁
    if (score < 80) {
      suggestions.add('• 매일 같은 시간에 일어나고 잠자리에 드는 규칙적인 수면 패턴을 만들어보세요.');
      suggestions.add('• 취침 전 1시간은 스마트폰, TV 등 전자기기 사용을 줄이세요.');
      suggestions.add('• 취침 전 따뜻한 우유나 허브차를 마시고, 가벼운 독서나 명상을 해보세요.');
    }

    return suggestions;
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getSuggestions();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: const Color(0xFFFFD54F), size: 24),
              const SizedBox(width: 12),
              const Text(
                '수면 품질 개선 제안',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (suggestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2E3F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Text(
                    '현재 수면 품질이 매우 좋습니다! 현재의 수면 습관을 유지하세요.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            ...suggestions
                .map(
                  (suggestion) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2E3F),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates,
                          color: const Color(0xFFFFD54F),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
        ],
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final int finalScoreFromCaller;
  const _ScoreHeader({required this.finalScoreFromCaller});

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
