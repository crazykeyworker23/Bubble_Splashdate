import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/topping.dart';

class CartController extends ChangeNotifier {
  final List<Order> _items = [];

  List<Order> get items => List.unmodifiable(_items);

  void addProduct(Product product, {List<Topping> toppings = const []}) {
    // si ya existe producto + toppings igual, aumentar cantidad
    final index = _items.indexWhere((o) => o.product.id == product.id && _sameToppings(o.toppings, toppings));
    if (index >= 0) {
      _items[index].quantity += 1;
    } else {
      _items.add(Order(product: product, toppings: toppings, quantity: 1));
    }
    notifyListeners();
  }

  bool _sameToppings(List<Topping> a, List<Topping> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
    }
    return true;
  }

  void removeAt(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  double get total => _items.fold(0.0, (p, e) => p + e.total);
}
