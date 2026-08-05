import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'ReceiptPage.dart';
import 'pagos_page.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'dart:convert';

import 'dart:typed_data';
import 'package:bubblesplash/utils/tamanos.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialPedidos;
  final double descuento;
  // Id opcional de la oferta/canje aplicada al pedido (ofc_int_id)
  final int? ofcIntId;
  const CartPage({
    super.key,
    required this.initialPedidos,
    this.descuento = 0.0,
    this.ofcIntId,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late List<Map<String, dynamic>> pedidos;
  String selectedDineOption = 'En el Local';
  double get _descuento => widget.descuento;
  bool _isProcessingPago = false;

  /// El carrito viene de un canje de oferta: el flujo debe cerrarse rápido.
  bool get _esCanje =>
      (widget.ofcIntId != null && widget.ofcIntId! > 0) || widget.descuento > 0;

  // =========================
  // ✅ MODAL PREMIUM (reemplaza SnackBar)
  // =========================
  Future<void> _showPremiumModal({
    required String title,
    required String message,
    IconData icon = Icons.info_rounded,
    Color accent = const Color(0xFF1B6F81),
    String buttonText = 'Entendido',
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, size: 34, color: accent),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  /// Redondea a 2 decimales para que no aparezcan céntimos fantasma.
  double _round2(double value) => (value * 100).round() / 100;

  /// Porcentaje de descuento (0.0 - 1.0) que aplica a ESTE ítem.
  ///
  /// El canje beneficia a un solo producto del carrito: el que se marcó como
  /// promocional al agregarlo. El resto se cobra a precio normal.
  double _itemDiscount(Map<String, dynamic> item) {
    if (item.containsKey('discountPercent')) {
      final value = _asDouble(item['discountPercent']);
      return value.clamp(0.0, 1.0);
    }
    if (item['isPromoItem'] == true) {
      return _descuento.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  /// Precio unitario SIN descuento: base + extra de vaso + hielo + toppings.
  double _computeUnitTotalSinDescuento(Map<String, dynamic> item) {
    if (item.containsKey('priceOriginal')) {
      return _round2(_asDouble(item['priceOriginal']));
    }

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

      return _round2(base + sizeExtra + iceExtra + toppingsTotal);
    }

    return _round2(_asDouble(item['price']));
  }

  /// ✅ Precio unitario REAL a cobrar.
  ///
  /// El descuento del canje se aplica sobre el total del ítem (base + tamaño +
  /// hielo + toppings), no solo sobre el precio base. Con una oferta del 100%
  /// el resultado es 0.00 aunque el vaso sea grande y tenga extras.
  double _computeUnitTotal(Map<String, dynamic> item) {
    final double bruto = _computeUnitTotalSinDescuento(item);
    final double descuento = _itemDiscount(item);
    if (descuento <= 0) return bruto;
    return _round2(bruto * (1 - descuento));
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

  /// Construye el payload de toppings para el backend.
  ///
  /// Soporta:
  /// - Lista de mapas con {id | top_int_id, qty?}  -> "toppings":[{"top_int_id":x,"qty":y}]
  /// - Lista de ids (int/string)                    -> "toppings_ids":[x,y]
  /// - Campo previo 'toppingsIds'/'toppings_ids'    -> "toppings_ids":[x,y]
  Map<String, dynamic> _buildToppingsBackendPayload(Map<String, dynamic> item) {
    final dynamic rawToppings = item['toppings'];
    final dynamic rawToppingsIds = item['toppingsIds'] ?? item['toppings_ids'];

    final List<Map<String, dynamic>> toppingsObjects = [];
    final Set<int> toppingsIdsSet = <int>{};

    // Toppings provenientes del carrito (lista)
    if (rawToppings is List) {
      for (final t in rawToppings) {
        if (t is Map) {
          final int id = _asInt(t['top_int_id'] ?? t['id']);
          if (id <= 0) continue;
          final int qtyRaw = _asInt(t['qty'] ?? 1);
          final int qty = qtyRaw <= 0 ? 1 : qtyRaw;
          toppingsObjects.add({'top_int_id': id, 'qty': qty});
          toppingsIdsSet.add(id);
        } else {
          final int id = _asInt(t);
          if (id > 0) toppingsIdsSet.add(id);
        }
      }
    }

    // Toppings ya expresados como ids
    if (rawToppingsIds is List) {
      for (final e in rawToppingsIds) {
        final int id = _asInt(e);
        if (id > 0) toppingsIdsSet.add(id);
      }
    }

    final Map<String, dynamic> payload = <String, dynamic>{};

    // Prioridad: estructura completa con qty ("toppings").
    if (toppingsObjects.isNotEmpty) {
      payload['toppings'] = toppingsObjects;
      return payload;
    }

    // Si solo tenemos ids, usamos "toppings_ids".
    if (toppingsIdsSet.isNotEmpty) {
      payload['toppings_ids'] = toppingsIdsSet.toList();
      return payload;
    }

    // Sin toppings
    return payload;
  }

  String _formatToppingsForUi(Map<String, dynamic> item) {
    final dynamic raw = item['toppings'];
    if (raw is List) {
      if (raw.isEmpty) return '';
      if (raw.first is String) {
        return raw
            .map((e) => e.toString())
            .where((name) => name.trim().isNotEmpty)
            .join(', ');
      }
      if (raw.first is Map) {
        return raw
            .map((e) => (e is Map ? (e['name'] ?? '').toString() : ''))
            .where((name) => name.trim().isNotEmpty)
            .join(', ');
      }
      return raw.map((e) => e.toString()).join(', ');
    }
    return '';
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

  // Subtotal sin aplicar el descuento global del carrito
  double get _subtotalSinDescuento {
    return pedidos.fold(0.0, (sum, p) {
      final double unit = _computeUnitTotalSinDescuento(p);
      final int quantity = _asInt(p['quantity'] ?? 1);
      final int safeQty = quantity <= 0 ? 1 : quantity;
      return sum + (unit * safeQty);
    });
  }

  // Monto total de descuento aplicado en el carrito
  double get _montoDescuento {
    if (_descuento <= 0) return 0.0;
    final double subtotal = _subtotalSinDescuento;
    final double total = _totalPrice;
    final double diff = subtotal - total;
    if (diff < 0) return 0.0;
    return diff;
  }

  void _clearAll() {
    setState(() => pedidos.clear());
    if (mounted) Navigator.pop(context, pedidos);
  }

  void _removeItem(int index) {
    setState(() => pedidos.removeAt(index));
    if (pedidos.isEmpty && mounted) Navigator.pop(context, pedidos);
  }

  void _increaseQuantity(int index) {
    final item = pedidos[index];

    // Si este ítem es el que usa el canje, limitamos la cantidad a 1
    if (item['isPromoItem'] == true) {
      final int currentQty = _asInt(item['quantity'] ?? 1);
      if (currentQty >= 1) {
        _showPremiumModal(
          title: 'Canje aplicado',
          message:
              'Este beneficio solo aplica a 1 producto. Si deseas más unidades, agrégalas como otro producto sin canje.',
          icon: Icons.local_offer_rounded,
          accent: const Color(0xFF1B6F81),
        );
        return;
      }
    }

    setState(
      () => pedidos[index]['quantity'] = _asInt(pedidos[index]['quantity']) + 1,
    );
  }

  void _decreaseQuantity(int index) {
    setState(() {
      final q = _asInt(pedidos[index]['quantity']);
      if (q > 1) {
        pedidos[index]['quantity'] = q - 1;
      } else {
        _removeItem(index);
      }
    });
  }

  Future<bool> _verificarSaldoSuficiente() async {
    try {
      final uri = BackendConfig.api('bubblesplash/wallet/me/');

      // AppHttp renueva el token automáticamente y fuerza logout si expira.
      final http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__', // AppHttp reemplaza esto
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Error al consultar saldo: ${response.statusCode} ${response.body}',
        );
        await _showPremiumModal(
          title: 'No se pudo verificar',
          message:
              'No se pudo verificar el saldo de tu billetera. Intenta nuevamente.',
          icon: Icons.wifi_off_rounded,
          accent: const Color(0xFFE80A5D),
        );
        return false;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
      final double saldoBackend = double.tryParse(balanceStr) ?? 0.0;

      if (saldoBackend + 1e-6 < _totalPrice) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 60,
                      color: Color(0xFFFFA726),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Saldo insuficiente',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B6F81),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Tu saldo disponible es S/. ${saldoBackend.toStringAsFixed(2)} '
                      'y el total de tu pedido es S/. ${_totalPrice.toStringAsFixed(2)}.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'Recarga tu billetera para continuar con el pago.',
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 22),

                    // 🔹 BOTONES
                    Row(
                      children: [
                        // 👉 Ir a billetera
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B6F81),
                              side: const BorderSide(
                                color: Color(0xFF1B6F81),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PagosPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Ir a mi billetera',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 👉 Entendido
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B6F81),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Entendido',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Excepción al verificar saldo: $e');
      await _showPremiumModal(
        title: 'Error',
        message: 'Ocurrió un error al verificar el saldo de tu billetera.',
        icon: Icons.error_rounded,
        accent: const Color(0xFFE53935),
      );
      return false;
    }
  }

  Future<double?> _getSaldoBackend() async {
    try {
      final uri = BackendConfig.api('bubblesplash/wallet/me/');
      // AppHttp renueva el token automáticamente.
      final http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          'No se pudo leer saldo: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final String balanceStr = (data['wal_de_balance'] ?? '0').toString();
      return double.tryParse(balanceStr) ?? 0.0;
    } catch (e) {
      debugPrint('Excepción al leer saldo: $e');
      return null;
    }
  }

  /// Ítems del carrito en el formato que espera el backend.
  ///
  /// Se extrajo a su propio método para que la consulta del total y la
  /// creación del pedido usen EXACTAMENTE el mismo cuerpo. Si difirieran,
  /// el importe consultado no sería el que se acaba cobrando.
  List<Map<String, dynamic>> _construirItemsPayload() {
    final List<Map<String, dynamic>> itemsPayload = [];
    for (final item in pedidos) {
      final dynamic rawProductId = item.containsKey('productId')
          ? item['productId']
          : item['id'];
      final int proIntId = _asInt(rawProductId);
      if (proIntId <= 0) continue;

      final int quantity = _asInt(item['quantity'] ?? 1);
      final String size = (item['size'] ?? '').toString().toUpperCase();
      final String notes = (item['notes'] ?? '').toString();
      final double priceWithDiscount = _computeUnitTotal(item);
      final double sizeExtraValue = _asDouble(item['sizeExtra']);

      // Construir item base (el backend calcula el precio, solo usamos
      // priceWithDiscount en la app para saldo y recibo).
      final Map<String, dynamic> itemMap = <String, dynamic>{
        'pro_int_id': proIntId,
        'pdi_txt_size': size,
        'pdi_int_quantity': quantity,
        'pdi_txt_notes': notes,
      };

      // ✅ Indica al backend sobre QUÉ ítem debe aplicar el canje, para que
      //    el descuento caiga en el producto correcto (base + tamaño +
      //    toppings) y no se reparta sobre todo el carrito.
      if (_itemDiscount(item) > 0) {
        itemMap['pdi_bool_promo'] = true;
      }

      // Enviar explícitamente el valor extra asociado al tamaño del vaso,
      // para que el backend pueda considerar este monto al calcular el total.
      if (sizeExtraValue != 0.0) {
        itemMap['pdi_de_size_extraprice'] = sizeExtraValue;
      }

      // Adjuntar toppings según corresponda
      final Map<String, dynamic> toppingsPayload = _buildToppingsBackendPayload(
        item,
      );
      itemMap.addAll(toppingsPayload);

      // Log de diagnóstico: cómo está calculando la app cada ítem
      try {
        final double base = _asDouble(item['basePrice']);
        final double sizeExtra = sizeExtraValue;
        final double iceExtra = _asDouble(item['iceExtra']);
        final double toppingsTotal = _asDouble(item['toppingsTotal']);
        debugPrint(
          'ITEM PEDIDO APP => pro_int_id=$proIntId, size=$size, qty=$quantity, '
          'base=$base, sizeExtra=$sizeExtra, iceExtra=$iceExtra, '
          'toppingsTotal=$toppingsTotal, unitTotalApp=$priceWithDiscount, '
          'toppingsPayload=$toppingsPayload',
        );
      } catch (_) {}

      itemsPayload.add(itemMap);
    }

    return itemsPayload;
  }

  Map<String, dynamic> _construirPayload({
    required String deliveryCode,
    required List<Map<String, dynamic>> itemsPayload,
  }) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'ped_txt_delivery': deliveryCode,
      'ped_txt_channel': 'APP',
      'items': itemsPayload,
    };

    // Si hay una oferta/canje asociado, lo adjuntamos.
    final int? ofcId = widget.ofcIntId;
    if (ofcId != null && ofcId > 0) {
      payload['ofc_int_id'] = ofcId;
    }

    return payload;
  }

  /// Total que va a cobrar el backend, consultado ANTES de crear el pedido.
  ///
  /// El servidor recalcula el precio por su cuenta: aplica el recargo por
  /// tamaño y el canje solo si sigue siendo válido. Preguntárselo antes evita
  /// el caso que se dio en producción: el carrito guardado en el teléfono
  /// conservaba el precio con descuento de un canje que ya no viajaba en la
  /// petición, así que la app mostraba S/ 10 y el backend cobraba S/ 25.
  ///
  /// Devuelve `null` si no se pudo consultar; en ese caso se continúa y queda
  /// la comprobación posterior al cobro como última red.
  Future<double?> _totalSegunBackend(String deliveryCode) async {
    try {
      final itemsPayload = _construirItemsPayload();
      if (itemsPayload.isEmpty) return null;

      final response = await http.post(
        BackendConfig.api('bubblesplash/pedidos/preview/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__',
        },
        body: jsonEncode(
          _construirPayload(
            deliveryCode: deliveryCode,
            itemsPayload: itemsPayload,
          ),
        ),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Preview no disponible: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return double.tryParse((decoded['total'] ?? '').toString());
    } catch (e) {
      debugPrint('Excepción consultando el total al backend: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _crearPedidoBackend() async {
    try {
      String deliveryCode;
      if (selectedDineOption.toLowerCase().contains('llevar')) {
        deliveryCode = 'PARA_LLEVAR';
      } else {
        deliveryCode = 'EN_LOCAL';
      }

      final List<Map<String, dynamic>> itemsPayload = _construirItemsPayload();

      // Log de diagnóstico: total que espera la app vs lo que luego descuenta el backend
      debugPrint(
        'DIAGNOSTICO PRE-PEDIDO: totalCarritoApp=S/. '
        '${_totalPrice.toStringAsFixed(2)} para ${itemsPayload.length} items',
      );

      if (itemsPayload.isEmpty) {
        await _showPremiumModal(
          title: 'Carrito inválido',
          message: 'No se pudo crear el pedido: faltan datos de productos.',
          icon: Icons.shopping_cart_checkout_rounded,
          accent: const Color(0xFFE80A5D),
        );
        return null;
      }

      final Map<String, dynamic> pedidoPayload = _construirPayload(
        deliveryCode: deliveryCode,
        itemsPayload: itemsPayload,
      );

      final String body = jsonEncode(pedidoPayload);

      debugPrint('CREAR PEDIDO REQUEST => $body');

      final uri = BackendConfig.api('bubblesplash/pedidos/');

      // AppHttp renueva el token automáticamente y fuerza logout si expira.
      final http.Response response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
          'CREAR PEDIDO OK => ${response.statusCode} ${response.body}',
        );
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint(
          'Error al crear pedido: ${response.statusCode} ${response.body}',
        );

        String errorMessage =
            'No se pudo crear el pedido (${response.statusCode}). Intenta nuevamente.';

        // Si el backend manda un "detail", lo mostramos al usuario
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final String detail =
                (decoded['detail'] ?? decoded['message'] ?? '').toString();
            if (detail.isNotEmpty) {
              errorMessage = detail;
            }
          }
        } catch (_) {}

        await _showPremiumModal(
          title: 'No se pudo procesar',
          message: errorMessage,
          icon: Icons.receipt_long_rounded,
          accent: const Color(0xFFE53935),
        );
        return null;
      }
    } catch (e) {
      debugPrint('Excepción al crear pedido: $e');
      await _showPremiumModal(
        title: 'Error',
        message: 'Error inesperado al procesar el pedido.',
        icon: Icons.error_rounded,
        accent: const Color(0xFFE53935),
      );
      return null;
    }
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    final String name = (item['name'] ?? 'Producto Desconocido').toString();
    final double price = _computeUnitTotal(item);
    final int quantity = _asInt(item['quantity'] ?? 1);

    final String sizeText = etiquetaTamano((item['size'] ?? '').toString());
    final String iceText = (item['ice'] ?? '').toString();
    final String toppingsText = _formatToppingsForUi(item).trim();
    final List<String> details = [
      if (sizeText.isNotEmpty) sizeText,
      if (iceText.isNotEmpty) iceText,
      if (toppingsText.isNotEmpty) toppingsText,
    ];

    final String? imagePath =
        item['image'] ?? item['imagePath'] ?? item['imageUrl'];
    final bool isNetworkImage =
        imagePath != null &&
        (imagePath.startsWith('http') || imagePath.startsWith('https'));

    // Detectar si es base64 (simple: cadena larga, sin http, y parece base64)
    bool isBase64Image = false;
    Uint8List? base64Bytes;
    if (imagePath != null && !isNetworkImage) {
      final base64RegExp = RegExp(r'^[A-Za-z0-9+/=\s]+$');
      // Opcional: quitar prefijo data:image/png;base64,
      String base64Str = imagePath;
      if (base64Str.startsWith('data:image')) {
        final idx = base64Str.indexOf('base64,');
        if (idx != -1) base64Str = base64Str.substring(idx + 7);
      }
      if (base64Str.length > 100 && base64RegExp.hasMatch(base64Str)) {
        try {
          base64Bytes = base64Decode(base64Str);
          isBase64Image = true;
        } catch (_) {
          isBase64Image = false;
        }
      }
    }

    debugPrint(
      'CartPage _buildCartItem: imagePath=$imagePath, isNetworkImage=$isNetworkImage, isBase64Image=$isBase64Image, item=$item',
    );

    Widget imageWidget;
    if (isNetworkImage) {
      imageWidget = CachedNetworkImage(
        imageUrl: imagePath!,
        height: 85,
        width: 85,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 85,
          width: 85,
          color: Colors.grey[200],
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Image.asset(
          'assets/bebidas.png',
          height: 85,
          width: 85,
          fit: BoxFit.cover,
        ),
      );
    } else if (isBase64Image && base64Bytes != null) {
      imageWidget = Image.memory(
        base64Bytes,
        height: 85,
        width: 85,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/bebidas.png',
          height: 85,
          width: 85,
          fit: BoxFit.cover,
        ),
      );
    } else {
      imageWidget = Image.asset(
        'assets/bebidas.png',
        height: 85,
        width: 85,
        fit: BoxFit.cover,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageWidget,
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
                if (details.isNotEmpty)
                  Text(
                    details.join(', '),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Row(
            children: [
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
              Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
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
    final bool hasDiscount = _descuento > 0;
    final double subtotalSinDescuento = _subtotalSinDescuento;
    final double montoDescuento = _montoDescuento;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1B6F81),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
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
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
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
                if (hasDiscount && montoDescuento > 0.009) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'S/. ${subtotalSinDescuento.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Descuento (${(_descuento * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                      Text(
                        '- S/. ${montoDescuento.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'S/. ${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
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
                    onPressed: (totalItems > 0 && !_isProcessingPago)
                        ? () async {
                            final prefs = await SharedPreferences.getInstance();
                            final isGuest = prefs.getBool('isGuest') ?? false;
                            if (isGuest) {
                              if (!mounted) return;
                              final login = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Row(
                                    children: const [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: Color(0xFF1B6F81),
                                        size: 28,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Acceso Requerido',
                                          style: TextStyle(
                                            color: Color(0xFF062B35),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: const Text(
                                    'Para realizar pedidos y pagar, por favor inicia sesión o crea una cuenta.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text(
                                        'Cancelar',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF1B6F81,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (login == true && mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (route) => false,
                                );
                              }
                              return;
                            }

                            setState(() => _isProcessingPago = true);
                            try {
                              final confirm = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (c) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  backgroundColor: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 28,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.payments_rounded,
                                          size: 60,
                                          color: Color(0xFF42A5F5),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _esCanje
                                              ? 'Confirmar canje'
                                              : 'Confirmar pago',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B6F81),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          // Con un canje del 100% el total es 0:
                                          // no tiene sentido preguntar "¿pagar S/ 0.00?".
                                          _totalPrice <= 0
                                              ? 'Tu canje cubre el 100% de este pedido. ¿Confirmas el pedido sin costo?'
                                              : _esCanje
                                              ? 'Con tu canje pagarás S/. ${_totalPrice.toStringAsFixed(2)} en lugar de S/. ${_subtotalSinDescuento.toStringAsFixed(2)}. ¿Confirmas?'
                                              : '¿Deseas pagar S/. ${_totalPrice.toStringAsFixed(2)}?',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFF1B6F81,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xFF1B6F81),
                                                    width: 2,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text(
                                                  'Cancelar',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF42A5F5,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text(
                                                  'Pagar',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (confirm != true) return;

                              final double? saldoAntes =
                                  await _getSaldoBackend();

                              final tieneSaldo =
                                  await _verificarSaldoSuficiente();
                              if (!tieneSaldo) return;

                              // Se compara el total con el que calcula el
                              // servidor ANTES de crear el pedido.
                              //
                              // La comprobación que había se hacía después de
                              // cobrar: detectaba el desajuste, sí, pero el
                              // dinero ya había salido de la billetera. Aquí
                              // se corta antes de que se mueva nada.
                              final String deliveryCode =
                                  selectedDineOption.toLowerCase().contains(
                                    'llevar',
                                  )
                                  ? 'PARA_LLEVAR'
                                  : 'EN_LOCAL';

                              final double? totalServidor =
                                  await _totalSegunBackend(deliveryCode);

                              if (totalServidor != null &&
                                  (totalServidor - _totalPrice).abs() > 0.01) {
                                if (!mounted) return;
                                await _showPremiumModal(
                                  title: 'El precio cambió',
                                  message:
                                      'El total de tu pedido es S/. '
                                      '${totalServidor.toStringAsFixed(2)}, no S/. '
                                      '${_totalPrice.toStringAsFixed(2)}.\n\n'
                                      'Puede que un descuento ya se haya usado o '
                                      'haya vencido. No se cobró nada; vuelve a '
                                      'armar tu pedido para ver el precio real.',
                                  icon: Icons.price_change_rounded,
                                  accent: const Color(0xFFE53935),
                                );
                                return;
                              }

                              final pedidoData = await _crearPedidoBackend();
                              if (pedidoData == null) return;

                              final double? saldoDespues =
                                  await _getSaldoBackend();
                              if (saldoAntes != null && saldoDespues != null) {
                                final double descontado =
                                    (saldoAntes - saldoDespues);
                                debugPrint(
                                  'DIAGNÓSTICO COBRO: appTotal=S/. ${_totalPrice.toStringAsFixed(2)} | serverDelta=S/. ${descontado.toStringAsFixed(2)}',
                                );

                                if (mounted &&
                                    (descontado - _totalPrice).abs() > 0.01) {
                                  await _showPremiumModal(
                                    title: 'Desajuste en el cobro',
                                    message:
                                        'Se descontó S/. ${descontado.toStringAsFixed(2)} desde la billetera, '
                                        'pero el total de tu pedido es S/. ${_totalPrice.toStringAsFixed(2)}.\n\n'
                                        'Por seguridad, no se marcará este pedido como pagado en la app. '
                                        'Por favor informa a un encargado para revisar el backend.',
                                    icon: Icons.warning_rounded,
                                    accent: const Color(0xFFE53935),
                                  );

                                  // No continuar al comprobante si el backend cobró menos
                                  return;
                                }
                              }

                              final List<Map<String, dynamic>>
                              finalPedidosCopy = pedidos
                                  .map((e) => Map<String, dynamic>.from(e))
                                  .toList();

                              final double localSubtotal = _totalPrice;

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
                                  (pedidoData['ped_txt_number'] ?? '')
                                      .toString();

                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.remove('cart_pedidos');

                              if (mounted) {
                                setState(() => pedidos.clear());
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
                                    // La boleta se emite con los datos de la
                                    // sede donde se registró el pedido.
                                    sedeJson:
                                        pedidoData['sede']
                                            is Map<String, dynamic>
                                        ? pedidoData['sede']
                                              as Map<String, dynamic>
                                        : null,
                                  ),
                                ),
                              );
                            } catch (e) {
                              debugPrint('Error procesando pago: $e');
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessingPago = false);
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6961),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isProcessingPago
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
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
        onTap: () => setState(() => selectedDineOption = text),
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
