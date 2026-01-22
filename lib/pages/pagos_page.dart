import 'package:flutter/material.dart';

class PagosPage extends StatelessWidget {
  const PagosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(title: "Pagos"),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(15),
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: const [
              _PagoCard(icon: Icons.qr_code, label: "Pagar servicios"),
              _PagoCard(icon: Icons.send, label: "Enviar dinero"),
              _PagoCard(icon: Icons.history, label: "Historial de pagos"),
              _PagoCard(icon: Icons.account_balance, label: "Cuentas y bancos"),
            ],
          ),
        ),
      ],
    );
  }
}

class _PagoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PagoCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF0D6EFD), size: 40),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center),
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
