import 'package:flutter/material.dart';
import '../onboarding_data.dart';

class ProblemPage extends StatefulWidget {
  final VoidCallback onNext;
  const ProblemPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  Set<String> sleepIssues = {};
  Set<String> emotionalSleepInterference = {};

  bool get isValid =>
      sleepIssues.isNotEmpty && emotionalSleepInterference.isNotEmpty;

  Widget _multiSelectQuestion(
    String title,
    List<String> options,
    Set<String> selected,
    void Function(String, bool) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...options.map((option) {
          final isChecked = selected.contains(option);
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 26.0, right: 0),
            leading: CircleCheckbox(
              value: isChecked,
              onChanged: (checked) {
                setState(() {
                  onChanged(option, checked ?? false);
                });
              },
            ),
            title: Text(option),
            onTap: () {
              setState(() {
                onChanged(option, !isChecked);
              });
            },
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  void _toggleSelection(Set<String> targetSet, String value, bool checked) {
    if (checked) {
      targetSet.add(value);
    } else {
      targetSet.remove(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset('lib/assets/koala.png', width: 120),
              const SizedBox(height: 16),
              _multiSelectQuestion(
                'Q13. 수면 문제는?',
                ['잠들기 어려움', '자주 깨요', '일찍 깨요', '낮 졸림', '악몽/불안', '움직임 많음', '없음'],
                sleepIssues,
                (value, checked) =>
                    _toggleSelection(sleepIssues, value, checked),
              ),
              _multiSelectQuestion(
                'Q14. 감정으로 인한 방해는?',
                ['스트레스', '불안감', '외로움', '긴장', '기타'],
                emotionalSleepInterference,
                (value, checked) => _toggleSelection(
                  emotionalSleepInterference,
                  value,
                  checked,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () {
                          final m = OnboardingData.answers;
                          m['sleepIssues'] = sleepIssues.toList();
                          m['emotionalSleepInterference'] =
                              emotionalSleepInterference.toList();
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
                child: const Text('다음', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// CircleCheckbox 위젯은 기존에 만든 거 그대로 사용하세요!
class CircleCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const CircleCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 2),
          ),
          child:
              value
                  ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black87,
                      ),
                    ),
                  )
                  : null,
        ),
      ),
    );
  }
}
