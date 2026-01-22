import 'package:flutter/material.dart';
import '../views/login/login_page.dart';
import '../views/home/inicio_page.dart';
import '../views/product_detail/product_detail_page.dart';
import '../views/cart/cart_page.dart';
import '../views/profile/profile_page.dart';

class AppRoutes {
  static const String welcome = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String productDetail = '/product-detail';
  static const String cart = '/cart';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> routes = {
    // welcome: (context) => const WelcomePage(),
    login: (context) => const LoginPage(),
    home: (context) => const InicioPage(),
    productDetail: (context) => const ProductDetailPage(),
    cart: (context) => const CartPage(),
    profile: (context) => const ProfilePage(),
  };
}
