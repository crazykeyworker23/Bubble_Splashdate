import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/services/app_http.dart' as http;

/// Historial de movimientos de la billetera.
///
/// POR QUÉ EXISTE ESTE ARCHIVO
/// ---------------------------
/// Antes, `MovimientosPage` y `PagosPage` cargaban y mezclaban los movimientos
/// cada una por su cuenta, con dos copias del mismo algoritmo. Las dos
/// mostraban la misma compra DOS VECES: una fila venía del backend y otra del
/// comprobante que la app guardaba en el teléfono, y el cruce entre ambas
/// nunca podía funcionar —la copia local se identificaba con un número de
/// pedido aleatorio generado en el móvil, que no existe en el servidor—.
///
/// LA REGLA AHORA
/// --------------
/// El backend es la ÚNICA fuente de la lista: cada movimiento de billetera
/// aparece una sola vez, con su importe y su fecha de servidor.
///
/// Lo que se guarda en el teléfono deja de ser una fila y pasa a ser DETALLE:
/// los productos, el tipo de entrega y la sede que hacen falta para reimprimir
/// la boleta, datos que el listado de movimientos del backend no trae. Ese
/// detalle se pega encima de la fila que le corresponde, emparejando por
/// número de pedido (`ped_txt_number`).
///
/// La única excepción son los flujos que NO pasan por el backend —pago por QR
/// y la recarga manual asistida—, que siguen siendo filas locales porque el
/// servidor no sabe nada de ellas.
class MovimientosService {
  /// Prefijos de los comprobantes que sólo existen en el teléfono.
  static const _prefijosSoloLocales = ['QR', 'REC'];

  /// Movimientos listos para pintar, del más reciente al más antiguo.
  static Future<List<Map<String, dynamic>>> cargar({String? nombreCliente}) async {
    final api = await _cargarDeApi(nombreCliente: nombreCliente);
    final locales = await cargarLocales();
    return _combinar(api: api, locales: locales);
  }

  // ==========================================================
  // BACKEND
  // ==========================================================
  static Future<List<Map<String, dynamic>>> _cargarDeApi({String? nombreCliente}) async {
    try {
      final response = await http.get(
        BackendConfig.api('bubblesplash/wallet/movimientos/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // AppHttp inyecta el token vigente y renueva la sesión si caducó.
          'Authorization': 'Bearer __placeholder__',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Movimientos: el servidor respondió ${response.statusCode} ${response.body}',
        );
        return [];
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List)
              ? decoded['results'] as List<dynamic>
              : const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map((item) => _desdeApi(item, nombreCliente))
          .toList();
    } catch (e) {
      debugPrint('Movimientos: excepción consultando el backend -> $e');
      return [];
    }
  }

  static Map<String, dynamic> _desdeApi(
    Map<String, dynamic> item,
    String? nombreCliente,
  ) {
    final esRecarga = (item['wmv_txt_type'] ?? '').toString().toUpperCase() == 'RECARGA';
    final monto = (double.tryParse((item['wmv_de_amount'] ?? '0').toString()) ?? 0.0).abs();
    final descripcion = (item['wmv_txt_description'] ?? '').toString();
    final id = (item['wmv_int_id'] ?? '').toString();
    final numeroPedido = (item['ped_txt_number'] ?? '').toString().trim();

    return <String, dynamic>{
      'tipo': esRecarga ? 'recarga' : 'gasto',
      'monto': monto,
      'metodo': esRecarga
          ? descripcion
          : (descripcion.isNotEmpty ? descripcion : 'Compra de productos'),
      // En las recargas la referencia va SIN el prefijo `MOV`: es el nombre con
      // el que se guardó el PDF del comprobante en el teléfono, y cambiarlo
      // dejaría inaccesibles los ya descargados.
      'referencia': esRecarga ? id : 'MOV$id',
      'fecha': _fechaLegible((item['timestamp_datecreate'] ?? '').toString()),
      'codigo': 'MOV$id',
      'orderNumber': numeroPedido,
      'orderId': item['ped_int_id'],
      'sede': item['sede'],
      'cliente': nombreCliente ?? 'Cliente',
      'origen': 'api',
    };
  }

  /// `2026-07-30T10:09:33Z` -> `2026-07-30 10:09`
  static String _fechaLegible(String iso) {
    if (!iso.contains('T')) return iso;
    try {
      return iso.replaceFirst('T', ' ').substring(0, 16);
    } catch (_) {
      return iso;
    }
  }

  // ==========================================================
  // ALMACÉN LOCAL
  // ==========================================================
  /// Clave de SharedPreferences donde vive el detalle guardado en el teléfono.
  static Future<String?> claveLocal() async {
    final prefs = await SharedPreferences.getInstance();

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}

    final email = prefs.getString('google_email') ?? prefs.getString('savedEmail');
    final id = user?.uid ?? ((email != null && email.isNotEmpty) ? email : null);

    return id != null ? 'movimientos_$id' : null;
  }

  static Future<List<Map<String, dynamic>>> cargarLocales() async {
    try {
      final clave = await claveLocal();
      if (clave == null) return [];

      final prefs = await SharedPreferences.getInstance();
      final crudos = prefs.getStringList(clave) ?? <String>[];

      final salida = <Map<String, dynamic>>[];
      for (final crudo in crudos) {
        try {
          final decoded = jsonDecode(crudo);
          if (decoded is Map) {
            salida.add(_normalizarMonto(Map<String, dynamic>.from(decoded)));
          }
        } catch (_) {
          // Entrada corrupta: se ignora en vez de tumbar el historial entero.
        }
      }
      return salida;
    } catch (e) {
      debugPrint('Movimientos: excepción leyendo el almacén local -> $e');
      return [];
    }
  }

  /// Guarda el detalle de una compra para poder reimprimir su boleta.
  ///
  /// `numeroPedido` es el número que devolvió el backend: es lo que permite
  /// reconocer después que este detalle y el movimiento del servidor son la
  /// misma operación. Si se guardara sin él —como se hacía antes— la compra
  /// volvería a aparecer duplicada en el historial.
  static Future<void> guardarDetalleCompra({
    required String numeroPedido,
    required Map<String, dynamic> detalle,
  }) async {
    final clave = await claveLocal();
    if (clave == null) return;

    final prefs = await SharedPreferences.getInstance();
    final crudos = prefs.getStringList(clave) ?? <String>[];

    final entrada = Map<String, dynamic>.from(detalle)
      ..['orderNumber'] = numeroPedido
      ..['origen'] = 'detalle';

    // Si ya había un detalle para este pedido (el usuario volvió a entrar al
    // comprobante), se reemplaza en vez de acumular copias.
    crudos.removeWhere((crudo) {
      try {
        final decoded = jsonDecode(crudo);
        return decoded is Map &&
            (decoded['orderNumber'] ?? '').toString() == numeroPedido;
      } catch (_) {
        return false;
      }
    });

    crudos.insert(0, jsonEncode(entrada));
    await prefs.setStringList(clave, crudos);
  }

  // ==========================================================
  // COMBINACIÓN
  // ==========================================================
  /// ¿Esta entrada local corresponde a un flujo que el backend desconoce?
  ///
  /// Los pagos por QR (`QR…`) y las recargas asistidas (`REC…`) no crean nada
  /// en el servidor, así que son las únicas entradas locales que siguen siendo
  /// filas por derecho propio.
  static bool _esSoloLocal(Map<String, dynamic> m) {
    final codigo = (m['codigo'] ?? '').toString().trim().toUpperCase();
    if (codigo.isEmpty) return false;
    return _prefijosSoloLocales.any(codigo.startsWith);
  }

  static List<Map<String, dynamic>> _combinar({
    required List<Map<String, dynamic>> api,
    required List<Map<String, dynamic>> locales,
  }) {
    // 1) Detalle de compras indexado por número de pedido.
    final detallePorPedido = <String, Map<String, dynamic>>{};
    final soloLocales = <Map<String, dynamic>>[];

    for (final local in locales) {
      if (_esSoloLocal(local)) {
        soloLocales.add(local);
        continue;
      }

      final numero = (local['orderNumber'] ?? '').toString().trim();
      if (numero.isNotEmpty) {
        detallePorPedido.putIfAbsent(numero, () => local);
      } else {
        // Comprobantes guardados por versiones anteriores de la app: no traen
        // el número de pedido, así que no se pueden emparejar. Se usan como
        // detalle de reserva —por importe— y NUNCA como fila propia: la fila
        // ya la pone el backend, y añadirlas era justo lo que duplicaba la
        // compra en el historial.
        final clave = _claveImporte(local);
        detallePorPedido.putIfAbsent('~$clave', () => local);
      }
    }

    // 2) Las filas son las del backend, enriquecidas con su detalle.
    final salida = <Map<String, dynamic>>[];
    for (final fila in api) {
      final numero = (fila['orderNumber'] ?? '').toString().trim();

      Map<String, dynamic>? detalle;
      if (numero.isNotEmpty) {
        detalle = detallePorPedido.remove(numero);
      }
      detalle ??= detallePorPedido.remove('~${_claveImporte(fila)}');

      salida.add(detalle == null ? fila : _enriquecer(fila, detalle));
    }

    // 3) Y por último los flujos que sólo viven en el teléfono.
    salida.addAll(soloLocales);

    salida.sort((a, b) => _fechaDe(b).compareTo(_fechaDe(a)));
    return salida;
  }

  /// Clave de reserva para comprobantes antiguos: tipo + importe.
  ///
  /// No se usa la fecha a propósito: la copia local lleva la hora del teléfono
  /// y la del backend la del servidor, que pueden estar en husos distintos.
  static String _claveImporte(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? '').toString();
    final monto = _comoDouble(m['monto']).toStringAsFixed(2);
    return '$tipo|$monto';
  }

  /// La fila del backend manda en importe y fecha; el detalle local aporta lo
  /// que el backend no guarda (productos, tipo de entrega, sede impresa).
  static Map<String, dynamic> _enriquecer(
    Map<String, dynamic> fila,
    Map<String, dynamic> detalle,
  ) {
    final salida = Map<String, dynamic>.from(fila);

    for (final campo in ['items', 'dineOption', 'cliente', 'sede', 'wallet']) {
      final valor = detalle[campo];
      final vacio = valor == null || (valor is List && valor.isEmpty);
      if (!vacio && (salida[campo] == null || _estaVacio(salida[campo]))) {
        salida[campo] = valor;
      }
    }

    return salida;
  }

  static bool _estaVacio(dynamic valor) {
    if (valor == null) return true;
    if (valor is String) return valor.trim().isEmpty;
    if (valor is List) return valor.isEmpty;
    if (valor is Map) return valor.isEmpty;
    return false;
  }

  // ==========================================================
  // UTILIDADES
  // ==========================================================
  static double _comoDouble(dynamic valor) {
    if (valor is double) return valor;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0.0;
  }

  static int _comoInt(dynamic valor) {
    if (valor is int) return valor;
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  /// Recalcula el importe de una compra local a partir de sus productos.
  ///
  /// El importe guardado puede quedar desfasado si el comprobante se rehízo;
  /// los productos son el dato duro.
  static Map<String, dynamic> _normalizarMonto(Map<String, dynamic> m) {
    if ((m['tipo'] ?? '').toString().toLowerCase() != 'gasto') return m;

    final items = m['items'];
    if (items is! List || items.isEmpty) return m;

    double suma = 0.0;
    for (final item in items) {
      if (item is! Map) continue;
      final cantidad = _comoInt(item['quantity'] ?? 1);
      suma += _comoDouble(item['price']) * (cantidad <= 0 ? 1 : cantidad);
    }

    if (suma <= 0) return m;
    return Map<String, dynamic>.from(m)..['monto'] = suma;
  }

  /// Interpreta tanto `2026-07-30 10:09` como `30/07/2026 10:09`.
  static DateTime _fechaDe(Map<String, dynamic> m) {
    final fecha = (m['fecha'] ?? '').toString().trim();
    if (fecha.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    if (fecha.contains('T') || RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(fecha)) {
      final normalizada = fecha.contains(' ') ? fecha.replaceFirst(' ', 'T') : fecha;
      return DateTime.tryParse(normalizada) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    try {
      final partes = fecha.split(' ');
      final d = partes[0].split('/');
      final t = (partes.length > 1 ? partes[1] : '00:00').split(':');
      if (d.length == 3) {
        return DateTime(
          int.tryParse(d[2]) ?? 1970,
          int.tryParse(d[1]) ?? 1,
          int.tryParse(d[0]) ?? 1,
          t.isNotEmpty ? (int.tryParse(t[0]) ?? 0) : 0,
          t.length > 1 ? (int.tryParse(t[1]) ?? 0) : 0,
        );
      }
    } catch (_) {}

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
