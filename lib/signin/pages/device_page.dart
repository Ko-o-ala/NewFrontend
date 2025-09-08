import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool get isValid => selectedDevices.isNotEmpty;

  final deviceOptions = ['스마트워치', '스마트폰 앱', '스마트 조명', '사운드 기기', '없음'];

  late ScrollController _scrollController;
  final GlobalKey _question18Key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToQuestion(GlobalKey key) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final scrollOffset =
          _scrollController.offset + position.dy - 200; // 200px 여백으로 증가
      _scrollController.animateTo(
        scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 UI 스타일 설정 (상태바, 네비게이션바 색상)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0A0E21), // 상태바 배경색
        statusBarIconBrightness: Brightness.light, // 상태바 아이콘 색상 (밝게)
        systemNavigationBarColor: Color(0xFF0A0E21), // 하단 네비게이션바 배경색
        systemNavigationBarIconBrightness: Brightness.light, // 하단 아이콘 색상 (밝게)
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '알라와 코잘라',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
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
                        Icons.devices,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '사용 기기 설정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수면 관리에 사용하는\n기기들을 선택해주세요',
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

              const SizedBox(height: 20),

              // 기기 선택 카드
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _scrollToQuestion(_question18Key),
                      child: Row(
                        key: _question18Key,
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
                            child: const Text(
                              "Q18. 평소에 수면을 도와주는 기기를 사용하시나요? 있다면 어떤 기기를 사용하시나요? (모두 고르시오)",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.touch_app,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...deviceOptions.map(
                      (option) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              selectedDevices.contains(option)
                                  ? const Color(0xFF6C63FF).withOpacity(0.2)
                                  : const Color(0xFF0A0E21),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selectedDevices.contains(option)
                                    ? const Color(0xFF6C63FF)
                                    : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 26.0,
                            right: 16,
                          ),
                          tileColor: Colors.transparent,
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
                            selectedColor: const Color(0xFF6C63FF),
                            unselectedBorderColor: Colors.white70,
                          ),
                          title: Text(
                            option,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  selectedDevices.contains(option)
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            final checked = !selectedDevices.contains(option);
                            setState(() {
                              _handleDeviceSelect(option, checked);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 다음 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
