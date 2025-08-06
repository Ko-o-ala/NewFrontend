import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopNav extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  final VoidCallback onLogout;
  final VoidCallback onLogin;

  const TopNav({
    super.key,
    required this.isLoggedIn,
    required this.onLogout,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('당신의 하루', style: TextStyle(color: Colors.white)),
      centerTitle: true,
      backgroundColor: const Color(0xFF8183D9),
      actions: [
        TextButton(
          onPressed: isLoggedIn ? onLogout : onLogin,
          child: Text(
            isLoggedIn ? '로그아웃' : '로그인',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
