// lib/sleep_dashboard/sleep_score_details.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class SleepScoreDetailsPage extends StatefulWidget {
  final int deepMin;
  final int remMin;
  final int lightMin;
  final int awakeMin;
  final DateTime sleepStart;
  final DateTime sleepEnd;
  final Duration goalSleepDuration;
  final bool fallbackFromTwoDaysAgo;

  const SleepScoreDetailsPage({
    super.key,
    required this.deepMin,
    required this.remMin,
    required this.lightMin,
    required this.awakeMin,
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
  final storage = const FlutterSecureStorage();
  int serverSleepScore = 0;
  bool isLoading = true;

  // 수면 데이터 변수들 (서버에서 받은 데이터 사용)
  int get deepMin => widget.deepMin;
  int get remMin => widget.remMin;
  int get lightMin => widget.lightMin;
  int get awakeMin => widget.awakeMin;

  int get totalSleepMin => deepMin + remMin + lightMin;
  int get inBedMinutes => totalSleepMin + awakeMin;

  // 계산된 값들
  int wakeEpisodes = 0, transitions = 0;
  double deepPct = 0, remPct = 0, lightPct = 0, earlyDeepRatio = 0;
  double transitionRate = 0;
  double sleepEfficiency = 0.0; // 실제수면/침대시간

  // 애니메이션 컨트롤러
  late AnimationController _scoreController;
  late AnimationController _fadeController;
  late Animation<double> _scoreAnimation;

  // 서버에서 수면점수 받아오기
  Future<void> _loadSleepScoreFromServer() async {
    try {
      final userId = await storage.read(key: 'userID');
      if (userId == null) {
        debugPrint('[SleepScoreDetails] 사용자 ID가 없습니다');
        return;
      }

      // 어제 날짜로 API 호출 (수면 데이터는 전날 기준)
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final formattedDate = DateFormat('yyyy-MM-dd').format(yesterday);

      final uri = Uri.parse(
        'https://kooala.tassoo.uk/sleep-data/$userId/$formattedDate',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['data'];
        if (records != null && records is List && records.isNotEmpty) {
          final record = records[0];
          final score = (record['sleepScore'] ?? 0).toInt();

          if (mounted) {
            setState(() {
              serverSleepScore = score;
              isLoading = false;
            });
            // 서버 점수를 받아온 후 다시 계산
            _compute();
          }

          debugPrint('[SleepScoreDetails] 서버에서 수면점수 받아옴: $score');
        } else {
          debugPrint('[SleepScoreDetails] 서버에 수면 데이터가 없습니다');
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      } else {
        debugPrint(
          '[SleepScoreDetails] 서버에서 수면점수 받아오기 실패: ${response.statusCode}',
        );
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[SleepScoreDetails] 수면점수 받아오기 오류: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 서버 데이터를 사용한 수면점수 계산 함수 (로컬 계산용)
  int _calculateSleepScoreFromServer({
    required int deepMinutes,
    required int remMinutes,
    required int lightMinutes,
    required int awakeMinutes,
    required DateTime sleepStart,
    required DateTime sleepEnd,
    required Duration goalSleepDuration,
  }) {
    final totalSleepMinutes = deepMinutes + remMinutes + lightMinutes;
    final totalInBedMinutes = totalSleepMinutes + awakeMinutes;

    if (totalInBedMinutes <= 0) return 0;

    // 기본 점수 (0-100)
    int score = 0;

    // 1. 수면 시간 점수 (40점 만점)
    final goalMinutes = goalSleepDuration.inMinutes;
    final durationRatio = totalSleepMinutes / goalMinutes;

    if (durationRatio >= 1.0) {
      score += 40; // 목표 달성
    } else if (durationRatio >= 0.8) {
      score += 32; // 80% 이상
    } else if (durationRatio >= 0.6) {
      score += 24; // 60% 이상
    } else {
      score += (durationRatio * 40).round(); // 비례 점수
    }

    // 2. 수면 효율성 점수 (30점 만점)
    final efficiency = totalSleepMinutes / totalInBedMinutes;
    if (efficiency >= 0.9) {
      score += 30; // 90% 이상
    } else if (efficiency >= 0.8) {
      score += 24; // 80% 이상
    } else if (efficiency >= 0.7) {
      score += 18; // 70% 이상
    } else {
      score += (efficiency * 30).round(); // 비례 점수
    }

    // 3. 수면 단계 비율 점수 (30점 만점)
    final deepRatio = deepMinutes / totalSleepMinutes;
    final remRatio = remMinutes / totalSleepMinutes;

    // 깊은 수면 비율 (15점)
    if (deepRatio >= 0.2) {
      score += 15; // 20% 이상
    } else if (deepRatio >= 0.15) {
      score += 12; // 15% 이상
    } else if (deepRatio >= 0.1) {
      score += 9; // 10% 이상
    } else {
      score += (deepRatio * 15).round(); // 비례 점수
    }

    // REM 수면 비율 (15점)
    if (remRatio >= 0.2) {
      score += 15; // 20% 이상
    } else if (remRatio >= 0.15) {
      score += 12; // 15% 이상
    } else if (remRatio >= 0.1) {
      score += 9; // 10% 이상
    } else {
      score += (remRatio * 15).round(); // 비례 점수
    }

    return score.clamp(0, 100);
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

    recalculatedScore = 0;

    // 서버에서 수면점수 받아오기
    _loadSleepScoreFromServer();
    _startAnimations();
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
        oldWidget.deepMin != widget.deepMin ||
        oldWidget.remMin != widget.remMin ||
        oldWidget.lightMin != widget.lightMin ||
        oldWidget.awakeMin != widget.awakeMin ||
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
    debugPrint('[SleepScoreDetails] 서버 데이터 분석 시작');
    debugPrint(
      '[SleepScoreDetails] 깊은수면: ${deepMin}분, REM: ${remMin}분, 얕은수면: ${lightMin}분, 깨어있음: ${awakeMin}분',
    );
    debugPrint(
      '[SleepScoreDetails] 수면 시간: ${widget.sleepStart} ~ ${widget.sleepEnd}',
    );
    debugPrint(
      '[SleepScoreDetails] 목표 수면(분): ${widget.goalSleepDuration.inMinutes}',
    );

    // 서버에서 받은 수면점수 사용 (서버 점수가 있으면 사용, 없으면 로컬 계산)
    if (serverSleepScore > 0) {
      recalculatedScore = serverSleepScore;
      debugPrint('[SleepScoreDetails] 서버 수면점수 사용: $serverSleepScore');
    } else {
      recalculatedScore = _calculateSleepScoreFromServer(
        deepMinutes: deepMin,
        remMinutes: remMin,
        lightMinutes: lightMin,
        awakeMinutes: awakeMin,
        sleepStart: widget.sleepStart,
        sleepEnd: widget.sleepEnd,
        goalSleepDuration: widget.goalSleepDuration,
      );
      debugPrint('[SleepScoreDetails] 로컬 계산 수면점수 사용: $recalculatedScore');
    }

    // 기존 변수들도 계산 (UI 표시용)
    wakeEpisodes = transitions = 0;

    // 서버 데이터를 사용하므로 HealthDataPoint 처리 제거
    // 대신 서버에서 받은 데이터로 계산된 값들 사용

    // UI 표시용 변수들 계산
    sleepEfficiency = inBedMinutes > 0 ? totalSleepMin / inBedMinutes : 0.0;
    deepPct = totalSleepMin > 0 ? deepMin / totalSleepMin : 0.0;
    remPct = totalSleepMin > 0 ? remMin / totalSleepMin : 0.0;
    lightPct = totalSleepMin > 0 ? lightMin / totalSleepMin : 0.0;

    // 초반 deep 분포 계산 (서버 데이터에서는 단순화)
    final earlyDeepMin = (deepMin * 0.6).round();

    earlyDeepRatio = deepMin > 0 ? earlyDeepMin / deepMin : 0.0;
    transitionRate = 2.0; // 기본값

    debugPrint('[SleepScoreDetails] 서버 데이터 분석 완료:');
    debugPrint(
      '  - 총 수면: ${totalSleepMin}분 (${(totalSleepMin / 60).toStringAsFixed(1)}시간)',
    );
    debugPrint(
      '  - 깊은 수면: ${deepMin}분 (${(deepPct * 100).toStringAsFixed(1)}%)',
    );
    debugPrint(
      '  - REM 수면: ${remMin}분 (${(remPct * 100).toStringAsFixed(1)}%)',
    );
    debugPrint(
      '  - 얕은 수면: ${lightMin}분 (${(lightPct * 100).toStringAsFixed(1)}%)',
    );
    debugPrint('  - 깨어있음: ${awakeMin}분');
    debugPrint('  - 수면 효율: ${(sleepEfficiency * 100).toStringAsFixed(1)}%');
    debugPrint('  - 재계산된 점수: $recalculatedScore');
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body:
          isLoading
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
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 수면 점수 카드
                    _buildScoreCard(),
                    const SizedBox(height: 24),

                    // 수면 데이터 요약
                    _buildDataSummary(),
                    const SizedBox(height: 24),

                    // 수면 단계별 분석
                    _buildStageAnalysis(),
                    const SizedBox(height: 24),

                    // 수면 효율성 분석
                    _buildEfficiencyAnalysis(),
                    const SizedBox(height: 24),

                    // 수면 조언
                    _buildSleepAdvice(),
                  ],
                ),
              ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getScoreColor(recalculatedScore),
            _getScoreColor(recalculatedScore).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getScoreColor(recalculatedScore).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Text(
                '${(recalculatedScore * _scoreAnimation.value).round()}',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            _getScoreText(recalculatedScore),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '목표: ${widget.goalSleepDuration.inHours}시간 ${widget.goalSleepDuration.inMinutes % 60}분',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수면 데이터 요약',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '총 수면시간',
                  '${totalSleepMin ~/ 60}시간 ${totalSleepMin % 60}분',
                  Icons.bedtime,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '침대에 있던 시간',
                  '${inBedMinutes ~/ 60}시간 ${inBedMinutes % 60}분',
                  Icons.hotel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '수면 효율성',
                  '${(sleepEfficiency * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '깨어있던 시간',
                  '${awakeMin}분',
                  Icons.wb_sunny,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStageAnalysis() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수면 단계별 분석',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildStageItem('깊은 수면', deepMin, deepPct, const Color(0xFF4A90E2)),
          const SizedBox(height: 12),
          _buildStageItem('REM 수면', remMin, remPct, const Color(0xFF7B68EE)),
          const SizedBox(height: 12),
          _buildStageItem('얕은 수면', lightMin, lightPct, const Color(0xFF50C878)),
        ],
      ),
    );
  }

  Widget _buildStageItem(
    String stage,
    int minutes,
    double percentage,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${minutes}분 (${(percentage * 100).toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyAnalysis() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수면 효율성 분석',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildEfficiencyItem(
            '수면 효율성',
            '${(sleepEfficiency * 100).toStringAsFixed(1)}%',
            sleepEfficiency,
            '실제 수면시간 / 침대에 있던 시간',
          ),
          const SizedBox(height: 12),
          _buildEfficiencyItem(
            '전반부 깊은 수면 비율',
            '${(earlyDeepRatio * 100).toStringAsFixed(1)}%',
            earlyDeepRatio,
            '수면 초기 40% 구간의 깊은 수면 비율',
          ),
        ],
      ),
    );
  }

  Widget _buildEfficiencyItem(
    String title,
    String value,
    double ratio,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E21),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _getEfficiencyColor(ratio),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  String _getScoreText(int score) {
    if (score >= 80) return '훌륭한 수면!';
    if (score >= 60) return '양호한 수면';
    if (score >= 40) return '보통 수면';
    return '개선이 필요해요';
  }

  Color _getEfficiencyColor(double ratio) {
    if (ratio >= 0.9) return const Color(0xFF4CAF50);
    if (ratio >= 0.8) return const Color(0xFF8BC34A);
    if (ratio >= 0.7) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Widget _buildSleepAdvice() {
    final adviceList = _getSleepAdvice();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '수면 개선 조언',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...adviceList
              .map(
                (advice) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          advice,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.4,
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

  List<String> _getSleepAdvice() {
    final advice = <String>[];

    // 수면 점수별 조언
    if (recalculatedScore >= 80) {
      advice.addAll([
        '현재 수면 상태가 매우 좋습니다! 이 패턴을 유지하세요.',
        '규칙적인 수면 시간을 계속 지켜주세요.',
        '스트레스 관리와 운동을 꾸준히 하세요.',
      ]);
    } else if (recalculatedScore >= 60) {
      advice.addAll([
        '수면 상태가 양호합니다. 조금만 더 개선하면 완벽해요!',
        '수면 시간을 30분 정도 늘려보세요.',
        '잠들기 1시간 전에는 스마트폰 사용을 줄이세요.',
      ]);
    } else if (recalculatedScore >= 40) {
      advice.addAll([
        '수면 개선이 필요합니다. 다음 사항들을 시도해보세요:',
        '매일 같은 시간에 잠자리에 누우세요.',
        '침실을 어둡고 시원하게 유지하세요.',
        '카페인 섭취를 오후 2시 이후에는 피하세요.',
      ]);
    } else {
      advice.addAll([
        '수면 상태가 많이 부족합니다. 즉시 개선이 필요해요:',
        '수면 전문의 상담을 받아보세요.',
        '규칙적인 생활 패턴을 만들어보세요.',
        '스트레스 요인을 찾아 해결해보세요.',
        '잠들기 전 명상이나 스트레칭을 해보세요.',
      ]);
    }

    // 수면 단계별 조언
    final deepPct = deepMin / totalSleepMin;
    final remPct = remMin / totalSleepMin;
    final lightPct = lightMin / totalSleepMin;

    if (deepPct < 0.15) {
      advice.add('깊은 수면이 부족합니다. 규칙적인 운동과 스트레스 관리를 해보세요.');
    }

    if (remPct < 0.20) {
      advice.add('REM 수면이 부족합니다. 충분한 수면 시간을 확보하세요.');
    }

    if (lightPct > 0.60) {
      advice.add('얕은 수면이 많습니다. 수면 환경을 개선해보세요.');
    }

    // 수면 효율성 조언
    final sleepEfficiency = totalSleepMin / inBedMinutes;
    if (sleepEfficiency < 0.85) {
      advice.add('수면 효율이 낮습니다. 침대에서 깨어있는 시간을 줄여보세요.');
    }

    // 수면 시간 조언
    final sleepHours = totalSleepMin / 60;
    if (sleepHours < 7) {
      advice.add('수면 시간이 부족합니다. 최소 7시간 이상 자도록 노력하세요.');
    } else if (sleepHours > 9) {
      advice.add('수면 시간이 과도할 수 있습니다. 7-9시간 사이로 조절해보세요.');
    }

    return advice;
  }
}
