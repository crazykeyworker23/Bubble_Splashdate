
import 'package:flutter/material.dart';

import 'movimiento.dart';

class DetalleMovimientoPage extends StatelessWidget {
  final Movimiento movimiento;
  final Map<String, dynamic>? datosAdicionales;

  const DetalleMovimientoPage({
    super.key,
    required this.movimiento,
    this.datosAdicionales,
  });

  @override
  Widget build(BuildContext context) {
    final raw = datosAdicionales ?? <String, dynamic>{};
    final codigo = (raw['codigo'] ?? '').toString();
    final metodo = (raw['metodo'] ?? '').toString();
    final referencia = (raw['referencia'] ?? '').toString();
    final fechaCruda = (raw['fecha'] ?? movimiento.fecha).toString();
    final orderId = (raw['orderId'] ?? '').toString();
    final dineOption = (raw['dineOption'] ?? '').toString();
    final cliente = (raw['cliente'] ?? 'Cliente').toString();
    final List<dynamic> rawItems =
        raw['items'] is List ? (raw['items'] as List) : const [];

    String fechaSolo = fechaCruda;
    String horaSolo = '';
    if (fechaCruda.contains(' ')) {
      final partes = fechaCruda.split(' ');
      if (partes.isNotEmpty) {
        fechaSolo = partes[0];
      }
      if (partes.length > 1) {
        horaSolo = partes[1];
      }
    }

    final esRecarga = movimiento.tipo == 'recarga';
    final esGasto = movimiento.tipo == 'gasto';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          esRecarga ? 'Comprobante de Recarga' : 'Comprobante de Consumo',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 27, 111, 129),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (esRecarga) ...[
              // --- CABECERA TIPO BOLETA (igual que en Pagos) ---
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.receipt_long, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      "Comprobante de recarga",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Datos de la empresa y cliente (mismos textos que en Pagos)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE3F2FD),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BubbleSplash SAC',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Calle. Sargento Lores, Iquitos, Loreto',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Contacto: +51 999 999 999',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 12),
              const Icon(Icons.check_circle,
                  size: 48, color: Colors.green),
              const SizedBox(height: 8),
              const Text(
                "¡Recarga exitosa!",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Tu recarga se ha procesado correctamente.",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.black12),

              // --- MONTO RECARGADO ---
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "Monto recargado",
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "S/ ${movimiento.monto.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: Colors.black12),

              // --- DETALLES ---
              const SizedBox(height: 10),
              const Text(
                "Detalles del comprobante",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.tag, size: 20, color: Color(0xFFE80A5D)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "ID transacción: ${codigo.isNotEmpty ? codigo : '-'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.credit_card,
                      size: 20, color: Color(0xFFE80A5D)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Método de pago: ${metodo.isNotEmpty ? metodo : 'Billetera Digital'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 20, color: Color(0xFFE80A5D)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Fecha: $fechaSolo",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 20, color: Color(0xFFE80A5D)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person,
                      size: 20, color: Color(0xFFE80A5D)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Cliente: $cliente",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // --- PUNTOS GANADOS ---
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        "Puntos ganados\n¡Sigue acumulando!",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black45),
                      ),
                      child: const Text(
                        "+ 5",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (esGasto) ...[
              if (rawItems.isNotEmpty) ...[
                // 🔹 Boleta de COMPRA igual a ReceiptPage (resumen)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B6F81),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_cafe_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BUBBLE TEA BUBBLESPLASH',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Comprobante de Pedido',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Datos de la empresa
                Row(
                  children: const [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Color(0xFF757575),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Calle. Sargento Lores, Iquitos, Loreto',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: Color(0xFF757575),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '+51 999 999 999',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 20),

                // Datos del cliente
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: Color(0xFF1B6F81),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cliente: $cliente',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Información general
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pedido #: ${orderId.isNotEmpty ? orderId : '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Fecha: $fechaSolo',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 15),

                // Tipo de consumo
                if (dineOption.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF0D6EFD)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        dineOption,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D6EFD),
                        ),
                      ),
                    ),
                  ),

                if (dineOption.isNotEmpty) const SizedBox(height: 20),

                // Lista de productos
                ...rawItems.map((item) {
                  final map = item as Map<String, dynamic>;
                  final String name = map['name'] ?? 'Producto';
                  final int quantity = (map['quantity'] ?? 1) as int;
                  final double price = (map['price'] is num)
                      ? (map['price'] as num).toDouble()
                      : 0.0;
                  final String size = map['size'] ?? '';
                  final String ice = map['ice'] ?? '';
                  final List<dynamic> toppingsRaw =
                      (map['toppings'] is List) ? map['toppings'] : [];
                  final List<String> toppings =
                      toppingsRaw.map((e) => e.toString()).toList();
                  final List<String> details = [
                    if (size.isNotEmpty) size,
                    if (ice.isNotEmpty) ice,
                    ...toppings,
                  ];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$quantity x $name',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'S/. ${(price * quantity).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details.join(', '),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),

                const Divider(height: 25),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6EFD),
                      ),
                    ),
                    Text(
                      'S/. ${movimiento.monto.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D6EFD),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Código de compra
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Text(
                        'Código de compra',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        codigo.isNotEmpty ? codigo : '-',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Color(0xFF42A5F5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                if (metodo == 'Pago QR') ...[
                  // Comprobante especial para pagos QR
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.qr_code_2, color: Colors.black87),
                        SizedBox(width: 8),
                        Text(
                          "Comprobante de pago QR",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.check_circle,
                      size: 48, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text(
                    "¡Pago QR exitoso!",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Tu pago mediante código QR se ha procesado correctamente.",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Colors.black12),

                  // Monto
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "Monto pagado",
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      "S/ ${movimiento.monto.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 10),

                  // Detalles
                  Row(
                    children: [
                      const Icon(Icons.tag,
                          size: 20, color: Color(0xFFE80A5D)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Código de operación: ${codigo.isNotEmpty ? codigo : '-'}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 20, color: Color(0xFFE80A5D)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Fecha: $fechaSolo",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 20, color: Color(0xFFE80A5D)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Hora: ${horaSolo.isNotEmpty ? horaSolo : '--:--'}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person,
                          size: 20, color: Color(0xFFE80A5D)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Cliente: $cliente",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // Fallback para consumos sin detalle de productos
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Monto Consumido:',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                        Text('S/ ${movimiento.monto.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.blue)),
                        const SizedBox(height: 10),
                        if (metodo.isNotEmpty) Text('Método: $metodo'),
                        if (referencia.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Referencia: $referencia'),
                        ],
                        if (metodo.isEmpty && referencia.isEmpty)
                          Text('Concepto: ${movimiento.titulo}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('¡Gracias por tu consumo!',
                      textAlign: TextAlign.center),
                ],
              ],
            ] else ...[
              // Otro tipo de movimiento
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monto:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('S/ ${movimiento.monto.toStringAsFixed(2)}'),
                    const SizedBox(height: 10),
                    Text('Concepto: ${movimiento.titulo}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('¡Gracias!', textAlign: TextAlign.center),
            ],

            const SizedBox(height: 30),

            // ✅ Botón Cerrar
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // Solo cerramos esta pantalla; ScannerPage se encarga de volver a Pagos
                Navigator.pop(context);
              },
              child: const Text(
                'Cerrar',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

