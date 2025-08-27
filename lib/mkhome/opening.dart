import 'package:flutter/material.dart';

class opening extends StatelessWidget {
  const opening({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // 🔹 배경 이미지
          Positioned.fill(
            child: Image.asset('lib/assets/opening.png', fit: BoxFit.cover),
          ),

          // 🔹 텍스트 & 버튼 레이어
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.75), // 🔸 버튼 위치 조정
                  // 🔸 홈으로 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("홈으로"),
                    ),
                  ),
                  const SizedBox(height: 16), // 🔸 버튼 간격
                  // 🔸 시작하기 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/start');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("시작하기"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
