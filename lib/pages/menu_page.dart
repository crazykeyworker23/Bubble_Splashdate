import 'package:flutter/material.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(title: "Menú"),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: [
              _MenuItem(
                title: "Bubble Tea Clásico",
                image: "assets/bebidas.png",
                desc: "Sabor original con tapioca perla.",
              ),
              _MenuItem(
                title: "Taro Latte",
                image: "assets/bebidas.png",
                desc: "Dulce, suave y colorido.",
              ),
              _MenuItem(
                title: "Matcha Deluxe",
                image: "assets/bebidas.png",
                desc: "Hecho con matcha japonés premium.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final String desc;
  final String image;

  const _MenuItem({
    required this.title,
    required this.image,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
            child: Image.asset(image, width: 100, height: 100, fit: BoxFit.cover),
          ),
          Expanded(
            child: ListTile(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(desc),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D6EFD),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
