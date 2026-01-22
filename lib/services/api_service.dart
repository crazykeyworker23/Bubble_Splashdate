import '../models/product.dart';

class ApiService {
  static List<Product> getProducts() {
    return [
      Product(
        id: 1,
        name: 'Bubble Tea Mango',
        description: 'Bubble Tea sabor mango',
        price: 5.0,
        image: 'assets/mango.png',
      ),
      Product(
        id: 2,
        name: 'Bubble Tea Fresa',
        description: 'Bubble Tea sabor fresa',
        price: 5.5,
        image: 'assets/strawberry.png',
      ),
      Product(
        id: 3,
        name: 'Smoothie Banana',
        description: 'Smoothie de banana',
        price: 6.0,
        image: 'assets/banana.png',
      ),
    ];
  }
}
