import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard 복사용

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<Map<String, String>> faqs = [
    {
      'question': '앱이 수면 상태를 어떻게 측정하나요?',
      'answer':
          '사용자의 수면 패턴, 기상 시간, 설문 응답, 사운드 사용 여부 등을 기반으로 수면 상태를 추정합니다. 스마트워치와 연동 시 더 정밀한 측정이 가능합니다.',
    },
    {
      'question': '추천 수면 사운드는 어떤 기준으로 선택되나요?',
      'answer': '설문 결과와 수면 유형을 분석해 최적화된 사운드를 추천합니다. 사용자의 선호에 따라 변경도 가능합니다.',
    },
    {
      'question': '개인정보는 안전하게 보호되나요?',
      'answer':
          '모든 데이터는 암호화되어 저장되며, 수면 개선 목적 외의 용도로는 사용되지 않습니다. 언제든 삭제도 가능합니다.',
    },
    {
      'question': '수면 점수는 어떤 기준으로 계산되나요?',
      'answer':
          '목표 수면 시간과 실제 수면 시간, 취침 시간의 일관성, 수면 중 깸 등을 종합적으로 분석해 점수를 산출합니다.',
    },
    {
      'question': '코알라 AI와 어떻게 대화하나요?',
      'answer':
          '홈 화면의 "코알라와 대화하기" 버튼을 누르고 마이크를 탭하면 음성으로 대화할 수 있습니다. AI가 수면에 대한 조언을 제공합니다.',
    },
    {
      'question': '수면 목표를 어떻게 설정하나요?',
      'answer':
          '수면 관리 섹션의 "수면 목표 설정"에서 개인 맞춤 수면 목표를 설정할 수 있습니다. 나이와 생활 패턴에 따라 최적의 수면 시간을 추천받을 수 있습니다.',
    },
    {
      'question': '회원 탈퇴는 어디서 하나요?',
      'answer': '프로필 수정 탭에 들어가서 맨 아래로 내려가면 계정 탈퇴하기 버튼이 있습니다.',
    },
  ];

  List<bool> isExpanded = [];

  @override
  void initState() {
    super.initState();
    isExpanded = List.generate(faqs.length, (index) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '자주 묻는 질문',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 섹션
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4B47BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.question_answer,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '궁금한 점이 있으신가요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '자주 묻는 질문들을 확인해보세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // FAQ 목록
              ...faqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 질문 부분
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isExpanded[index] = !isExpanded[index];
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6C63FF,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.help_outline,
                                  color: Color(0xFF6C63FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  faq['question']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedRotation(
                                turns: isExpanded[index] ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: const Color(0xFF6C63FF),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 답변 부분 (애니메이션)
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E21),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF6C63FF).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline,
                                    color: Color(0xFF4CAF50),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    faq['answer']!,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.white70,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        crossFadeState:
                            isExpanded[index]
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 300),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // 추가 도움말 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.support_agent,
                            color: Color(0xFFFF9800),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            '더 많은 도움이 필요하신가요?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '위의 FAQ에서 답을 찾지 못하셨다면, 고객 지원팀에 문의해주세요.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          const email = 'kooalasleep@gmail.com';
                          await showDialog(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF1D1E33),
                                  title: const Text(
                                    '고객 지원 이메일',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const SelectableText(
                                    'kooalasleep@gmail.com',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                          const ClipboardData(text: email),
                                        );
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('이메일이 복사되었어요.'),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        '복사',
                                        style: TextStyle(
                                          color: Color(0xFF6C63FF),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text(
                                        '닫기',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        },
                        icon: const Icon(Icons.email, color: Colors.white),
                        label: const Text(
                          '고객 지원 문의',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
