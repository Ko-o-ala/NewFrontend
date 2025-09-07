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
                  SizedBox(
                    height: screenHeight * 0.65,
                  ), // 🔸 버튼 위치 조정 (0.75 → 0.65)
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
                  const SizedBox(height: 12), // 🔸 버튼 간격 (16 → 12)
                  // 🔸 이미 계정이 있나요? 링크
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text(
                        '로그인하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12), // 🔸 링크와 버튼 간격 (16 → 12)
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
                  const SizedBox(height: 20), // 🔸 하단 여백 추가
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
