import 'package:flutter/material.dart';

class BugReportPage extends StatefulWidget {
  const BugReportPage({super.key});

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final TextEditingController _bugController = TextEditingController();
  final TextEditingController _featureController = TextEditingController();

  void _submitFeedback() {
    final bugText = _bugController.text.trim();
    final featureText = _featureController.text.trim();

    if (bugText.isEmpty && featureText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 가지 내용을 입력해주세요.')),
      );
      return;
    }

    // TODO: 서버 API와 연동하여 전송 처리
    print('버그 내용: $bugText');
    print('기능 제안: $featureText');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('제출 완료'),
        content: const Text('소중한 의견 감사합니다!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    _bugController.clear();
    _featureController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('버그 신고 / 기능 요청'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '앱 사용 중 불편하거나 개선이 필요한 부분이 있나요?\n아래 양식을 통해 버그를 신고하거나,\n추가로 원하는 기능을 제안해 주세요.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),

            const Text('버그를 신고하고 싶어요', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInputBox(_bugController, hint: '예: 날짜/시간, 사용 중인 기기, 오류 내용 등'),

            const SizedBox(height: 24),
            const Text('이런 기능이 있었으면 좋겠어요', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildInputBox(_featureController, hint: '예: 추가되었으면 하는 기능이나 바라는 점'),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('제출하기', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBox(TextEditingController controller, {String? hint}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration.collapsed(hintText: hint ?? ''),
      ),
    );
  }
}