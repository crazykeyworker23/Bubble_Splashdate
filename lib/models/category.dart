import 'product.dart';

class Category {
  final int id;
  final String name;
  final String description;
  final int order;
  final String status;
  final List<Product> products;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    required this.status,
    required this.products,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final idRaw = json['cat_int_id'];
    final orderRaw = json['cat_int_order'];

    final productsRaw = json['productos'];
    final List<dynamic> productsList = productsRaw is List
        ? productsRaw
        : const [];

    final products = productsList
        .whereType<Map<String, dynamic>>()
        .where((item) {
          final status = (item['txt_status'] ?? '').toString().toUpperCase();
          return status.isEmpty || status == 'ACTIVO';
        })
        .map((item) {
          final int id = (item['pro_int_id'] ?? 0) is int
              ? item['pro_int_id'] as int
              : int.tryParse(item['pro_int_id'].toString()) ?? 0;
          final String name = (item['pro_txt_name'] ?? '').toString();
          final String description = (item['pro_txt_description'] ?? '')
              .toString();

          final String priceStr = (item['pro_de_baseprice'] ?? '0').toString();
          final double price = double.tryParse(priceStr) ?? 0.0;

          // Algunos responses traen URL en `pro_txt_urlimagepath` y otros en `pro_txt_imageurl`.
          final String image =
              ((item['pro_txt_urlimagepath'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty)
              ? (item['pro_txt_urlimagepath'] ?? '').toString()
              : (item['pro_txt_imageurl'] ?? '').toString();

          return Product(
            id: id,
            name: name,
            description: description,
            price: price,
            image: image,
          );
        })
        .toList();

    return Category(
      id: idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '') ?? 0,
      name: (json['cat_txt_name'] ?? '').toString(),
      description: (json['cat_txt_description'] ?? '').toString(),
      order: orderRaw is int
          ? orderRaw
          : int.tryParse(orderRaw?.toString() ?? '') ?? 0,
      status: (json['txt_status'] ?? '').toString(),
      products: products,
    );
  }
}
