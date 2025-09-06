import 'package:flutter/material.dart';

class WeekdaySelector extends StatelessWidget {
  final Set<int> selectedDays;
  final ValueChanged<int> onDayToggle;

  const WeekdaySelector({
    Key? key,
    required this.selectedDays,
    required this.onDayToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: List.generate(7, (index) {
        final isSelected = selectedDays.contains(index);
        return GestureDetector(
          onTap: () => onDayToggle(index),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFF8183D9) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center, // ✅ 완전 중앙 정렬
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dayLabels[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }),
    );
  }
}
