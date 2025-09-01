import 'package:flutter/material.dart';

class TopNav extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool? showBackButton; // null 이면 Navigator.canPop 으로 자동 판단
  final VoidCallback? onBack; // 커스텀 뒤로가기 동작 지정 가능
  final List<Widget>? actions; // 우측 액션들
  final Color backgroundColor;
  final Color titleColor;
  final double elevation;
  final Gradient? gradient; // 그라디언트 배경을 쓰고 싶을 때

  const TopNav({
    super.key,
    required this.title,
    this.showBackButton,
    this.onBack,
    this.actions,
    this.backgroundColor = const Color(0xFF1D1E33),
    this.titleColor = Colors.white,
    this.elevation = 0,
    this.gradient,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final shouldShowBack = showBackButton ?? canPop;

    return AppBar(
      centerTitle: true,
      elevation: elevation,
      backgroundColor: gradient == null ? backgroundColor : Colors.transparent,
      iconTheme: IconThemeData(color: titleColor),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
      ),
      leading:
          shouldShowBack
              ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack ?? () => Navigator.maybePop(context),
              )
              : null,
      actions: actions,
      flexibleSpace:
          gradient != null
              ? Container(decoration: BoxDecoration(gradient: gradient))
              : null,
    );
  }
}
