import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuardandoDatosPage extends StatelessWidget {
  const GuardandoDatosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1B6F81)),
            const SizedBox(height: 20),
            Text(
              "Guardando datos...",
              style: GoogleFonts.paytoneOne(
                fontSize: 20,
                color: const Color(0xFF1B6F81),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
