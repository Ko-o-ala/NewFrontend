// home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('로그인 화면 가기'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/sleep'),
              child: const Text('수면 대시보드 가기'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/time-set'),
              child: const Text('수면 목표 설정 가기'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/test'),
              child: const Text('테스트 화면 바로가기'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/start'),
              child: const Text('시작하기'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/sound'),
              child: const Text('사운드 화면 가기'),
            ),
            const SizedBox(height: 20),
            // ✅ 서버 기반 차트로 이동: selectedDate만 넘김
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/sleep-chart',
                  arguments: {'date': DateTime.now()},
                );
              },
              child: const Text('수면 차트 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
