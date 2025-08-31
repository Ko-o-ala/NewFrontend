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
  final TextEditingController genderController = TextEditingController();
  // 실시간 체크는 제거. 중복 결과만 표시하기 위해 아래 두 개만 유지
  bool? _isIdAvailable; // null: 모름, false: 중복
  String? _idHelperText; // 메시지

  int? selectedGender;
  bool isPasswordVisible = false;
  bool agreedToPrivacy = false;
  bool isLoading = false;

  // 오류 메시지 추가
  String? _passwordError;
  String? _birthdateError;
  String? _generalError;

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

  // 비밀번호 변경 시 오류 메시지 지우기
  void _onPasswordChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = null;
      } else if (value.length < 6) {
        _passwordError = '비밀번호는 6글자 이상 입력해주세요';
      } else {
        _passwordError = null;
      }
    });
  }

  // 생년월일 변경 시 오류 메시지 지우기
  void _onBirthdateChanged(String value) {
    setState(() {
      if (value.isEmpty) {
        _birthdateError = null;
      } else if (!_isBirthdateValid(value)) {
        _birthdateError = '올바른 생년월일 형식으로 입력해주세요';
      } else {
        _birthdateError = null;
      }
    });
  }

  // 폼 유효성 검사 및 오류 메시지 생성
  String? _validateForm() {
    // 아이디 검사
    if (idController.text.trim().isEmpty) {
      return '아이디를 입력해주세요';
    }

    // 생년월일 검사
    if (birthdateController.text.trim().isEmpty) {
      return '생년월일을 입력해주세요';
    }
    if (!_isBirthdateValid(birthdateController.text)) {
      return '올바른 생년월일 형식으로 입력해주세요 (예: 1995-08-07)';
    }
    // 비밀번호 검사
    if (passwordController.text.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (passwordController.text.length < 6) {
      return '비밀번호는 6글자 이상 입력해주세요';
    }
    if (selectedGender == null) {
      return '성별을 선택해주세요';
    }

    // 개인정보 동의 검사
    if (!agreedToPrivacy) {
      return '개인정보 처리방침에 동의해주세요';
    }

    return null;
  }

  // 시작하기 버튼 클릭 시 유효성 검사
  void _onStartButtonPressed() {
    final errorMessage = _validateForm();
    if (errorMessage != null) {
      setState(() {
        _generalError = errorMessage;
      });
      // 3초 후 오류 메시지 자동 제거
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _generalError = null;
          });
        }
      });
    } else {
      _handleSignUp();
    }
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    birthdateController.dispose();
    genderController.dispose();
    super.dispose();
  }

  bool get isFormValid {
    return idController.text.trim().isNotEmpty &&
        passwordController.text.length >= 6 &&
        _isBirthdateValid(birthdateController.text) &&
        agreedToPrivacy;
  }

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
    );
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
        await _showAlert('아이디 중복', '이미 사용 중인 아이디입니다. 다른 아이디를 입력해 주세요.');
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
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 뒤로가기 버튼
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: 20),

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
                        Icons.person_add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '계정을 생성하세요',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1분이면 끝나요!\n편하게 시작해보세요 😊',
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
                child: Column(
                  children: [
                    Image.asset(
                      'lib/assets/koala.png',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '코알라와 함께\n수면 관리의 여정을 시작해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 회원가입 폼
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF4CAF50),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "회원가입 정보",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 아이디 입력
                    _buildIdField(),
                    const SizedBox(height: 16),

                    // 생년월일 입력
                    _buildInputField(
                      controller: birthdateController,
                      hint: '생년월일 (예: 1995-08-07)',
                      isValid: _isBirthdateValid(birthdateController.text),
                      icon: Icons.calendar_today,
                      errorMessage: _birthdateError,
                    ),
                    const SizedBox(height: 16),

                    // 성별 선택
                    _buildInputField(
                      controller: genderController,
                      hint: '성별 선택',
                      isValid: selectedGender != null,
                      icon: Icons.person_outline,
                      errorMessage: null,
                      isReadOnly: true,
                      onTap: _showGenderPicker,
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 입력
                    TextField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      onChanged: _onPasswordChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '비밀번호',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        helperText: _passwordError ?? '6글자 이상 입력해주세요',
                        helperStyle: TextStyle(
                          color:
                              _passwordError != null
                                  ? Colors.red
                                  : Colors.white54,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0A0E21),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color:
                                _passwordError != null
                                    ? Colors.red.withOpacity(0.5)
                                    : const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color:
                                _passwordError != null
                                    ? Colors.red.withOpacity(0.5)
                                    : const Color(0xFF6C63FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color:
                                _passwordError != null
                                    ? Colors.red
                                    : const Color(0xFF6C63FF),
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Color(0xFF6C63FF),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white54,
                          ),
                          onPressed:
                              () => setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 개인정보 동의
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E21),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color:
                              agreedToPrivacy
                                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                                  : const Color(0xFF6C63FF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: agreedToPrivacy,
                            onChanged:
                                (value) => setState(
                                  () => agreedToPrivacy = value ?? false,
                                ),
                            activeColor: const Color(0xFF4CAF50),
                            checkColor: Colors.white,
                          ),
                          Expanded(
                            child: Text(
                              '개인정보 처리방침을 읽고 동의합니다',
                              style: TextStyle(
                                color:
                                    agreedToPrivacy
                                        ? const Color(0xFF4CAF50)
                                        : Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 오류 메시지 표시
              if (_generalError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _generalError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_generalError != null) const SizedBox(height: 20),

              // 시작하기 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !isLoading ? _onStartButtonPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                  child:
                      isLoading
                          ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            '시작하기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required bool isValid,
    required IconData icon,
    String? errorMessage,
    bool isReadOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            onTap: onTap,
            showCursor: !isReadOnly ? null : false,
            enableInteractiveSelection: !isReadOnly,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF0A0E21),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color:
                      errorMessage != null
                          ? Colors.red.withOpacity(0.5)
                          : const Color(0xFF6C63FF).withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color:
                      errorMessage != null
                          ? Colors.red.withOpacity(0.5)
                          : const Color(0xFF6C63FF).withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color:
                      errorMessage != null
                          ? Colors.red
                          : const Color(0xFF6C63FF),
                  width: 2,
                ),
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
              suffixIcon:
                  isValid
                      ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                      : errorMessage != null && errorMessage.isNotEmpty
                      ? Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 16,
                        ),
                      )
                      : isReadOnly
                      ? const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF6C63FF),
                        size: 24,
                      )
                      : const SizedBox(width: 0),
            ),
          ),
        ),
        if (errorMessage != null && errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildIdField() {
    final bool duplicated = (_isIdAvailable == false);

    return TextField(
      controller: idController,
      onChanged: _onIdChanged,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: '아이디',
        helperText: _idHelperText,
        helperStyle: TextStyle(
          color: duplicated ? Colors.red : Colors.white54,
          fontSize: 12,
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: const Color(0xFF0A0E21),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color:
                duplicated
                    ? Colors.red.withOpacity(0.5)
                    : const Color(0xFF6C63FF).withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color:
                duplicated
                    ? Colors.red.withOpacity(0.5)
                    : const Color(0xFF6C63FF).withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: duplicated ? Colors.red : const Color(0xFF6C63FF),
            width: 2,
          ),
        ),
        prefixIcon: const Icon(Icons.person, color: Color(0xFF6C63FF)),
        suffixIcon:
            duplicated
                ? Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.red, size: 16),
                )
                : null,
      ),
    );
  }

  String _getGenderText() {
    switch (selectedGender) {
      case 1:
        return '남자';
      case 2:
        return '여자';
      default:
        return '성별을 선택하고 싶지 않음';
    }
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33), // (선택) 다크 테마 맞춤
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in const [
                {'v': 1, 't': '남자'},
                {'v': 2, 't': '여자'},
                {'v': 0, 't': '선택 안함'},
              ])
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF6C63FF),
                  ),
                  title: Text(
                    e['t'] as String,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      selectedGender = e['v'] as int;
                      genderController.text = _getGenderText(); // ⬅️ 표시값 갱신
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
