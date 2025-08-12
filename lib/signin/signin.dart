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

  // 실시간 체크는 제거. 중복 결과만 표시하기 위해 아래 두 개만 유지
  bool? _isIdAvailable; // null: 모름, false: 중복
  String? _idHelperText; // 메시지

  int? selectedGender = 0;
  bool isPasswordVisible = false;
  bool agreedToPrivacy = false;
  bool isLoading = false;

  final storage = const FlutterSecureStorage();

  // "YYYY-MM-DD" 형식 + 실제 존재 날짜 검사
  final _birthdateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  bool _isBirthdateValid(String s) {
    final t = s.trim();
    if (!_birthdateRegex.hasMatch(t)) return false;
    final parts = t.split('-');
    final y = int.parse(parts[0]),
        m = int.parse(parts[1]),
        d = int.parse(parts[2]);
    final dt = DateTime(y, m, d);
    return dt.year == y && dt.month == m && dt.day == d;
  }

  // 입력하면 이전 중복 에러/메시지 지우기만
  void _onIdChanged(String _) {
    if (_isIdAvailable == false || _idHelperText != null) {
      setState(() {
        _isIdAvailable = null;
        _idHelperText = null;
      });
    }
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    birthdateController.dispose();
    super.dispose();
  }

  bool get isFormValid {
    return idController.text.trim().isNotEmpty &&
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
        final decoded = json.decode(response.body);
        final username = decoded['data']['name'];
        final token = decoded['data']['token'];

        await storage.write(key: 'username', value: username);
        await storage.write(key: 'jwt', value: token);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/complete');
      } else if (response.statusCode == 409) {
        // 아이디 중복
        if (!mounted) return;
        setState(() {
          _isIdAvailable = false;
          _idHelperText = '이미 사용 중인 아이디예요';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 아이디입니다. 다른 아이디를 입력해 주세요.')),
        );
      } else {
        throw Exception('회원가입 실패: ${response.statusCode} ${response.body}');
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
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  children: const [
                    Text(
                      '계정을 생성하세요',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1분이면 끝나요! 편하게 시작해보세요 😊',
                      style: TextStyle(fontSize: 14, color: Color(0xFF8183D9)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              _buildIdField(),
              const SizedBox(height: 12),

              _buildInputField(
                controller: birthdateController,
                hint: '생년월일 (예: 1995-08-07)',
                isValid: _isBirthdateValid(birthdateController.text),
              ),
              const SizedBox(height: 12),

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
              const SizedBox(height: 20),

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
                    onPressed:
                        () => setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        }),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Checkbox(
                    value: agreedToPrivacy,
                    onChanged:
                        (value) =>
                            setState(() => agreedToPrivacy = value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      '개인정보 처리방침을 읽고 동의합니다',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: isFormValid && !isLoading ? _handleSignUp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFormValid
                          ? const Color(0xFF9187F4)
                          : const Color(0xFF9187F4).withOpacity(0.3),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('시작하기'),
              ),
              const SizedBox(height: 20),
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
                ? const Icon(Icons.check, color: Colors.green)
                : const SizedBox(width: 0),
      ),
    );
  }

  Widget _buildIdField() {
    final bool duplicated = (_isIdAvailable == false);

    return TextField(
      controller: idController,
      onChanged: _onIdChanged,
      decoration: InputDecoration(
        hintText: '아이디',
        helperText: _idHelperText, // 409 이후에만 메시지 노출
        helperStyle: TextStyle(
          color: duplicated ? Colors.red : Colors.grey[600],
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        suffixIcon:
            duplicated ? const Icon(Icons.close, color: Colors.red) : null,
      ),
    );
  }
}
