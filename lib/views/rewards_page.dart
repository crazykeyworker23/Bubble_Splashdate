import 'package:flutter/material.dart';
import 'package:bubblesplash/widgets/cart_fab_button.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Puntos y Beneficios')),
      body: const Center(
        child: Text('Aquí irán los puntos y beneficios.'),
      ),
      floatingActionButton: CartFabButton(
        count: 0, // TODO: Reemplazar con la cantidad real si está disponible
        onPressed: () {
          Navigator.pushNamed(context, '/cart');
        },
        draggable: false,
        heroTag: 'rewards_cart_fab',
      ),
    );
  }
}
