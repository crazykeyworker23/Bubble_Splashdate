import 'package:flutter/material.dart';
import '../models/product.dart';
import '../constants/styles.dart';
import '../constants/colors.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Card(
          color: kSecondaryColor.withOpacity(0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: Image.asset(product.image, fit: BoxFit.contain)),
                const SizedBox(height: 8),
                Text(product.name, style: kProductNameStyle, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('\$${product.price.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
