import 'package:flutter/material.dart';

class CommonHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CommonHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 2,
      foregroundColor: Colors.black,
      toolbarHeight: 70, // 🔹 Controla que todos tengan la misma altura
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
