// lib/onboarding/pages/welcome_page.dart
import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WelcomePage extends StatefulWidget {
  final VoidCallback onNext;
  const WelcomePage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _nameCtrl = TextEditingController();
  final storage = const FlutterSecureStorage();

  bool get isValid => _nameCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Image.asset('lib/assets/koala.png', width: 150),
              const SizedBox(height: 30),
              const Text(
                '안녕하세요.\n저는 수면요정 코알라, 알라야예요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '잘 자고 싶어서 오셨죠?\n도와드릴게요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '이름 입력해 주세요',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final name = _nameCtrl.text.trim();
                          OnboardingData.answers['name'] = name;
                          await storage.write(key: 'name', value: name);
                          await storage.write(key: 'username', value: name);
                          widget.onNext();
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8183D9),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '안녕 알라야!',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
