// lib/sleep_dashboard/sleep_score_details.dart
import 'package:flutter/material.dart';
import 'package:health/health.dart';

class SleepScoreDetailsPage extends StatefulWidget {
  final List<HealthDataPoint> data;
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final Duration goalSleepDuration;
  final bool fallbackFromTwoDaysAgo;

  const SleepScoreDetailsPage({
    super.key,
    required this.data,
    required this.sleepStart,
    required this.sleepEnd,
    required this.goalSleepDuration,
    this.fallbackFromTwoDaysAgo = false,
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
  int wakeEpisodes = 0, transitions = 0;
  double deepPct = 0, remPct = 0, lightPct = 0, earlyDeepRatio = 0;
  double transitionRate = 0;
  // _SleepScoreDetailsPageState 안에
  double sleepEfficiency = 0.0; // 실제수면/침대시간

  // UI 표시용 변수들 (감점 방식에서 가중치 방식으로 변경됨)

  // 애니메이션 컨트롤러
  late AnimationController _scoreController;
  late AnimationController _fadeController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _fadeAnimation;

  // ✅ 목표가 없을 때 기본 8시간(480분)을 내부 타깃으로 사용
  int get _targetMinutes {
    final m = widget.goalSleepDuration.inMinutes;
    return m > 0 ? m : 480;
  }

  bool get _usingDefaultTarget => widget.goalSleepDuration.inMinutes <= 0;

  // sleep_dashboard.dart와 동일한 수면점수 계산 함수
  int _calculateSleepScore({
    required List<HealthDataPoint> data,
    required DateTime sleepStart,
    required DateTime sleepEnd,
    required Duration goalSleepDuration,
  }) {
    int deepMin = 0, remMin = 0, lightMin = 0, awakeMin = 0;
    int wakeEpisodes = 0, transitions = 0;

    HealthDataPoint? prev;
    for (final d in data) {
      final minutes = d.dateTo.difference(d.dateFrom).inMinutes;
      switch (d.type) {
        case HealthDataType.SLEEP_DEEP:
          deepMin += minutes;
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

    final asleepMin = deepMin + remMin + lightMin; // 실제 수면
    final inBedMin = asleepMin + awakeMin; // 침대에 있던 전체 시간
    if (asleepMin <= 0) return 0;

    // --- 1) Duration score (목표 대비) ---
    final goalMinutes = goalSleepDuration.inMinutes.toDouble();

    // ⬇️ targetMinutes를 항상 갖게 만듭니다. (목표 없으면 8h)
    final targetMinutes = goalMinutes > 0 ? goalMinutes : 480.0;

    double wDur = 0.40,
        wEff = 0.20,
        wStruct = 0.20,
        wFrag = 0.15,
        wEarly = 0.05;

    final durRatio = (deepMin + remMin + lightMin) / targetMinutes;
    double durScore;
    if (durRatio >= 1.0) {
      durScore = 90 + (((durRatio - 1.0).clamp(0.0, 0.2)) / 0.2) * 10;
    } else {
      durScore = (durRatio.clamp(0.0, 1.0)) * 90;
    }

    // --- 2) Efficiency score (실제수면/침대시간) ---
    final eff = inBedMin > 0 ? asleepMin / inBedMin : 0.0;
    double effScore;
    if (eff <= 0.75) {
      // 0.60→0 ~ 0.75→50
      effScore = 50 * ((eff - 0.60) / 0.15).clamp(0.0, 1.0);
    } else if (eff <= 0.85) {
      // 0.75→50 ~ 0.85→80
      effScore = 50 + 30 * ((eff - 0.75) / 0.10).clamp(0.0, 1.0);
    } else if (eff <= 0.92) {
      // 0.85→80 ~ 0.92→95
      effScore = 80 + 15 * ((eff - 0.85) / 0.07).clamp(0.0, 1.0);
    } else {
      // 0.92→95 ~ 0.97→100
      effScore = 95 + 5 * ((eff - 0.92) / 0.05).clamp(0.0, 1.0);
    }
    effScore = effScore.clamp(0, 100).toDouble();

    // --- 3) Structure score (깊/REM/얕 비율) ---
    final deepPct = asleepMin > 0 ? deepMin / asleepMin : 0.0;
    final remPct = asleepMin > 0 ? remMin / asleepMin : 0.0;
    final lightPct = asleepMin > 0 ? lightMin / asleepMin : 0.0;
    // 목표 비율: 깊 22%, REM 22%, 얕 56%
    final dev =
        (deepPct - 0.22).abs() +
        (remPct - 0.22).abs() +
        (lightPct - 0.56).abs();
    // dev=0 → 100점, dev=0.5 → 0점 (상한/하한 클램프)
    double structScore = (100 - (dev / 0.5) * 100).clamp(0, 100).toDouble();

    // --- 4) Fragmentation score (깸/전환) ---
    final hours = asleepMin / 60.0;
    final transitionRate = hours > 0 ? transitions / hours : 0.0;
    double fragScore = 100.0;
    fragScore -= (wakeEpisodes * 6).clamp(0, 36); // 깸 1회당 -6, 최대 -36
    if (transitionRate > 12)
      fragScore -= (transitionRate - 12) * 3; // 전환률 12/h 초과부터 감점
    fragScore = fragScore.clamp(0, 100).toDouble();

    // --- 5) Early-deep score (첫 40% 구간의 깊은수면 분포) ---
    final sleepDuration = sleepEnd.difference(sleepStart);
    final earlyEnd = sleepStart.add(
      Duration(minutes: (sleepDuration.inMinutes * 0.4).round()),
    );
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
    final earlyDeepRatio = deepMin > 0 ? earlyDeepMin / deepMin : 0.0;
    double earlyScore;
    if (earlyDeepRatio <= 0.2) {
      earlyScore = 40;
    } else if (earlyDeepRatio < 0.4) {
      earlyScore = 40 + 50 * ((earlyDeepRatio - 0.2) / 0.2);
    } else if (earlyDeepRatio < 0.5) {
      earlyScore = 90 + 10 * ((earlyDeepRatio - 0.4) / 0.1);
    } else {
      earlyScore = 100;
    }
    earlyScore = earlyScore.clamp(0, 100).toDouble();

    // --- 가중 합산 ---
    // 목표 없을 때 가중치 정규화
    final sumW = wDur + wEff + wStruct + wFrag + wEarly;
    wDur /= sumW;
    wEff /= sumW;
    wStruct /= sumW;
    wFrag /= sumW;
    wEarly /= sumW;

    final score =
        wDur * durScore +
        wEff * effScore +
        wStruct * structScore +
        wFrag * fragScore +
        wEarly * earlyScore;

    return score.round().clamp(0, 100);
  }

  @override
  void initState() {
    super.initState();

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
    if (oldWidget.goalSleepDuration != widget.goalSleepDuration ||
        oldWidget.data != widget.data ||
        oldWidget.sleepStart != widget.sleepStart ||
        oldWidget.sleepEnd != widget.sleepEnd) {
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
    if (widget.data.isEmpty) {
      debugPrint('[SleepScoreDetails] 데이터가 비어있습니다');
      return;
    }

    debugPrint('[SleepScoreDetails] 데이터 분석 시작 - ${widget.data.length}개');
    debugPrint(
      '[SleepScoreDetails] 수면 시간: ${widget.sleepStart} ~ ${widget.sleepEnd}',
    );
    debugPrint(
      '[SleepScoreDetails] 목표 수면(분): ${widget.goalSleepDuration.inMinutes} '
      '(사용 타깃=${_targetMinutes}분${_usingDefaultTarget ? ", 기본값" : ""})',
    );

    // sleep_dashboard.dart와 동일한 계산 로직 사용
    recalculatedScore = _calculateSleepScore(
      data: widget.data,
      sleepStart: widget.sleepStart,
      sleepEnd: widget.sleepEnd,
      goalSleepDuration: widget.goalSleepDuration,
    );

    // 기존 변수들도 계산 (UI 표시용)
    final data = widget.data;
    deepMin = remMin = lightMin = awakeMin = 0;
    wakeEpisodes = transitions = 0;

    HealthDataPoint? prev;
    for (final d in data) {
      final duration = d.dateTo.difference(d.dateFrom).inMinutes;

      switch (d.type) {
        case HealthDataType.SLEEP_DEEP:
          deepMin += duration;
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

    totalSleepMin = deepMin + remMin + lightMin; // 실제 수면
    inBedMinutes = totalSleepMin + awakeMin; // 침대에 있던 전체

    // UI 표시용 변수들 계산
    sleepEfficiency = inBedMinutes > 0 ? totalSleepMin / inBedMinutes : 0.0;
    deepPct = totalSleepMin > 0 ? deepMin / totalSleepMin : 0.0;
    remPct = totalSleepMin > 0 ? remMin / totalSleepMin : 0.0;
    lightPct = totalSleepMin > 0 ? lightMin / totalSleepMin : 0.0;

    // 초반 deep 분포 계산
    final sleepDurWindow = widget.sleepEnd.difference(widget.sleepStart);
    final earlyEnd = widget.sleepStart.add(
      Duration(minutes: (sleepDurWindow.inMinutes * 0.4).round()),
    );

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

    earlyDeepRatio = deepMin > 0 ? earlyDeepMin / deepMin : 0.0;
    transitionRate =
        (totalSleepMin / 60.0) > 0 ? transitions / (totalSleepMin / 60.0) : 0.0;

    debugPrint('[SleepScoreDetails] 계산 완료:');
    debugPrint(
      '  - 실제 수면: ${totalSleepMin ~/ 60}h ${totalSleepMin % 60}m (target ${_targetMinutes}m)',
    );
    debugPrint(
      '  - 깊:${deepMin}m(${(deepPct * 100).toStringAsFixed(1)}%), '
      'REM:${remMin}m(${(remPct * 100).toStringAsFixed(1)}%), '
      '코어:${lightMin}m(${(lightPct * 100).toStringAsFixed(1)}%)',
    );
    debugPrint('  - 깨어있음: ${awakeMin}m, 깸: $wakeEpisodes회, 전환: $transitions회');
    debugPrint('  - 최종 점수: $recalculatedScore점');
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
              _buildMainScoreCard(),
              const SizedBox(height: 24),
              _buildSleepSummaryCard(),
              const SizedBox(height: 24),
              _buildScoreAnalysisCard(),
              const SizedBox(height: 24),
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
          const SizedBox(height: 8),
          if (_usingDefaultTarget)
            Text(
              '(목표 미설정 → 기본 8시간 기준)',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
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

    final tH = _targetMinutes ~/ 60;
    final tM = _targetMinutes % 60;

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
                  _usingDefaultTarget ? '목표 수면(기본값)' : '목표 수면',
                  '$tH시간 $tM분',
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
          _buildScoreFactorItem('수면 시간', '목표 대비 실제 수면량 (40%)'),
          _buildScoreFactorItem('수면 효율', '실제 수면 / 침대 시간 (20%)'),
          _buildScoreFactorItem('수면 구조', '깊은수면, REM, 코어수면 비율 (20%)'),
          _buildScoreFactorItem('수면 단편화', '깸 횟수 및 전환 빈도 (15%)'),
          _buildScoreFactorItem('초기 깊은수면', '수면 초반 깊은수면 분포 (5%)'),
        ],
      ),
    );
  }

  Widget _buildScoreFactorItem(String label, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.analytics,
              color: Color(0xFF6C63FF),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
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

    // 점수 기반 개선 제안
    if (recalculatedScore < 60) {
      suggestions.add(
        _buildSuggestionItem(
          '💤 전반적인 수면 개선',
          '수면 시간, 효율, 구조를 종합적으로 개선해보세요. 규칙적인 수면 패턴과 쾌적한 환경이 중요합니다.',
          Colors.red,
        ),
      );
    } else if (recalculatedScore < 80) {
      suggestions.add(
        _buildSuggestionItem(
          '⭐ 수면 품질 향상',
          '수면 점수를 더 높이기 위해 취침 전 스마트폰 사용을 줄이고, 침실 환경을 개선해보세요.',
          Colors.orange,
        ),
      );
    } else {
      suggestions.add(
        _buildSuggestionItem(
          '🎉 훌륭한 수면!',
          '좋은 수면 패턴을 유지하고 계세요. 현재의 수면 습관을 계속 지켜나가면 됩니다.',
          Colors.green,
        ),
      );
    }

    // 수면 효율성 기반 제안
    if (sleepEfficiency < 0.8) {
      suggestions.add(
        _buildSuggestionItem(
          '⏳ 수면 효율 개선',
          '침대에 있는 시간 대비 실제 수면이 부족해요. 중간 각성/뒤척임을 줄이면 좋아져요.',
          Colors.orange,
        ),
      );
    }

    // 수면 구조 기반 제안
    if (deepPct < 0.15 || remPct < 0.15) {
      suggestions.add(
        _buildSuggestionItem(
          '🏗️ 수면 구조 개선',
          '깊은수면이나 REM 수면이 부족해요. 규칙적인 수면 패턴과 쾌적한 환경이 도움이 됩니다.',
          Colors.purple,
        ),
      );
    }

    // 깸 횟수 기반 제안
    if (wakeEpisodes > 3) {
      suggestions.add(
        _buildSuggestionItem(
          '😴 수면 중 깸 줄이기',
          '수면 중 깨어나는 횟수가 많아요. 소음 차단, 암실, 쾌적한 온도로 깸을 줄여보세요.',
          Colors.red,
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
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    if (score >= 30) return Colors.deepOrange;
    return Colors.red;
  }

  String _getScoreMessage(int score) {
    if (score >= 70) return '훌륭한 수면!';
    if (score >= 50) return '좋은 수면';
    if (score >= 30) return '개선이 필요해요';
    return '수면 관리가 필요해요';
  }

  String _getScoreDescription(int score) {
    if (score >= 70) return '전문가 수준의 수면';
    if (score >= 50) return '일반적인 수면 품질';
    if (score >= 30) return '수면 패턴 개선 필요';
    return '수면 전문의 상담 권장';
  }
}
