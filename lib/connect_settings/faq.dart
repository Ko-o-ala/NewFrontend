import 'package:flutter/material.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<Map<String, String>> faqs = [
    {
      'question': '앱이 수면 상태를 어떻게 측정하나요?',
      'answer': '사용자의 수면 패턴, 기상 시간, 설문 응답, 사운드 사용 여부 등을 기반으로 수면 상태를 추정합니다. 스마트워치와 연동 시 더 정밀한 측정이 가능합니다.'
    },
    {
      'question': '추천 수면 사운드는 어떤 기준으로 선택되나요?',
      'answer': '설문 결과와 수면 유형을 분석해 최적화된 사운드를 추천합니다. 사용자의 선호에 따라 변경도 가능합니다.'
    },
    {
      'question': '개인정보는 안전하게 보호되나요?',
      'answer': '모든 데이터는 암호화되어 저장되며, 수면 개선 목적 외의 용도로는 사용되지 않습니다. 언제든 삭제도 가능합니다.'
    },
    {
      'question': '수면 점수는 어떤 기준으로 계산되나요?',
      'answer': '목표 수면 시간과 실제 수면 시간, 취침 시간의 일관성, 수면 중 깸 등을 종합적으로 분석해 점수를 산출합니다.'
    },
  ];

  List<bool> isExpanded = [false, false, false, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자주 묻는 질문'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              ListTile(
                title: Text(
                  faqs[index]['question']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Icon(isExpanded[index] ? Icons.expand_less : Icons.expand_more),
                onTap: () {
                  setState(() {
                    isExpanded[index] = !isExpanded[index];
                  });
                },
              ),
              if (isExpanded[index])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      faqs[index]['answer']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}
