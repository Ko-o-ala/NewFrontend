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
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('lib/assets/koala.png', width: 120),
                const SizedBox(height: 30),
                Text(
                  '$username님,',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '편안한 수면을 위해\n몇 가지를 여쭤볼게요!\n어려운 건 없어요.\n차근차근 같이 해봐요 :)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8183D9),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('시작할게요!', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
