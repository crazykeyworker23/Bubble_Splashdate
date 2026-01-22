import 'package:flutter/material.dart';

class PromoDetailPage extends StatelessWidget {
  const PromoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final banner = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle Promoción')),
      body: Center(
        child: Text('Detalle de la promoción:\n\n' + (banner?.toString() ?? 'Sin datos')),
      ),
    );
  }
}
