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

const Map<String, String> soundAutoOffTypeMap = {
  '고정 시간': 'fixedTime',
  '수면 감지': 'autoDetect',
  '수동': 'manual',
  '사용 없음': 'notUsed',
};

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
          width: 17, // ⬅️ 기존 24 → 20
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black87, width: 2),
          ),
          child:
              value
                  ? Center(
                    child: Container(
                      width: 10, // ⬅️ 기존 12 → 10
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

class DevicePage extends StatefulWidget {
  final VoidCallback onNext;
  const DevicePage({Key? key, required this.onNext}) : super(key: key);

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  String? soundAutoOffType;

  bool get isValid => selectedDevices.isNotEmpty && soundAutoOffType != null;

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
                'Q18. 어떤 기기를 사용하나요?',
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

              const SizedBox(height: 24),
              const Text(
                'Q19. 원하는 사운드 자동 종료 방식은?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...['고정 시간', '수면 감지', '수동', '사용 없음'].map(
                (option) => RadioListTile(
                  title: Text(option),
                  value: option,
                  groupValue: soundAutoOffType,
                  onChanged: (value) {
                    setState(() => soundAutoOffType = value);
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
                          m['soundAutoOffType'] = soundAutoOffType;

                          await storage.write(
                            key: 'sleepDevicesUsed',
                            value: jsonEncode(
                              selectedDevices
                                  .map((e) => deviceMap[e]!)
                                  .toList(),
                            ),
                          );
                          await storage.write(
                            key: 'soundAutoOffType',
                            value: soundAutoOffTypeMap[soundAutoOffType]!,
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
