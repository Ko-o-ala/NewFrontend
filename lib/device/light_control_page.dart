import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LightControlPage extends StatefulWidget {
  const LightControlPage({super.key});

  @override
  State<LightControlPage> createState() => _LightControlPageState();
}

class _LightControlPageState extends State<LightControlPage> {
  // UI 상태
  double brightness = 60;
  String colorTemperature = '따뜻한';

  // 인증/네트워크
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 색온도 → HEX 매핑 (서로 확실히 다른 톤)
  static const Map<String, String> _tempToHex = {
    '따뜻한': '#FFB74D', // warm amber
    '중간': '#FFFFFF', // neutral white
    '차가운': '#64B5F6', // cool blue
  };

  Future<Map<String, String>> _authHeaders() async {
    String? raw = await _storage.read(key: 'jwt');
    if (raw == null || raw.trim().isEmpty) {
      throw Exception('JWT가 없습니다. 다시 로그인해주세요.');
    }
    final tokenOnly =
        raw.startsWith(RegExp(r'Bearer\\s', caseSensitive: false))
            ? raw.split(' ').last
            : raw;
    final bearer = 'Bearer $tokenOnly';
    return {
      'Authorization': bearer,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  /// 저장 버튼: 밝기 적용된 HEX로 POST 전송
  Future<void> _saveLedColor() async {
    final baseHex = _tempToHex[colorTemperature] ?? '#FFFFFF';
    final hexToSend = _applyBrightnessToHex(baseHex, brightness);
    try {
      final url = Uri.parse('https://kooala.tassoo.uk/users/create/hardware');
      final resp = await http.post(
        url,
        headers: await _authHeaders(),
        body: json.encode({"RGB": hexToSend}),
      );

      if (resp.statusCode == 401) {
        throw Exception('Unauthorized (401)');
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('LED 색상 저장 완료: $hexToSend')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('LED 색상 저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseHex = _tempToHex[colorTemperature] ?? '#FFFFFF';
    final previewHex = _applyBrightnessToHex(baseHex, brightness);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          '조명 관리',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('LED 색상 저장'),
              onPressed: _saveLedColor,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              '조명 색 온도',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: [
                colorTemperature == '따뜻한',
                colorTemperature == '중간',
                colorTemperature == '차가운',
              ],
              onPressed: (index) {
                setState(() {
                  colorTemperature = ['따뜻한', '중간', '차가운'][index];
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('따뜻한'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('중간'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('차가운'),
                ),
              ],
            ),

            // 현재 선택 색 미리보기 + 저장
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hexToColor(previewHex),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 10),
                const SizedBox(height: 280),

                Expanded(child: Text('현재 선택 색상: $previewHex')),
              ],
            ),

            // 간격 넉넉하게
            const SizedBox(height: 30),

            const Text('밝기 조절'),
            Slider(
              value: brightness,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${brightness.toInt()}%',
              onChanged: (v) => setState(() => brightness = v),
            ),

            // 하단 여백 넉넉하게
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ===== 유틸: HEX <-> Color + 밝기 적용 =====

Color _hexToColor(String hex) {
  final clean = hex.replaceAll('#', '');
  final a = clean.length == 8 ? clean.substring(0, 2) : 'FF';
  final r = clean.length == 8 ? clean.substring(2, 4) : clean.substring(0, 2);
  final g = clean.length == 8 ? clean.substring(4, 6) : clean.substring(2, 4);
  final b = clean.length == 8 ? clean.substring(6, 8) : clean.substring(4, 6);
  return Color(int.parse('$a$r$g$b', radix: 16));
}

String _colorToHex(Color c) {
  String to2(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${to2(c.red)}${to2(c.green)}${to2(c.blue)}';
}

/// 밝기(0~100)를 기본 HEX 색에 적용해서 새 HEX 반환 (HSV로 명도만 조절)
String _applyBrightnessToHex(String baseHex, double brightnessPercent) {
  final base = _hexToColor(baseHex);
  final hsv = HSVColor.fromColor(base);
  final v = (brightnessPercent.clamp(0, 100)) / 100.0;
  final adjusted = hsv.withValue(v.clamp(0.1, 1.0)).toColor(); // 너무 어두운 0 방지
  return _colorToHex(adjusted);
}
