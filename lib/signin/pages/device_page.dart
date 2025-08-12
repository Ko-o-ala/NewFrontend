import 'dart:convert';
import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
Set<String> selectedDevices = {};
const Map<String, String> deviceMap = {
  '스마트워치': 'watch',
  '스마트폰 앱': 'app',
  '스마트 조명': 'light',
  '사운드 기기': 'speaker',
  '없음': 'none',
};

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

class DevicePage extends StatefulWidget {
  final VoidCallback onNext;
  const DevicePage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool get isValid => selectedDevices.isNotEmpty != null;

  final deviceOptions = ['스마트워치', '스마트폰 앱', '스마트 조명', '사운드 기기', '없음'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Image.asset('lib/assets/koala.png', width: 120)),
              const SizedBox(height: 16),

              const Text(
                'Q18. 평소에 어떤 기기를 사용하시나요?(모두 골라주세요)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...deviceOptions.map(
                (option) => ListTile(
                  contentPadding: const EdgeInsets.only(left: 26.0, right: 0),
                  tileColor: Colors.transparent, // 배경색 제거
                  selectedTileColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  leading: CircleCheckbox(
                    value: selectedDevices.contains(option),
                    onChanged: (checked) {
                      setState(() {
                        _handleDeviceSelect(option, checked ?? false);
                      });
                    },
                  ),
                  title: Text(option),
                  onTap: () {
                    final checked = !selectedDevices.contains(option);
                    setState(() {
                      _handleDeviceSelect(option, checked);
                    });
                  },
                ),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed:
                    isValid
                        ? () async {
                          final m = OnboardingData.answers;
                          m['sleepDevicesUsed'] = selectedDevices.toList();

                          await storage.write(
                            key: 'sleepDevicesUsed',
                            value: jsonEncode(
                              selectedDevices
                                  .map((e) => deviceMap[e]!)
                                  .toList(),
                            ),
                          );

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

  void _handleDeviceSelect(String option, bool checked) {
    if (option == '없음') {
      if (checked) {
        selectedDevices = {'없음'};
      } else {
        selectedDevices.remove('없음');
      }
    } else {
      selectedDevices.remove('없음');
      if (checked) {
        selectedDevices.add(option);
      } else {
        selectedDevices.remove(option);
      }
    }
  }
}
