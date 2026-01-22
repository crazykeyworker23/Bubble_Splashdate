import 'package:flutter/material.dart';

class BeneficiosPage extends StatelessWidget {
  const BeneficiosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(title: "Beneficios"),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(15),
            children: const [
              _BenefitCard(
                title: "10% de descuento en tu primera compra",
                desc: "Disponible hasta el 31 de diciembre.",
              ),
              _BenefitCard(
                title: "Puntos FINT Rewards",
                desc: "Acumula puntos y canjéalos por bebidas gratis.",
              ),
              _BenefitCard(
                title: "Invita y gana",
                desc: "Gana S/5 por cada amigo que se registre.",
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final String title;
  final String desc;
  const _BenefitCard({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD))),
          const SizedBox(height: 5),
          Text(desc, style: const TextStyle(color: Colors.black87)),
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
