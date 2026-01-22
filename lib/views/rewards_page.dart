import 'package:flutter/material.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puntos y Beneficios')),
      body: const Center(
        child: Text('Aquí irán los puntos y beneficios.'),
      ),
    );
  }
}
