import 'package:flutter/material.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final category = ModalRoute.of(context)?.settings.arguments;
    return Scaffold(
      appBar: AppBar(title: const Text('Categoría')),
      body: Center(
        child: Text('Categoría seleccionada: ' + (category?.toString() ?? 'Sin datos')),
      ),
    );
  }
}
