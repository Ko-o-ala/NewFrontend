import 'package:flutter/material.dart';
import 'package:my_app/user_model.dart';
import 'package:my_app/connect_settings/manage_account.dart';
import 'package:my_app/connect_settings/notification.dart';
import 'package:my_app/connect_settings/faq.dart';
import 'package:my_app/connect_settings/ask_bug.dart';
import 'package:my_app/device/light_control_page.dart';
import 'package:my_app/device/alarm/alarm_dashboard_page.dart';

// 임시 사용자 정보 (나중에 서버 연동 시 수정)
Future<UserModel> fetchUserInfo() async {
  await Future.delayed(const Duration(seconds: 1));
  return UserModel(
    name: '이유나',
    email: 'yuna@example.com',
    profileImage: 'lib/assets/profile.jpg', // pubspec.yaml에 등록되어야 함
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: FutureBuilder<UserModel>(
        future: fetchUserInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('사용자 정보를 불러오지 못했습니다.'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('사용자 정보가 없습니다.'));
          }

          final user = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: AssetImage(user.profileImage),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSettingsItem(
                context,
                '내 계정 정보',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageAccountPage(),
                      ),
                    ),
              ),

              _buildSettingsItem(
                context,
                '수면 데이터 관리',
                onTap: () {
                  // 추후 연결
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '기기 제어 설정',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildSettingsItem(
                context,
                '조명 설정',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LightControlPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '고객 지원',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildSettingsItem(
                context,
                '자주 묻는 질문',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FAQPage()),
                    ),
              ),
              _buildSettingsItem(
                context,
                '이용 약관/개인정보 처리방침',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Notice()),
                    ),
              ),
              _buildSettingsItem(
                context,
                '버그 신고/기능 요청',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BugReportPage(),
                      ),
                    ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("로그아웃"),
                          content: const Text(
                            "앱에서 로그아웃하시겠어요?\n다시 사용하려면 로그인해야 해요.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("취소하기"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/',
                                  (route) => false,
                                );
                              },
                              child: const Text("로그아웃"),
                            ),
                          ],
                        ),
                  );
                },
                child: const Text('로그아웃', style: TextStyle(color: Colors.teal)),
              ),
              TextButton(
                onPressed: () {
                  // 계정 삭제 기능 연결 예정
                },
                child: const Text(
                  '계정 탈퇴하기',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String title, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
