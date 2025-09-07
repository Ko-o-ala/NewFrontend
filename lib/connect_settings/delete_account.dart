import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _agreed = false;

  void _handleDelete() {
    if (!_agreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("먼저 안내사항에 동의해주세요.")));
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("계정을 정말 탈퇴할까요?"),
            content: const Text("계정을 탈퇴하면 모든 데이터가 삭제되며, 복구할 수 없습니다."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("취소"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                  _performDelete();
                },
                child: const Text("탈퇴하기"),
              ),
            ],
          ),
    );
  }

  void _performDelete() async {
    // TODO: 나중에 서버에 탈퇴 요청 보내기 (DELETE API)

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("계정이 탈퇴되었습니다.")));

    // 로그아웃 처리 및 초기 화면으로 이동
    await AuthService.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("계정 탈퇴하기"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "정말 계정을 탈퇴하시겠어요?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "계정을 탈퇴하면 모든 수면 데이터, 기록, 설정 정보가 영구적으로 삭제되며 복구할 수 없습니다.\n\n아래 내용을 꼭 확인해주세요:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("- 저장된 수면 데이터가 모두 삭제됩니다."),
                  SizedBox(height: 4),
                  Text("- 프리미엄 구독이 자동으로 해지됩니다."),
                  SizedBox(height: 4),
                  Text("- 탈퇴 후 같은 이메일로 재가입은 가능하지만, 기존 데이터는 복원되지 않습니다."),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value!),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text("위 내용을 모두 이해했으며, 계정을 탈퇴하겠습니다."),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  "계속하기",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
