// lib/onboarding/problem_page.dart
import 'package:flutter/material.dart';
import '../onboarding_data.dart';

List<String> _normalizeNone(List<String> arr) {
  return arr.contains('none') ? <String>['none'] : arr;
}

/// 서버 스펙에 맞춘 매핑 (라벨 -> enum)
const Map<String, String> sleepIssuesMap = {
  '잠들기 어려움': 'fallAsleepHard',
  '자주 깨요': 'wakeOften',
  '일찍 깨요': 'wakeEarly',
  '낮 졸림': 'daySleepy',
  '악몽/불안': 'nightmares',
  '움직임 많음': 'movesALot',
  '없음': 'none', // none은 보통 단독 선택(배타) 처리
};

const Map<String, String> emotionalSleepMap = {
  '스트레스': 'stress',
  '불안감': 'anxiety',
  '외로움': 'loneliness',
  '긴장': 'tension',
  '기타': 'other',
};

/// 화면에 표시할 옵션 리스트 (라벨)
const List<String> sleepIssueLabels = [
  '잠들기 어려움',
  '자주 깨요',
  '일찍 깨요',
  '낮 졸림',
  '악몽/불안',
  '움직임 많음',
  '없음',
];

const List<String> emotionalInterferenceLabels = [
  '스트레스',
  '불안감',
  '외로움',
  '긴장',
  '기타',
];

class ProblemPage extends StatefulWidget {
  final VoidCallback onNext;
  const ProblemPage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<ProblemPage> createState() => _ProblemPageState();
}

class _ProblemPageState extends State<ProblemPage> {
  /// 화면에서 선택된 "라벨"들을 저장합니다.
  String? emotionalOtherInput;

  final Set<String> sleepIssues = {};
  final Set<String> emotionalSleepInterference = {};

  bool get isValid =>
      sleepIssues.isNotEmpty &&
      emotionalSleepInterference.isNotEmpty &&
      (!emotionalSleepInterference.contains('기타') ||
          (emotionalOtherInput != null && emotionalOtherInput!.isNotEmpty));

  /// 공용 멀티 셀렉트 위젯
  Widget _buildMultiSelectCard(
    String title,
    List<String> options,
    Set<String> selected,
    void Function(String, bool) onChanged,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Color(0xFFFFD700),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...options.map((option) {
            final isChecked = selected.contains(option);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color:
                    isChecked
                        ? const Color(0xFF6C63FF).withOpacity(0.2)
                        : const Color(0xFF0A0E21),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isChecked
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 26.0, right: 16),
                leading: CircleCheckbox(
                  value: isChecked,
                  onChanged: (checked) {
                    setState(() => onChanged(option, checked ?? false));
                  },
                  selectedColor: const Color(0xFF6C63FF),
                  unselectedBorderColor: Colors.white70,
                ),
                title: Text(
                  option,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => onChanged(option, !isChecked));
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 선택 토글 핸들러
  /// - sleepIssues의 '없음'은 배타적으로 처리
  void _toggleSelection(Set<String> targetSet, String value, bool checked) {
    final bool isSleepIssuesSet = identical(targetSet, sleepIssues);

    if (isSleepIssuesSet && value == '없음') {
      if (checked) {
        targetSet
          ..clear()
          ..add('없음');
      } else {
        targetSet.remove('없음');
      }
      return;
    }

    if (isSleepIssuesSet && checked) {
      targetSet.remove('없음'); // 다른 항목 선택 시 '없음' 해제
    }

    if (checked) {
      targetSet.add(value);
    } else {
      targetSet.remove(value);
    }
  }

  /// 전송용(저장용) 배열로 변환: 한글 라벨 -> 서버 enum 값
  List<String> _mapLabelsToEnums(
    Set<String> labels,
    Map<String, String> mapper,
  ) {
    return labels.map((l) => mapper[l]).whereType<String>().toList();
  }

  void _onNext() {
    final m = OnboardingData.answers;

    // 1) 라벨 → enum
    final sleepIssuesEnums = _mapLabelsToEnums(sleepIssues, sleepIssuesMap);
    final emotionalEnums = _mapLabelsToEnums(
      emotionalSleepInterference,
      emotionalSleepMap,
    );
    if (emotionalSleepInterference.contains('기타') &&
        emotionalOtherInput != null &&
        emotionalOtherInput!.isNotEmpty) {
      m['emotionalSleepInterferenceOther'] = emotionalOtherInput;
    }

    // 2) 'none' 단독 전송 보장
    m['sleepIssues'] = _normalizeNone(sleepIssuesEnums);
    m['emotionalSleepInterference'] = emotionalEnums;

    // 3) (선택) 디버그로 타입 확인 — 진짜 List<String>인지 확인
    debugPrint(
      'sleepIssues => ${m['sleepIssues'].runtimeType} : ${m['sleepIssues']}',
    );
    debugPrint(
      'emotionalSleepInterference => ${m['emotionalSleepInterference'].runtimeType} : ${m['emotionalSleepInterference']}',
    );

    // NOTE: 나머지 페이지에서 아래 필드들도 꼭 채워야 서버 통과
    // m['exerciseWhen']          // 'morning'|'day'|'night'|'none' (String)
    // m['sleepGoal']             // List<String>
    // m['preferenceBalance']     // double/int

    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
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
                        Icons.psychology,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '수면 문제 파악',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수면과 관련된 어려움과\n감정적 방해 요소를 알려주세요',
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

              const SizedBox(height: 30),

              // 코알라 이미지
              Container(
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
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'lib/assets/koala.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Q13 - 수면 관련 어려움
              _buildMultiSelectCard(
                'Q13. 최근에 수면과 관련해서 어려움을 느끼시나요?(모두 골라주세요)',
                sleepIssueLabels,
                sleepIssues,
                (value, checked) =>
                    _toggleSelection(sleepIssues, value, checked),
              ),

              // Q14 - 수면 방해 감정
              _buildMultiSelectCard(
                'Q14. 수면에 가장 방해되는 감정은 어떤 것인가요?(모두 골라주세요)',
                emotionalInterferenceLabels,
                emotionalSleepInterference,
                (value, checked) => _toggleSelection(
                  emotionalSleepInterference,
                  value,
                  checked,
                ),
              ),

              // 기타 감정 입력 필드
              if (emotionalSleepInterference.contains('기타'))
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Color(0xFF4CAF50),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "기타 감정 입력",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: '기타 감정을 입력해주세요',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A0E21),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFF6C63FF),
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged:
                            (value) => setState(
                              () => emotionalOtherInput = value.trim(),
                            ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isValid ? _onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color:
                          isValid
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 기존 CircleCheckbox 위젯
class CircleCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color selectedColor;
  final Color unselectedBorderColor;

  const CircleCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.selectedColor = const Color(0xFF6750A4),
    this.unselectedBorderColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = value ? selectedColor : unselectedBorderColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(20),
        splashColor: selectedColor.withOpacity(0.12),
        highlightColor: Colors.transparent,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child:
              value
                  ? Center(
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedColor,
                      ),
                    ),
                  )
                  : null,
        ),
      ),
    );
  }
}
