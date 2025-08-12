import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  int? selectedGender = 0;
  bool isPasswordVisible = false;
  bool agreedToPrivacy = false;
  bool isLoading = false;

  final storage = FlutterSecureStorage();
  // "YYYY-MM-DD" 형식 + 실제로 존재하는 날짜인지 검사
  final _birthdateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  bool _isBirthdateValid(String s) {
    final t = s.trim();
    if (!_birthdateRegex.hasMatch(t)) return false;
    final parts = t.split('-');
    final y = int.parse(parts[0]),
        m = int.parse(parts[1]),
        d = int.parse(parts[2]);
    final dt = DateTime(y, m, d);
    // 2025-02-30 같은 잘못된 날짜 걸러내기
    return dt.year == y && dt.month == m && dt.day == d;
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    birthdateController.dispose(); // 추가
    super.dispose();
  }

  bool get isFormValid {
    return idController.text.isNotEmpty &&
        passwordController.text.length >= 6 &&
        _isBirthdateValid(birthdateController.text) &&
        agreedToPrivacy;
  }

  Future<void> _handleSignUp() async {
    setState(() => isLoading = true);

    try {
      final savedName = await storage.read(key: 'name') ?? '사용자';

      final response = await http.post(
        Uri.parse('https://kooala.tassoo.uk/users/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userID': idController.text.trim(),
          'name': savedName,
          'password': passwordController.text,
          'birthdate': birthdateController.text.trim(),
          'gender': selectedGender,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('회원가입 응답: ${response.body}');

        final decoded = json.decode(response.body);
        final username = decoded['data']['name'];
        final token = decoded['data']['token'];
        print('✅ JWT토큰: $token');

        await storage.write(key: 'username', value: username);
        await storage.write(key: 'jwt', value: token);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete'); // 🎯 여기로 이동
      } else {
        throw Exception('회원가입 실패: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(height: 10),
              Center(
                child: Column(
                  children: [
                    Text(
                      '계정을 생성하세요',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1분이면 끝나요! 편하게 시작해보세요 😊',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8183D9), // 강조 컬러
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),

              _buildInputField(
                controller: idController,
                hint: '아이디',
                isValid: idController.text.isNotEmpty,
              ),
              SizedBox(height: 12),
              // 생년월일 입력
              _buildInputField(
                controller: birthdateController,
                hint: '생년월일 (예: 1995-08-07)',
                isValid: _isBirthdateValid(birthdateController.text),
              ),
              SizedBox(height: 12),

              // 성별 선택 드롭다운
              DropdownButtonFormField<int>(
                value: selectedGender,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('선택 안함')),
                  DropdownMenuItem(value: 1, child: Text('남자')),
                  DropdownMenuItem(value: 2, child: Text('여자')),
                ],
                onChanged:
                    (value) => setState(() => selectedGender = value ?? 0),
                decoration: InputDecoration(
                  hintText: '성별 선택',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 20),

              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),

              Row(
                children: [
                  Checkbox(
                    value: agreedToPrivacy,
                    onChanged: (value) {
                      setState(() {
                        agreedToPrivacy = value!;
                      });
                    },
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '개인정보 처리방침을 읽고 동의합니다',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              ElevatedButton(
                onPressed: isFormValid && !isLoading ? _handleSignUp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFormValid
                          ? Color(0xFF9187F4)
                          : Color(0xFF9187F4).withOpacity(0.3),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child:
                    isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('시작하기'),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required bool isValid,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        suffixIcon:
            isValid
                ? Icon(Icons.check, color: Colors.green)
                : SizedBox(width: 0),
      ),
    );
  }
}
