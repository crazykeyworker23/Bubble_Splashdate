import 'package:flutter/material.dart';
import 'ReceiptPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Asumiendo que ReceiptPage está definida o importada aquí
// (Si está en otro archivo, asegúrate de importarla: import 'receipt_page.dart';)

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialPedidos;
  const CartPage({super.key, required this.initialPedidos});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late List<Map<String, dynamic>> pedidos;
  String selectedDineOption = 'En el Local';

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double _computeUnitTotal(Map<String, dynamic> item) {
    // Si tenemos desglose, este es el valor “real” a cobrar por unidad.
    if (item.containsKey('basePrice') ||
        item.containsKey('sizeExtra') ||
        item.containsKey('iceExtra') ||
        item.containsKey('toppingsTotal')) {
      final base = _asDouble(item['basePrice']);
      final sizeExtra = _asDouble(item['sizeExtra']);
      final iceExtra = _asDouble(item['iceExtra']);

      double toppingsTotal = _asDouble(item['toppingsTotal']);
      if (toppingsTotal == 0.0) {
        final rawToppings = item['toppings'];
        if (rawToppings is List) {
          toppingsTotal = rawToppings.fold<double>(0.0, (sum, t) {
            if (t is Map) return sum + _asDouble(t['price']);
            return sum;
          });
        }
      }

      return base + sizeExtra + iceExtra + toppingsTotal;
    }

    // Fallback a lo que se guardó históricamente.
    return _asDouble(item['price']);
  }

  void _repriceItemsToMatchTotal(
    List<Map<String, dynamic>> items,
    double targetTotal,
  ) {
    if (items.isEmpty) return;

    final int targetCents = (targetTotal * 100).round();
    if (targetCents <= 0) return;

    final originalLineCents = <int>[];
    int sumOriginalCents = 0;

    for (final item in items) {
      final int quantity = _asInt(item['quantity'] ?? 1);
      final int safeQty = quantity <= 0 ? 1 : quantity;
      final double unit = _asDouble(item['price']);
      final int cents = (unit * safeQty * 100).round();
      originalLineCents.add(cents);
      sumOriginalCents += cents;
    }

    if (sumOriginalCents <= 0) return;

    int allocated = 0;
    for (int i = 0; i < items.length; i++) {
      final int quantity = _asInt(items[i]['quantity'] ?? 1);
      final int safeQty = quantity <= 0 ? 1 : quantity;

      int newLineCents;
      if (i == items.length - 1) {
        newLineCents = targetCents - allocated;
      } else {
        newLineCents = ((originalLineCents[i] * targetCents) / sumOriginalCents)
            .round();
        allocated += newLineCents;
      }

      final double newUnit = (newLineCents / safeQty) / 100.0;
      items[i]['price'] = newUnit;
    }
  }

  List<int> _extractToppingsIds(Map<String, dynamic> item) {
    final dynamic rawToppingsIds = item['toppingsIds'];
    if (rawToppingsIds is List) {
      return rawToppingsIds
          .map((e) => _asInt(e))
          .where((id) => id > 0)
          .toList();
    }

    final dynamic rawToppings = item['toppings'];
    if (rawToppings is List) {
      // Puede venir como List<String> o List<Map>{id,name,price}
      final ids = <int>[];
      for (final t in rawToppings) {
        if (t is Map) {
          final id = _asInt(t['id']);
          if (id > 0) ids.add(id);
        }
      }
      return ids;
    }

    return <int>[];
  }

  String _formatToppingsForUi(Map<String, dynamic> item) {
    final dynamic raw = item['toppings'];
    if (raw is List) {
      if (raw.isEmpty) return 'Sin toppings';
      if (raw.first is String) {
        return raw.join(', ');
      }
      if (raw.first is Map) {
        return raw
            .map((e) => (e is Map ? (e['name'] ?? '').toString() : ''))
            .where((name) => name.trim().isNotEmpty)
            .join(', ');
      }
      return raw.map((e) => e.toString()).join(', ');
    }
    return 'Sin toppings';
  }

  @override
  void initState() {
    super.initState();
    pedidos = widget.initialPedidos.map((p) {
      return {...p, 'quantity': p.containsKey('quantity') ? p['quantity'] : 1};
    }).toList();
  }

  double get _totalPrice {
    return pedidos.fold(0.0, (sum, p) {
      final double unit = _computeUnitTotal(p);
      final int quantity = _asInt(p['quantity'] ?? 1);
      final int safeQty = quantity <= 0 ? 1 : quantity;
      return sum + (unit * safeQty);
    });
  }

  void _clearAll() {
    setState(() {
      pedidos.clear();
    });
    // Si se vacía el carrito, volvemos al menú con la lista actualizada
    if (mounted) {
      Navigator.pop(context, pedidos);
    }
  }

  void _removeItem(int index) {
    setState(() {
      pedidos.removeAt(index);
    });

    // Si ya no quedan productos, volvemos al menú
    if (pedidos.isEmpty && mounted) {
      Navigator.pop(context, pedidos);
    }
  }

  void _increaseQuantity(int index) {
    setState(() {
      pedidos[index]['quantity'] += 1;
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (pedidos[index]['quantity'] > 1) {
        pedidos[index]['quantity'] -= 1;
      } else {
        _removeItem(index);
      }
    });
  }

  /// Verifica en el backend si la billetera tiene saldo suficiente
  /// para cubrir el total actual del carrito.
  /// Si no alcanza, muestra un mensaje y devuelve false.
  Future<bool> _verificarSaldoSuficiente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay access token. Inicia sesión nuevamente para usar tu billetera.',
            ),
          ),
        );
        return false;
      }

      final token = rawToken.trim();
      final uri = BackendConfig.api('bubblesplash/wallet/me/');

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu sesión ha expirado. Inicia sesión nuevamente para usar tu billetera.',
            ),
          ),
        );
        return false;
      }

      if (response.statusCode != 200) {
        debugPrint(
          'Error al consultar saldo de billetera: ${response.statusCode} ${response.body}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo verificar el saldo de tu billetera.'),
          ),
        );
        return false;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
      final double saldoBackend = double.tryParse(balanceStr) ?? 0.0;

      if (saldoBackend + 1e-6 < _totalPrice) {
        // No alcanza el saldo para cubrir el total
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Saldo insuficiente'),
              content: Text(
                'Tu saldo disponible es S/. ${saldoBackend.toStringAsFixed(2)} y el total de tu pedido es S/. ${_totalPrice.toStringAsFixed(2)}. Por favor, recarga tu billetera para continuar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Excepción al verificar saldo de billetera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error al verificar el saldo de tu billetera.',
          ),
        ),
      );
      return false;
    }
  }

  /// Lee el saldo actual desde el backend (wallet/me).
  /// Se usa para diagnóstico: saber cuánto descontó el servidor.
  Future<double?> _getSaldoBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');
      if (rawToken == null || rawToken.trim().isEmpty) return null;

      final uri = BackendConfig.api('bubblesplash/wallet/me/');
      http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${rawToken.trim()}',
        },
      );

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

      if (response.statusCode != 200) {
        debugPrint('No se pudo leer saldo wallet/me: ${response.statusCode} ${response.body}');
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
      return double.tryParse(balanceStr) ?? 0.0;
    } catch (e) {
      debugPrint('Excepción al leer saldo wallet/me: $e');
      return null;
    }
  }

  /// Construye y envía el pedido al backend.
  /// Devuelve el JSON de respuesta si todo va bien, o null si falla.
  Future<Map<String, dynamic>?> _crearPedidoBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay access token. Inicia sesión nuevamente para pagar.',
            ),
          ),
        );
        return null;
      }

      final token = rawToken.trim();

      // Mapear opción de consumo a código esperado por el backend
      String deliveryCode;
      if (selectedDineOption.toLowerCase().contains('llevar')) {
        deliveryCode = 'PARA_LLEVAR';
      } else {
        deliveryCode = 'EN_LOCAL';
      }

      final List<Map<String, dynamic>> itemsPayload = [];

      for (final item in pedidos) {
        final dynamic rawProductId = item.containsKey('productId')
            ? item['productId']
            : item['id'];
        final int proIntId = _asInt(rawProductId);

        if (proIntId <= 0) continue;

        final int quantity = _asInt(item['quantity'] ?? 1);
        final String size = (item['size'] ?? '').toString().toUpperCase();
        final List<int> toppingsIds = _extractToppingsIds(item);

        final String notes = (item['notes'] ?? '').toString();

        itemsPayload.add({
          'pro_int_id': proIntId,
          'pdi_txt_size': size,
          'pdi_int_quantity': quantity,
          'toppings': toppingsIds,
          // Por ahora no hay campo de notas en la UI
          'pdi_txt_notes': notes,
        });
      }

      if (itemsPayload.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo crear el pedido: faltan datos de productos.',
            ),
          ),
        );
        return null;
      }

      final body = jsonEncode({
        'ped_txt_delivery': deliveryCode,
        'items': itemsPayload,
      });

      final uri = BackendConfig.api('bubblesplash/pedidos/');

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu sesión ha expirado. Por favor, inicia sesión nuevamente para pagar.',
            ),
          ),
        );
        return null;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        debugPrint(
          'Error al crear pedido: ${response.statusCode} ${response.body}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo crear el pedido (${response.statusCode}): ${response.body}',
            ),
          ),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Excepción al crear pedido: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error inesperado al procesar el pedido.'),
        ),
      );
      return null;
    }
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final String name = item['name'] ?? 'Producto Desconocido';
    final double price = _computeUnitTotal(item);
    final int quantity = item['quantity'] ?? 1;
    final String imagePath = 'assets/bebidas.png';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              imagePath,
              height: 85,
              width: 85,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "S/. ${price.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                  ),
                ),
                Text(
                  "${item['size']}, ${item['ice']}, ${_formatToppingsForUi(item)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 🔹 Sección de cantidad y eliminar
          Row(
            children: [
              // Botón eliminar
              GestureDetector(
                onTap: () => _removeItem(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón disminuir cantidad
              GestureDetector(
                onTap: () => _decreaseQuantity(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Cantidad
              Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),

              // Botón aumentar cantidad
              GestureDetector(
                onTap: () => _increaseQuantity(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, color: Colors.blue.shade600, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalItems = pedidos.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1B6F81),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          // 1. CORRECCIÓN: Devolver la lista actualizada de pedidos al ir atrás
          onPressed: () => Navigator.pop(context, pedidos),
        ),
        title: const Text(
          'Atrás',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Precio',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  'S/. ${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearAll,
                child: const Text(
                  'Borrar Todo',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: totalItems == 0
                ? const Center(
                    child: Text("Tu carrito está vacío. ¡Agrega algo!"),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: totalItems,
                    itemBuilder: (context, index) {
                      return _buildCartItem(pedidos[index], index);
                    },
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                  ),
          ),

          // 🔹 Sección inferior (botón pagar + opciones)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3F0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '¿De qué forma lo vas a disfrutar?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDineOptionButton('En el Local', Icons.house_outlined),
                    _buildDineOptionButton('Para Llevar', Icons.card_giftcard),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: totalItems > 0
                        ? () async {
                            // Confirmación: mostrar el monto real del carrito
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Confirmar pago'),
                                content: Text(
                                  '¿Deseas pagar S/. ${_totalPrice.toStringAsFixed(2)}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Pagar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;

                            // Diagnóstico: saldo antes de crear el pedido
                            final double? saldoAntes =
                              await _getSaldoBackend();

                            // 1) Verificar saldo suficiente en billetera
                            final tieneSaldo =
                                await _verificarSaldoSuficiente();
                            if (!tieneSaldo) return;

                            // 2) Crear pedido en backend
                            final pedidoData = await _crearPedidoBackend();
                            if (pedidoData == null) return;

                            // Diagnóstico: saldo después de crear el pedido
                            final double? saldoDespues =
                                await _getSaldoBackend();
                            if (saldoAntes != null && saldoDespues != null) {
                              final double descontado =
                                  (saldoAntes - saldoDespues);
                              debugPrint(
                                'DIAGNÓSTICO COBRO: appTotal=S/. ${_totalPrice.toStringAsFixed(2)} | serverDelta=S/. ${descontado.toStringAsFixed(2)} | saldoAntes=S/. ${saldoAntes.toStringAsFixed(2)} | saldoDespues=S/. ${saldoDespues.toStringAsFixed(2)}',
                              );

                              // Si el servidor descuenta distinto, lo mostramos.
                              if (mounted &&
                                  (descontado - _totalPrice).abs() > 0.01) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'El servidor descontó S/. ${descontado.toStringAsFixed(2)} (tu carrito: S/. ${_totalPrice.toStringAsFixed(2)}).',
                                    ),
                                  ),
                                );
                              }
                            }

                            // Copia para el recibo antes de limpiar el carrito
                            final List<Map<String, dynamic>> finalPedidosCopy =
                                pedidos
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList();

                            // Requisito: cobrar sin IGV. Usar el total real calculado por la app
                            // (precio base + extras) y NO el total del backend.
                            final double localSubtotal = _totalPrice;

                            // Fecha/hora desde el backend si existe
                            String? backendDate;
                            String? backendTime;
                            final String ts =
                                (pedidoData['timestamp_datecreate'] ?? '')
                                    .toString();
                            if (ts.isNotEmpty) {
                              try {
                                final dt = DateTime.parse(ts);
                                backendDate =
                                    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
                                backendTime =
                                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              } catch (_) {}
                            }

                            final String orderNumber =
                                (pedidoData['ped_txt_number'] ?? '').toString();

                            // Limpiar carrito persistido al completar el pago
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('cart_pedidos');

                            if (mounted) {
                              setState(() {
                                pedidos.clear();
                              });
                            }

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReceiptPage(
                                  finalPedidos: finalPedidosCopy,
                                  dineOption: selectedDineOption,
                                  subtotal: localSubtotal,
                                  backendOrderNumber: orderNumber.isNotEmpty
                                      ? orderNumber
                                      : null,
                                  backendDate: backendDate,
                                  backendTime: backendTime,
                                  alreadyPaid: true,
                                  applyWalletDeduction: true,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6961),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Pagar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(
                          totalItems > 0 ? 1.0 : 0.7,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDineOptionButton(String text, IconData icon) {
    final bool isSelected = selectedDineOption == text;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedDineOption = text;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B6F81) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1B6F81)
                  : const Color(0xFFB0BEC5),
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF1B6F81),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
