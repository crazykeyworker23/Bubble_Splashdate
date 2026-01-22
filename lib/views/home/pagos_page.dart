import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/rendering.dart';
import 'package:ionicons/ionicons.dart';

import 'detail_movimiento_page.dart';
import 'scanner_page.dart';
import 'movimiento.dart';
import 'movimientos_page.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bubblesplash/services/auth_service.dart';

class PagosPage extends StatefulWidget {
  const PagosPage({super.key});

  @override
  State<PagosPage> createState() => _PagosPageState();
}

class _PagosPageState extends State<PagosPage> {
  // Clave para capturar el comprobante como imagen
  final GlobalKey _comprobanteKey = GlobalKey();

  bool _mostrarSaldo = true;
  double saldoActual = 0.0;

  // Datos de la empresa / cliente para el comprobante
  final String _razonSocial = "BubbleSplash SAC";
  final String _direccionEmpresa = "Calle. Sargento Lores, Iquitos, Loreto";
  final String _telefonoContacto = "+51 999 999 999";
  String? _nombreCliente;

  @override
  void initState() {
    super.initState();
    _cargarSaldo();
    _cargarNombreCliente();
  }

  Future<void> _cargarSaldo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        setState(() {
          saldoActual = 0.0;
        });
        debugPrint('No hay access_token para consultar el saldo en la API');
        return;
      }

      final token = rawToken.trim();
      final uri = Uri.parse(
          'https://services.fintbot.pe/api/bubblesplash/wallet/me/');

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Si el token expiró (401), intentamos refrescar y reintentar una vez
      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (response.statusCode == 401) {
        debugPrint('Sesión expirada al consultar saldo wallet/me');
        setState(() {
          saldoActual = 0.0;
        });
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String balanceStr =
            (data['wal_de_balance'] ?? '0').toString();
        final double balance = double.tryParse(balanceStr) ?? 0.0;

        setState(() {
          saldoActual = balance;
        });
      } else {
        debugPrint(
            'Error al cargar saldo desde API wallet/me: ${response.statusCode} ${response.body}');
        setState(() {
          saldoActual = 0.0;
        });
      }
    } catch (e) {
      debugPrint('Excepción al cargar saldo desde API wallet/me: $e');
      setState(() {
        saldoActual = 0.0;
      });
    }
  }

  Future<void> _cargarNombreCliente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _nombreCliente =
            user?.displayName ?? user?.email ?? 'Cliente';
      });
    } catch (_) {
      // En caso de no tener Firebase inicializado o sin sesión
      setState(() {
        _nombreCliente = 'Cliente';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Stack(
        children: [
          // Header azul grande y fijo
          SafeArea(
            child: Container(
              height: 250,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 27, 111, 129),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Mi Wallet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Paga y acumula puntos.",
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  // Tarjeta de saldo + botón Recargar separado a la derecha
                  Row(
                    children: [
                      // Contenedor de saldo
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 76, 155, 10),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Saldo disponible",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: _mostrarSaldo
                                          ? Text(
                                              "S/ ${saldoActual.toStringAsFixed(2)}",
                                              key: const ValueKey('saldo'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : const Text(
                                              "••••••••",
                                              key: ValueKey('oculto'),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _mostrarSaldo
                                      ? Ionicons.eye_outline
                                      : Ionicons.eye_off_outline,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _mostrarSaldo = !_mostrarSaldo;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón Recargar separado al costado derecho
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _mostrarPopupRecarga,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 255, 255, 255),
                            foregroundColor:
                                const Color.fromARGB(255, 27, 111, 129),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 0),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Recargar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Contenido desplazable debajo del header
          Padding(
            padding: const EdgeInsets.only(top: 300),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 90, // espacio para footer
              ),
              child: Column(
                children: [
                  // Botón Escanear
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScannerPage(),
                              ),
                            );
                          },
                          icon: const Icon(Ionicons.camera_outline,
                              color: Colors.black87),
                          label: const Text(
                            "Escanear",
                            style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            shadowColor: Colors.black.withOpacity(0.1),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Movimientos",
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history),
                      label: const Text(
                        'Ver historial de movimientos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MovimientosPage(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Vista rápida de los últimos movimientos guardados
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _cargarMovimientosPreview(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final data = snapshot.data ?? [];
                      if (data.isEmpty) {
                        return const Text(
                          'Aún no tienes movimientos registrados.',
                          style: TextStyle(color: Colors.black54),
                        );
                      }

                      final ultimos = data.take(3).toList();
                      return Column(
                        children: ultimos
                            .map((m) => MovimientoItem(movimientoRaw: m))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } 

  // --- POPUP PARA MOSTRAR LA RECARGA DE SALDO ---
  void _mostrarPopupRecarga() {
    double? montoSeleccionado;
    String tipoTransferencia = "Billetera Digital";
    String metodoOtraBilletera = "Yape";
    final TextEditingController montoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setModalState) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- TÍTULO ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Recargar Saldo",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 28),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- SALDO ACTUAL ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Saldo actual",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            "S/ ${saldoActual.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Divider(color: Colors.black26, thickness: 1),
                      const SizedBox(height: 15),

                      // --- MONTOS RÁPIDOS ---
                      const Text(
                        "Montos rápidos",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [50, 100, 200, 500].map((monto) {
                          final isSelected = montoSeleccionado == monto;
                          return ChoiceChip(
                            label: Text("S/ $monto"),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0D6EFD),
                            onSelected: (selected) {
                              setModalState(() {
                                if (isSelected) {
                                  montoSeleccionado = null;
                                } else {
                                  montoSeleccionado = monto.toDouble();
                                  montoController.clear();
                                }
                              });
                            },
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 15),

                      // --- MONTO PERSONALIZADO ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Monto personalizado",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: montoController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              hintText: "Ingrese monto",
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                montoSeleccionado = double.tryParse(value);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // --- TIPO DE TRANSFERENCIA ---
                      const Text(
                        "Tipo de transferencia",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          "Billetera Digital",
                          "Transferencia Bancaria",
                          "Otra billetera",
                        ].map((tipo) {
                          final isSelected = tipoTransferencia == tipo;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                tipoTransferencia = tipo;
                              });
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE3F2FD)
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF0D6EFD)
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: tipo,
                                    groupValue: tipoTransferencia,
                                    onChanged: (value) {
                                      setModalState(() {
                                        tipoTransferencia = value!;
                                      });
                                    },
                                    activeColor: const Color(0xFF0D6EFD),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(tipo),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 15),

                      // --- CONTENIDO ADICIONAL SEGÚN TIPO ---
                      if (tipoTransferencia == "Billetera Digital") ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF0D6EFD),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF0D6EFD),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Recargar con mi billetera digital vinculada. Sigue los pasos de tu billetera para completar el pago.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (tipoTransferencia == "Transferencia Bancaria") ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Transfiere al siguiente número de cuenta:",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Banco: BCP",
                                style: TextStyle(fontSize: 13),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Cuenta: 123-45678901-0-12",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Titular: Bubble Tea SAC",
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ] else if (tipoTransferencia == "Otra billetera") ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Elige tu billetera:",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text("Yape"),
                                    selected: metodoOtraBilletera == "Yape",
                                    selectedColor: const Color(0xFF0D6EFD)
                                        .withOpacity(0.9),
                                    onSelected: (_) {
                                      setModalState(() {
                                        metodoOtraBilletera = "Yape";
                                      });
                                    },
                                    labelStyle: TextStyle(
                                      color: metodoOtraBilletera == "Yape"
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text("Plin"),
                                    selected: metodoOtraBilletera == "Plin",
                                    selectedColor: const Color(0xFF0D6EFD)
                                        .withOpacity(0.9),
                                    onSelected: (_) {
                                      setModalState(() {
                                        metodoOtraBilletera = "Plin";
                                      });
                                    },
                                    labelStyle: TextStyle(
                                      color: metodoOtraBilletera == "Plin"
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: Colors.grey[200],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Escanea el QR o usa el número asociado a tu Yape o Plin para completar la recarga.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // --- BOTÓN CONFIRMAR ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (montoSeleccionado != null &&
                                montoSeleccionado! > 0) {
                              Navigator.of(dialogContext).pop();
                              await Future.delayed(
                                  const Duration(milliseconds: 300));

                              if (mounted) {
                                await _realizarRecargaBackend(
                                  montoSeleccionado!,
                                  tipoTransferencia,
                                  metodoOtraBilletera,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6EFD),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Recargar",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Registra la recarga en la lista persistente de movimientos
  Future<void> _guardarMovimientoRecarga(
    double montoRecargado,
    String tipoTransferencia,
    String fechaHora,
    String codigo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final String? keyMovs = user != null ? 'movimientos_${user.uid}' : null;
    final List<String> data = keyMovs != null
        ? (prefs.getStringList(keyMovs) ?? [])
        : <String>[];

    final movimiento = {
      'tipo': 'recarga',
      'monto': montoRecargado,
      'metodo': tipoTransferencia,
      'referencia': codigo,
      'fecha': fechaHora,
      'codigo': codigo,
      'cliente': _nombreCliente ?? 'Cliente',
    };

    data.insert(0, jsonEncode(movimiento));
    if (keyMovs != null) {
      await prefs.setStringList(keyMovs, data);
    }
  }

  // Carga todos los movimientos guardados para la vista previa de Pagos
  Future<List<Map<String, dynamic>>> _cargarMovimientosPreview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        debugPrint('No hay access_token para consultar movimientos (preview)');
        return [];
      }

      final token = rawToken.trim();
      final uri = Uri.parse(
          'https://services.fintbot.pe/api/bubblesplash/wallet/movimientos/');

      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Si el token expiró (401), intentamos refrescar y reintentar una vez
      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
          );
        }
      }

      if (response.statusCode == 401) {
        debugPrint('Sesión expirada al consultar movimientos (preview)');
        return [];
      }

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body) as List<dynamic>;

        return data.whereType<Map<String, dynamic>>().map((item) {
          final String rawType =
              (item['wmv_txt_type'] ?? '').toString();
          final String tipo =
              rawType.toUpperCase() == 'RECARGA' ? 'recarga' : 'movimiento';

          final String amountStr =
              (item['wmv_de_amount'] ?? '0').toString();
          final double monto = double.tryParse(amountStr) ?? 0.0;

          final String descripcion =
              (item['wmv_txt_description'] ?? '').toString();
          final String fechaIso =
              (item['timestamp_datecreate'] ?? '').toString();

          String fecha = fechaIso;
          if (fechaIso.contains('T')) {
            try {
              fecha = fechaIso.replaceFirst('T', ' ').substring(0, 16);
            } catch (_) {
              fecha = fechaIso;
            }
          }

          final String id = (item['wmv_int_id'] ?? '').toString();

          return <String, dynamic>{
            'tipo': tipo,
            'monto': monto,
            'metodo': descripcion,
            'referencia': id,
            'fecha': fecha,
            'codigo': 'MOV$id',
            'cliente': _nombreCliente ?? 'Cliente',
          };
        }).toList();
      } else {
        debugPrint(
            'Error al cargar movimientos (preview): ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Excepción al cargar movimientos (preview): $e');
      return [];
    }
  }

  Future<void> _realizarRecargaBackend(
    double montoSeleccionado,
    String tipoTransferencia,
    String metodoOtraBilletera,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'No hay access_token. Inicia sesión nuevamente para recargar.'),
            backgroundColor: Colors.red.shade400,
          ),
        );
        return;
      }

      final token = rawToken.trim();

      String transferCode;
      if (tipoTransferencia == 'Billetera Digital') {
        transferCode = 'BILLETERA_DIGITAL';
      } else if (tipoTransferencia == 'Transferencia Bancaria') {
        transferCode = 'TRANSFERENCIA_BANCARIA';
      } else {
        if (metodoOtraBilletera == 'Yape') {
          transferCode = 'YAPE';
        } else if (metodoOtraBilletera == 'Plin') {
          transferCode = 'PLIN';
        } else {
          transferCode = 'OTRA_BILLETERA';
        }
      }

        final uri = Uri.parse(
          'https://services.fintbot.pe/api/bubblesplash/wallet/recarga/');

      final body = jsonEncode({
        'wmv_de_amount': montoSeleccionado.toStringAsFixed(2),
        'wmv_txt_transfer': transferCode,
      });

      http.Response response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      // Si el token expiró (401), intentamos refrescar y reintentar una vez
      if (response.statusCode == 401 && await AuthService.refreshToken()) {
        final newToken = prefs.getString('access_token')?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          response = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $newToken',
            },
            body: body,
          );
        }
      }

      if (response.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Tu sesión ha expirado. Inicia sesión nuevamente para recargar.'),
            backgroundColor: Colors.red.shade400,
          ),
        );
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final wallet = data['wallet'] as Map<String, dynamic>?;
        final movement = data['movement'] as Map<String, dynamic>?;

        double nuevoSaldo = saldoActual;
        if (wallet != null) {
          final balanceStr =
              (wallet['wal_de_balance'] ?? '0').toString();
          nuevoSaldo = double.tryParse(balanceStr) ?? nuevoSaldo;
        }

        String metodoPagoUi;
        if (tipoTransferencia == 'Otra billetera') {
          metodoPagoUi = 'Otra billetera ($metodoOtraBilletera)';
        } else {
          metodoPagoUi = tipoTransferencia;
        }

        String fecha = '';
        String hora = '';
        String idTransaccion = '';
        double montoRecibido = montoSeleccionado;

        if (movement != null) {
          final amountStr =
              (movement['wmv_de_amount'] ?? '0').toString();
          montoRecibido = double.tryParse(amountStr) ?? montoRecibido;

          final String id = (movement['wmv_int_id'] ?? '').toString();
          idTransaccion = 'MOV$id';

          final String fechaIso =
              (movement['timestamp_datecreate'] ?? '').toString();
          if (fechaIso.isNotEmpty) {
            try {
              final dt = DateTime.parse(fechaIso);
              fecha =
                  '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
              hora =
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              fecha = fechaIso;
              hora = '';
            }
          }
        }

        if (mounted) {
          setState(() {
            saldoActual = nuevoSaldo;
          });
        }

        if (mounted) {
          await _mostrarPopupRecargaExitosa(
            context,
            montoRecibido,
            metodoPagoUi,
            fecha,
            hora,
            idTransaccion.isEmpty
                ? 'REC${DateTime.now().millisecondsSinceEpoch}'
                : idTransaccion,
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error al realizar recarga: ${response.statusCode}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al realizar recarga: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Future<void> _mostrarPopupRecargaExitosa(
    BuildContext context,
    double montoRecargado,
    String tipoTransferencia,
    String fecha,
    String hora,
    String idTransaccion,
  ) async {
    const int puntosGanados = 5;

    // Actualiza los puntos acumulados por recarga por usuario (local)
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String keyPuntos = 'puntos_${user.uid}';
      final int puntosActuales = prefs.getInt(keyPuntos) ?? 0;
      await prefs.setInt(keyPuntos, puntosActuales + puntosGanados);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // BOLETA QUE SE CAPTURA COMO IMAGEN
                RepaintBoundary(
                  key: _comprobanteKey,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Franja celeste superior tipo boleta
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
                              Icon(Icons.receipt_long,
                                  color: Colors.black87),
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
                        // Datos de la empresa y cliente debajo del título
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE3F2FD),
                                  border: Border.all(
                                    color: Colors.black12,
                                  ),
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
                                  children: [
                                    Text(
                                      _razonSocial,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _direccionEmpresa,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Contacto: $_telefonoContacto",
                                      style: const TextStyle(
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
                            "S/ ${montoRecargado.toStringAsFixed(2)}",
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
                        _buildDetailRow(
                            Icons.tag, "ID transacción", idTransaccion),
                        _buildDetailRow(
                            Icons.credit_card,
                            "Método de pago",
                            tipoTransferencia),
                        _buildDetailRow(
                            Icons.calendar_today, "Fecha", fecha),
                        _buildDetailRow(Icons.access_time, "Hora", hora),
                        _buildDetailRow(
                          Icons.person,
                          "Cliente",
                          _nombreCliente ?? 'Cliente'),

                        const SizedBox(height: 10),

                        // --- PUNTOS GANADOS ---
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.black12, width: 1),
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
                                  border:
                                      Border.all(color: Colors.black45),
                                ),
                                child: Text(
                                  "+ $puntosGanados",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // BOTONES (NO ENTRAN EN LA CAPTURA)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // --- Botón Descargar ---
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _generarPDFComprobante(
                              context,
                              montoRecargado,
                              tipoTransferencia,
                              idTransaccion,
                              fecha,
                              hora,
                              puntosGanados,
                            );
                          },
                          icon: const Icon(Icons.download,
                              color: Colors.black),
                          label: const Text(
                            "Descargar",
                            style: TextStyle(color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            side:
                                const BorderSide(color: Colors.black12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),

                      // --- Botón Compartir ---
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _mostrarPopupCompartir(context);
                          },
                          icon:
                              const Icon(Icons.share, color: Colors.black),
                          label: const Text(
                            "Compartir",
                            style: TextStyle(color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            side:
                                const BorderSide(color: Colors.black12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // --- BOTÓN REGRESAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        side: const BorderSide(color: Colors.black12),
                      ),
                      child: const Text(
                        "Regresar",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- FUNCIÓN AUXILIAR PARA FILAS DE DETALLE ---
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE80A5D), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // --- GENERAR PDF DE COMPROBANTE ---
  Future<void> _generarPDFComprobante(
    BuildContext context,
    double monto,
    String metodo,
    String id,
    String fecha,
    String hora,
    int puntos,
  ) async {
    final pdf = pw.Document();
    try {
      // Captura la imagen del comprobante visual
      final boundary = _comprobanteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      pw.Widget comprobanteWidget;
      Uint8List? pngBytes;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          pngBytes = byteData.buffer.asUint8List();
        }
      }

      if (pngBytes != null) {
        final imageProvider = pw.MemoryImage(pngBytes);
        comprobanteWidget = pw.Center(
          child: pw.Image(imageProvider, fit: pw.BoxFit.contain, width: 350),
        );
      } else {
        comprobanteWidget = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text("Comprobante de Recarga Exitosa",
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Monto Recargado: S/ ${monto.toStringAsFixed(2)}"),
            pw.Text("Método de Pago: $metodo"),
            pw.Text("ID Transacción: $id"),
            pw.Text("Fecha: $fecha"),
            pw.Text("Hora: $hora"),
            pw.SizedBox(height: 10),
            pw.Text("Puntos Ganados: +$puntos"),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text("¡Gracias por tu recarga!",
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic, fontSize: 14)),
            ),
          ],
        );
      }

      pdf.addPage(
        pw.Page(
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: comprobanteWidget,
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/comprobante_recarga.pdf");
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("PDF guardado correctamente en la app. Abriendo archivo..."),
          backgroundColor: Colors.green.shade600,
        ),
      );

      // Abrir el archivo PDF automáticamente para visualizarlo
      try {
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("No se pudo abrir el PDF"),
              content: const Text(
                "El comprobante se guardó correctamente, pero no se pudo abrir automáticamente.\n\nPuedes buscarlo en la carpeta de documentos de tu dispositivo: comprobante_recarga.pdf"
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Aceptar"),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("No se pudo abrir el PDF"),
            content: Text(
              "El comprobante se guardó correctamente, pero ocurrió un error al intentar abrirlo automáticamente.\n\nPuedes buscarlo en la carpeta de documentos de tu dispositivo: comprobante_recarga.pdf\n\nError: $e"
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Aceptar"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al generar PDF: $e"),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  // --- POPUP DE COMPARTIR COMPROBANTE ---
  void _mostrarPopupCompartir(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Compartir comprobante de pago",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text(
                  "Compartir",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                onPressed: () async {
                  await _capturarYCompartirComprobante();
                  if (mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Captura el comprobante mostrado en el popup de recarga y lo comparte como imagen
  Future<void> _capturarYCompartirComprobante() async {
    try {
      final boundary = _comprobanteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo capturar el comprobante.'),
            backgroundColor: Colors.red.shade400,
          ),
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/comprobante_recarga_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Comprobante de recarga');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir comprobante: $e'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}

// --- WIDGET DE ICONO DE COMPARTIR ---
class _IconoCompartir extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconoCompartir({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            radius: 28,
            child: Icon(icon, size: 30, color: const Color(0xFFE80A5D)),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class MovimientoItem extends StatelessWidget {
  final Map<String, dynamic> movimientoRaw;

  const MovimientoItem({
    super.key,
    required this.movimientoRaw,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = (movimientoRaw['tipo'] ?? '').toString();
    final fecha = (movimientoRaw['fecha'] ?? '').toString();
    final montoNum = (movimientoRaw['monto'] is num)
        ? (movimientoRaw['monto'] as num).toDouble()
        : double.tryParse(movimientoRaw['monto'].toString()) ?? 0.0;
    final prefijo = tipo == 'recarga' ? '+ ' : '- ';
    final tituloBase = tipo == 'recarga' ? 'RECARGA' : 'GASTO';
    final color = tipo == 'recarga' ? Colors.green : Colors.black87;

    return InkWell(
      onTap: () {
        final movimiento = Movimiento(
          titulo: tituloBase,
          monto: montoNum,
          tipo: tipo,
          fecha: fecha,
        );

        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, animation, secondaryAnimation) =>
                FadeTransition(
              opacity: animation,
              child: DetalleMovimientoPage(
                movimiento: movimiento,
                datosAdicionales: movimientoRaw,
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tituloBase,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 3),
                Text(fecha,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            Row(
              children: [
                Text(
                  "S/ $prefijo${montoNum.toStringAsFixed(2)}",
                  style: TextStyle(
                      color: color, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                const Icon(Ionicons.chevron_forward_outline,
                    color: Colors.grey, size: 20), // Flechita
              ],
            ),
          ],
        ),
      ),
    );
  }
}
