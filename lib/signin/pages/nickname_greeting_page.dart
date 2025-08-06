// lib/onboarding/pages/nickname_greet_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'intro_question.dart'; // 📌 다음 페이지 import 추가

class NicknameGreetPage extends StatefulWidget {
  final VoidCallback onNext;
  const NicknameGreetPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<NicknameGreetPage> createState() => _NicknameGreetPageState();
}

class _NicknameGreetPageState extends State<NicknameGreetPage> {
  String? name;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    storage.read(key: 'username').then((v) => setState(() => name = v));
  }

  void _goToIntroPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => IntroQuestionPage(
              onNext: () {
                // 나중에 질문 시작 페이지로 이동할 수 있어요
                // Navigator.push(context, MaterialPageRoute(builder: (_) => NextPage()));
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: Center(
        child:
            name == null
                ? const CircularProgressIndicator()
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('lib/assets/koala.png', width: 130),
                    const SizedBox(height: 24),
                    Text(
                      '${name!}님!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('멋진 이름이에요 😊', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: widget.onNext, // ✅ 버튼 클릭 시 페이지 이동
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8183D9),
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '고마워!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
