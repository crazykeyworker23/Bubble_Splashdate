import 'package:flutter/material.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle Producto')),
      body: Center(
        child: Text('Producto recomendado:\n\n' + (product?.toString() ?? 'Sin datos')),
      ),
    );
  }
}
