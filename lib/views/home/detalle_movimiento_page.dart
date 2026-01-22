import 'package:flutter/material.dart';

class DetalleMovimientoPage extends StatelessWidget {
  const DetalleMovimientoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.98),
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 27, 111, 129),
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "BUBBLE TEA",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // 👇 sin bottomNavigationBar, para que se vea el del Home
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 5),
            const Text(
              "Comprobante de Pedido",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Pedido #: 00012345",
                    style: TextStyle(color: Colors.black87, fontSize: 14)),
                Text("Fecha: 30/09/2025   Hora: 3:40 pm",
                    style: TextStyle(color: Colors.black87, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0D6EFD), width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              child: const Text(
                "Para Llevar",
                style: TextStyle(
                  color: Color(0xFF0D6EFD),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 25),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "1 Bubble tea Mango",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "s/ 10.00",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        "vaso normal – Extra hielo – Poca Azúcar",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),

            const Divider(thickness: 1, color: Colors.black26),
            const SizedBox(height: 10),

            Column(
              children: const [
                _DetalleTotalItem(label: "SubTotal", value: "S/ 30.00", bold: false),
                _DetalleTotalItem(label: "IGV (18%)", value: "S/ 4.86", bold: false),
                _DetalleTotalItem(
                    label: "TOTAL", value: "S/ 34.86", bold: true, color: Color(0xFF0D6EFD)),
              ],
            ),
            const SizedBox(height: 35),

            const Text(
              "¡Gracias por tu compra!",
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _DetalleTotalItem extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _DetalleTotalItem({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  color: color ?? Colors.black87,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
