// lib/sleep_dashboard/sleep_score_details.dart
import 'package:flutter/material.dart';
import 'package:health/health.dart';

class SleepScoreDetailsPage extends StatefulWidget {
  final List<HealthDataPoint> data;
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final Duration goalSleepDuration;

  const SleepScoreDetailsPage({
    super.key,
    required this.data,
    required this.sleepStart,
    required this.sleepEnd,
    required this.goalSleepDuration,
  });

  @override
  State<SleepScoreDetailsPage> createState() => _SleepScoreDetailsPageState();
}

class _SleepScoreDetailsPageState extends State<SleepScoreDetailsPage>
    with TickerProviderStateMixin {
  late int recalculatedScore;

  // 수면 데이터 변수들
  int deepMin = 0, remMin = 0, lightMin = 0, awakeMin = 0;
  int totalSleepMin = 0, inBedMinutes = 0;
  int wakeEpisodes = 0, transitions = 0, longDeepSegments = 0;
  double deepPct = 0, remPct = 0, lightPct = 0, earlyDeepRatio = 0;
  double transitionRate = 0;

  // 감점 변수들
  int timePenalty = 0, structurePenalty = 0, earlyDeepPenalty = 0;
  int wakePenalty = 0, transitionPenalty = 0, deepSegPenalty = 0;

  // 애니메이션 컨트롤러
  late AnimationController _scoreController;
  late AnimationController _fadeController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scoreAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    recalculatedScore = 0;

    if (widget.data.isNotEmpty) {
      _compute();
      _startAnimations();
    }
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scoreController.forward();
      _fadeController.forward();
    });
  }

  @override
  void didUpdateWidget(SleepScoreDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalSleepDuration != widget.goalSleepDuration) {
      _compute();
      _startAnimations();
    }
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _compute() {
    if (widget.data.isEmpty) return;

    // 수면 데이터 분석
    final data = widget.data;
    deepMin = remMin = lightMin = awakeMin = 0;
    wakeEpisodes = transitions = longDeepSegments = 0;

    HealthDataPoint? prev;
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

    // 점수 계산
    final totalMinutes =
        widget.sleepEnd.difference(widget.sleepStart).inMinutes;
    final goalMinutes = widget.goalSleepDuration.inMinutes;

    int score = 100;

    // 1. 수면 시간 감점 (더 관대하게)
    if (totalMinutes < goalMinutes) {
      final hourDiff = ((goalMinutes - totalMinutes) / 60).ceil();
      timePenalty = (hourDiff * 5).clamp(0, 15); // 10 → 5, 25 → 15
      score -= timePenalty;
    } else {
      timePenalty = 0;
    }

    // 2. 수면 구조 감점 (더 관대하게)
    if (totalSleepMin > 0) {
      deepPct = deepMin / totalSleepMin;
      remPct = remMin / totalSleepMin;
      lightPct = lightMin / totalSleepMin;
      final diffSum =
          (deepPct - 0.2).abs() + (remPct - 0.2).abs() + (lightPct - 0.6).abs();
      structurePenalty = ((diffSum / 0.3).round() * 3).clamp(
        0,
        10,
      ); // 0.2 → 0.3, 5 → 3, 15 → 10
      score -= structurePenalty;
    } else {
      structurePenalty = 10; // 15 → 10
      score -= structurePenalty;
    }

    // 3. 초반 deep 분포 감점 (더 관대하게)
    final sleepDuration = widget.sleepEnd.difference(widget.sleepStart);
    final earlyEnd = widget.sleepStart.add(sleepDuration * 0.4);
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
    if (earlyDeepRatio < 0.4) {
      // 0.6 → 0.4
      earlyDeepPenalty = 3; // 5 → 3
      score -= 3;
    } else {
      earlyDeepPenalty = 0;
    }

    // 4. 깸 횟수 감점 (더 관대하게)
    wakePenalty = (wakeEpisodes * 2).clamp(0, 6); // 3 → 2, 8 → 6
    score -= wakePenalty;

    // 5. 수면 통합성 감점 (더 관대하게)
    final hours = totalSleepMin / 60;
    transitionRate = hours > 0 ? transitions / hours : 0;
    if (transitionRate >= 10) {
      // 8 → 10
      transitionPenalty = 2; // 3 → 2
      score -= 2;
    } else {
      transitionPenalty = 0;
    }

    if (longDeepSegments == 0) {
      deepSegPenalty = 3; // 5 → 3
      score -= 3;
    } else {
      deepSegPenalty = 0;
    }

    recalculatedScore = score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '수면 점수 분석',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메인 점수 카드
              _buildMainScoreCard(),
              const SizedBox(height: 24),

              // 수면 요약 카드
              _buildSleepSummaryCard(),
              const SizedBox(height: 24),

              // 점수 분석 카드
              _buildScoreAnalysisCard(),
              const SizedBox(height: 24),

              // 개선 제안 카드
              _buildImprovementCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getScoreColor(recalculatedScore).withValues(alpha: 0.2),
            _getScoreColor(recalculatedScore).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getScoreColor(recalculatedScore).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scoreAnimation.value,
                child: Text(
                  '$recalculatedScore',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(recalculatedScore),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getScoreMessage(recalculatedScore),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getScoreColor(recalculatedScore).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getScoreDescription(recalculatedScore),
              style: TextStyle(
                color: _getScoreColor(recalculatedScore),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepSummaryCard() {
    final h = totalSleepMin ~/ 60;
    final m = totalSleepMin % 60;
    final goalH = widget.goalSleepDuration.inHours;
    final goalM = widget.goalSleepDuration.inMinutes % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bedtime, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                '수면 요약',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('실제 수면', '$h시간 $m분', Colors.green),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '목표 수면',
                  '$goalH시간 $goalM분',
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '깊은수면',
                  '${(deepPct * 100).toStringAsFixed(1)}%',
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'REM',
                  '${(remPct * 100).toStringAsFixed(1)}%',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '코어수면',
                  '${(lightPct * 100).toStringAsFixed(1)}%',
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildScoreAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '점수 분석',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildPenaltyItem('시간', timePenalty, '목표 수면시간 달성 여부'),
          _buildPenaltyItem('수면 구조', structurePenalty, '깊은수면, REM, 코어수면 비율'),
          _buildPenaltyItem('초반 deep', earlyDeepPenalty, '수면 초반 깊은수면 분포'),
          _buildPenaltyItem('깸 횟수', wakePenalty, '수면 중 깨어난 횟수'),
          _buildPenaltyItem('전환율', transitionPenalty, '수면 단계 전환 빈도'),
          _buildPenaltyItem('deep 세그먼트', deepSegPenalty, '30분 이상 깊은수면 지속'),
        ],
      ),
    );
  }

  Widget _buildPenaltyItem(String label, int penalty, String description) {
    if (penalty == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.remove, color: Colors.red, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label 감점: -$penalty점',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '개선 제안',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._getImprovementSuggestions(),
        ],
      ),
    );
  }

  List<Widget> _getImprovementSuggestions() {
    final suggestions = <Widget>[];

    if (timePenalty > 0) {
      suggestions.add(
        _buildSuggestionItem(
          '⏰ 수면 시간 부족',
          '목표 수면시간을 달성하기 위해 취침 시간을 앞당기거나 기상 시간을 늦추세요.',
          Colors.orange,
        ),
      );
    }

    if (structurePenalty > 0) {
      suggestions.add(
        _buildSuggestionItem(
          '🏗️ 수면 구조 개선',
          '규칙적인 수면 패턴과 적절한 수면 환경을 만들어 깊은수면과 REM 수면을 늘리세요.',
          Colors.purple,
        ),
      );
    }

    if (earlyDeepPenalty > 0) {
      suggestions.add(
        _buildSuggestionItem(
          '🌅 초반 깊은수면 부족',
          '수면 초반에 깊은수면을 늘리려면 취침 전 스마트폰 사용을 줄이고 편안한 환경을 만드세요.',
          Colors.blue,
        ),
      );
    }

    if (wakePenalty > 0) {
      suggestions.add(
        _buildSuggestionItem(
          '😴 수면 중 깸 횟수',
          '수면 중 깨어나는 것을 줄이려면 방을 어둡게 하고, 소음을 차단하며, 편안한 온도를 유지하세요.',
          Colors.red,
        ),
      );
    }

    if (deepSegPenalty > 0) {
      suggestions.add(
        _buildSuggestionItem(
          '🔴 깊은수면 지속성',
          '30분 이상 지속되는 깊은수면을 위해 스트레스를 줄이고, 규칙적인 운동을 하세요.',
          Colors.indigo,
        ),
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        _buildSuggestionItem(
          '🎉 훌륭한 수면!',
          '현재 수면 패턴이 매우 좋습니다. 이대로 유지하세요!',
          Colors.green,
        ),
      );
    }

    return suggestions;
  }

  Widget _buildSuggestionItem(String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 70) return Colors.green; // 80 → 70
    if (score >= 50) return Colors.orange; // 60 → 50
    if (score >= 30) return Colors.deepOrange; // 40 → 30
    return Colors.red;
  }

  String _getScoreMessage(int score) {
    if (score >= 70) return '훌륭한 수면!'; // 80 → 70
    if (score >= 50) return '좋은 수면'; // 60 → 50
    if (score >= 30) return '개선이 필요해요'; // 40 → 30
    return '수면 관리가 필요해요';
  }

  String _getScoreDescription(int score) {
    if (score >= 70) return '전문가 수준의 수면'; // 80 → 70
    if (score >= 50) return '일반적인 수면 품질'; // 60 → 50
    if (score >= 30) return '수면 패턴 개선 필요'; // 40 → 30
    return '수면 전문의 상담 권장';
  }
}
