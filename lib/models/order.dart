import 'product.dart';
import 'topping.dart';

class Order {
  final Product product;
  final List<Topping> toppings;
  int quantity;

  Order({required this.product, this.toppings = const [], this.quantity = 1});

  double get total =>
      (product.price + toppings.fold(0.0, (p, e) => p + e.price)) * quantity;
}
