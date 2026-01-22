import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'detail_movimiento_page.dart';
import 'movimiento.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  String? _lastCode;
  bool _detected = false;
  String? montoEscaneado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Cámara activa
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final code = barcodes.first.rawValue;
              if (code != null && code != _lastCode) {
                setState(() {
                  _lastCode = code;
                  montoEscaneado = code;
                  _detected = true;
                });
              }
            },
          ),

          /// Capa semitransparente con hueco central
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.black45,
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Contenido superior (botón cerrar, ícono, texto)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.qr_code_scanner,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Escanea un QR con el monto a pagar",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          /// Marco de escaneo
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _detected ? Colors.green : Colors.white,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          /// Mostrar el monto y botón pagar cuando se detecte
          if (_detected && montoEscaneado != null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Monto escaneado: S/ $montoEscaneado",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final monto = double.tryParse(montoEscaneado ?? '0') ?? 0.0;

                        // Registrar movimiento de gasto en el historial
                        final prefs = await SharedPreferences.getInstance();
                        final user = FirebaseAuth.instance.currentUser;
                        final String? keyMovs = user != null ? 'movimientos_${user.uid}' : null;
                        final List<String> data = keyMovs != null
                          ? (prefs.getStringList(keyMovs) ?? [])
                          : <String>[];
                        final now = DateTime.now();
                        final fecha = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                        final codigo = 'QR${now.millisecondsSinceEpoch}';

                        // Obtener nombre del cliente (similar a PagosPage)
                        String nombreCliente = 'Cliente';
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            nombreCliente = (user.displayName != null &&
                                    user.displayName!.trim().isNotEmpty)
                                ? user.displayName!
                                : (user.email ?? 'Cliente');
                          }
                        } catch (_) {}

                        final movimientoJson = {
                          'tipo': 'gasto',
                          'monto': monto,
                          'metodo': 'Pago QR',
                          'referencia': codigo,
                          'fecha': fecha,
                          'codigo': codigo,
                          'cliente': nombreCliente,
                        };

                        data.insert(0, jsonEncode(movimientoJson));
                        if (keyMovs != null) {
                          await prefs.setStringList(keyMovs, data);
                        }

                        // Descontar el monto del saldo por usuario
                        if (user != null) {
                          final String keySaldo = 'saldo_${user.uid}';
                          final saldoActual = prefs.getDouble(keySaldo) ?? 0.0;
                          final nuevoSaldo = (saldoActual - monto).clamp(0.0, double.infinity);
                          await prefs.setDouble(keySaldo, nuevoSaldo);
                        }

                        // Mostrar comprobante usando el modelo simple + datos crudos
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) {
                              final movimiento = Movimiento(
                                titulo: 'CONSUMO',
                                monto: monto,
                                tipo: 'gasto',
                                fecha: fecha,
                              );
                              return DetalleMovimientoPage(
                                movimiento: movimiento,
                                datosAdicionales: movimientoJson,
                              );
                            },
                          ),
                        ).then((_) {
                          // Al cerrar el comprobante, volver automáticamente a Pagos
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        });
                      },
                      child: const Text("Pagar"),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
