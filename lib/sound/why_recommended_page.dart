// lib/sound/why_recommended_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/services/global_mini_player.dart'; // 전역 미니플레이어

class WhyRecommendedPage extends StatefulWidget {
  final String userId;
  final DateTime date;

  const WhyRecommendedPage({Key? key, required this.userId, required this.date})
    : super(key: key);

  @override
  State<WhyRecommendedPage> createState() => _WhyRecommendedPageState();
}

class _WhyRecommendedPageState extends State<WhyRecommendedPage> {
  final storage = const FlutterSecureStorage();

  bool loading = true;
  String? error;
  String recommendedText = '';
  List<String> topSounds = [];

  String _ymd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<Map<String, String>> _authHeaders() async {
    final raw = await storage.read(key: 'jwt');
    if (raw == null || raw.trim().isEmpty) {
      throw Exception('JWT가 없습니다. 다시 로그인해주세요.');
    }
    final tokenOnly =
        raw.startsWith(RegExp(r'Bearer\s', caseSensitive: false))
            ? raw.split(' ').last
            : raw;
    final bearer = 'Bearer $tokenOnly';
    return {
      'Authorization': bearer,
      HttpHeaders.authorizationHeader: bearer,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _fetch() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dateStr = _ymd(widget.date);
      final url = Uri.parse(
        'https://kooala.tassoo.uk/recommend-sound/${Uri.encodeComponent(widget.userId)}/$dateStr/results',
      );
      final resp = await http.get(url, headers: await _authHeaders());
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final Map<String, dynamic> body = json.decode(resp.body);
      recommendedText =
          (body['recommended_text'] ?? body['recommendation_text'] ?? '')
              .toString();

      final recs = (body['recommended_sounds'] as List?) ?? [];
      topSounds =
          recs
              .whereType<Map>()
              .map((e) => e['filename'])
              .whereType<String>()
              .take(3)
              .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '왜 사운드를 추천하나요?',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: '다시 불러오기',
            icon: const Icon(Icons.refresh),
            onPressed: loading ? null : _fetch,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
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
                      children: const [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'AI가 이렇게 추천했어요',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '당신의 수면 패턴과 선호도를 분석한 결과입니다',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                      ),
                    )
                  else ...[
                    if (topSounds.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(16),
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
                                Icon(
                                  Icons.music_note,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '추천된 사운드',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  topSounds.asMap().entries.map((e) {
                                    final idx = e.key;
                                    final label = e.value
                                        .replaceAll('.mp3', '')
                                        .replaceAll('_', ' ');
                                    final grad =
                                        idx < 3
                                            ? const [
                                              Color(0xFFFFD700),
                                              Color(0xFFFFA000),
                                            ]
                                            : const [
                                              Color(0xFF6C63FF),
                                              Color(0xFF4B47BD),
                                            ];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: grad,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${idx + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(16),
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
                              Icon(
                                Icons.psychology,
                                color: Color(0xFFFFD700),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'AI 분석 결과',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E21),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFF6C63FF,
                                ).withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              recommendedText.isEmpty
                                  ? '추천 이유를 불러오지 못했습니다.'
                                  : recommendedText,
                              style: const TextStyle(
                                color: Colors.white,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          GlobalMiniPlayer(), // 하단 고정 미니플레이어
        ],
      ),
    );
  }
}
