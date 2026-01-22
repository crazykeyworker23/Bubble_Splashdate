import 'package:flutter/material.dart';
import '../constants/colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const AppHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kPrimaryColor,
      title: Text(title),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
