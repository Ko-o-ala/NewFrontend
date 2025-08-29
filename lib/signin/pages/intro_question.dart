// lib/onboarding/pages/intro_question_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IntroQuestionPage extends StatefulWidget {
  final VoidCallback onNext;
  const IntroQuestionPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<IntroQuestionPage> createState() => _IntroQuestionPageState();
}

class _IntroQuestionPageState extends State<IntroQuestionPage> {
  String username = '';

  @override
  void initState() {
    super.initState();
    loadName();
  }

  Future<void> loadName() async {
    final storage = FlutterSecureStorage();
    final storedName = await storage.read(key: 'username');
    setState(() {
      username = storedName ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Container(
        color: const Color(0xFF0A0E21), // SafeArea 위아래 흰색 방지
        child: SafeArea(
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
                          Icons.quiz,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '$username님, 안녕하세요!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '편안한 수면을 위해\n몇 가지를 여쭤볼게요!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 코알라 이미지와 설명
                Container(
                  width: double.infinity,
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
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'lib/assets/koala.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '어려운 건 없어요.\n차근차근 같이 해봐요 :)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 시작 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                    ),
                    child: const Text(
                      '시작할게요!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
