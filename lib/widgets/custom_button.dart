import 'package:flutter/material.dart';
import '../constants/colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // ✅ ahora acepta null

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return ElevatedButton(
      onPressed: onPressed, // ✅ null = deshabilitado
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 27, 111, 129),
        disabledBackgroundColor:
            const Color.fromARGB(255, 27, 111, 129),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.6, // efecto deshabilitado
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
