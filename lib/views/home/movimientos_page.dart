import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:bubblesplash/services/auth_service.dart';

import 'detail_movimiento_page.dart';
import 'movimiento.dart' as simple;

class MovimientosPage extends StatefulWidget {
  const MovimientosPage({super.key});

  @override
  State<MovimientosPage> createState() => _MovimientosPageState();
}

class _MovimientosPageState extends State<MovimientosPage> {
  List<Map<String, dynamic>> movimientosRaw = [];

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _computeMontoFromItems(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? '').toString().toLowerCase();
    if (tipo != 'gasto') return null;

    final dynamic rawItems = m['items'];
    if (rawItems is! List) return null;

    double sum = 0.0;
    for (final item in rawItems) {
      if (item is! Map) continue;
      final unit = _asDouble(item['price']);
      final qty = _asInt(item['quantity'] ?? 1);
      final safeQty = qty <= 0 ? 1 : qty;
      sum += unit * safeQty;
    }

    if (sum <= 0) return null;
    return sum;
  }

  Map<String, dynamic> _normalizeMonto(Map<String, dynamic> m) {
    final computed = _computeMontoFromItems(m);
    if (computed == null) return m;
    final out = Map<String, dynamic>.from(m);
    out['monto'] = computed;
    return out;
  }

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  Future<List<Map<String, dynamic>>> _cargarMovimientosLocales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      final String? keyMovs = user != null ? 'movimientos_${user.uid}' : null;
      final List<String> data = keyMovs != null
          ? (prefs.getStringList(keyMovs) ?? <String>[])
          : <String>[];

      final List<Map<String, dynamic>> parsed = [];
      for (final raw in data) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            parsed.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Ignorar entradas corruptas
        }
      }
      return parsed;
    } catch (e) {
      debugPrint('Excepción al cargar movimientos locales: $e');
      return [];
    }
  }

  DateTime _parseFechaMovimiento(Map<String, dynamic> m) {
    final fecha = (m['fecha'] ?? '').toString().trim();
    if (fecha.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    // ISO: 2026-01-10T12:34:56Z / 2026-01-10 12:34
    try {
      if (fecha.contains('T')) {
        return DateTime.tryParse(fecha) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(fecha)) {
        final normalized = fecha.contains(' ') ? fecha.replaceFirst(' ', 'T') : fecha;
        return DateTime.tryParse(normalized) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
    } catch (_) {}

    // Formato local: dd/MM/yyyy HH:mm
    try {
      final parts = fecha.split(' ');
      final datePart = parts.isNotEmpty ? parts[0] : fecha;
      final timePart = parts.length > 1 ? parts[1] : '00:00';
      final d = datePart.split('/');
      final t = timePart.split(':');
      if (d.length == 3) {
        final day = int.tryParse(d[0]) ?? 1;
        final month = int.tryParse(d[1]) ?? 1;
        final year = int.tryParse(d[2]) ?? 1970;
        final hour = t.isNotEmpty ? int.tryParse(t[0]) ?? 0 : 0;
        final minute = t.length > 1 ? int.tryParse(t[1]) ?? 0 : 0;
        return DateTime(year, month, day, hour, minute);
      }
    } catch (_) {}

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dedupeKey(Map<String, dynamic> m) {
    final codigo = (m['codigo'] ?? '').toString().trim();
    if (codigo.isNotEmpty) return 'codigo:$codigo';
    final tipo = (m['tipo'] ?? '').toString();
    final monto = (m['monto'] ?? '').toString();
    final fecha = (m['fecha'] ?? '').toString();
    final ref = (m['referencia'] ?? '').toString();
    return 't:$tipo|m:$monto|f:$fecha|r:$ref';
  }

  List<Map<String, dynamic>> _mergeMovimientos(
    List<Map<String, dynamic>> locales,
    List<Map<String, dynamic>> api,
  ) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addAll(List<Map<String, dynamic>> src) {
      for (final m in src) {
        final key = _dedupeKey(m);
        if (seen.add(key)) {
          out.add(m);
        }
      }
    }

    // Preferimos los movimientos locales porque contienen datos para reconstruir boletas (items, cliente, etc.)
    // y recalculamos el monto real desde los items.
    addAll(locales.map(_normalizeMonto).toList());
    addAll(api);

    out.sort((a, b) => _parseFechaMovimiento(b).compareTo(_parseFechaMovimiento(a)));
    return out;
  }

  Future<void> _cargarMovimientos() async {
    List<Map<String, dynamic>> apiMovimientos = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawToken = prefs.getString('access_token');

      if (rawToken == null || rawToken.trim().isEmpty) {
        debugPrint('No hay access_token para consultar movimientos (API)');
      } else {
        final token = rawToken.trim();
        final uri = Uri.parse(ApiConstants.baseUrl + '/bubblesplash/wallet/movimientos/');

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
          debugPrint('Sesión expirada al cargar movimientos (API)');
        } else if (response.statusCode == 200) {
          final List<dynamic> data =
              jsonDecode(response.body) as List<dynamic>;

          apiMovimientos = data.whereType<Map<String, dynamic>>().map((item) {
            final String rawType =
                (item['wmv_txt_type'] ?? '').toString();
            // Importante: DetalleMovimientoPage renderiza boleta de consumo cuando tipo == 'gasto'
            final String tipo =
                rawType.toUpperCase() == 'RECARGA' ? 'recarga' : 'gasto';

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
            };
          }).toList();
        } else {
          debugPrint(
              'Error al cargar movimientos (API): ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('Excepción al cargar movimientos (API): $e');
    }

    final locales = await _cargarMovimientosLocales();
    final listaFinal = _mergeMovimientos(locales, apiMovimientos);
    if (!mounted) return;
    setState(() {
      movimientosRaw = listaFinal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: movimientosRaw.isEmpty
          ? const Center(child: Text('No hay movimientos'))
          : ListView.builder(
              itemCount: movimientosRaw.length,
              itemBuilder: (context, i) {
                final m = movimientosRaw[i];
                final tipo = (m['tipo'] ?? '').toString();
                final metodo = (m['metodo'] ?? '').toString();
                final referencia = (m['referencia'] ?? '').toString();
                final fecha = (m['fecha'] ?? '').toString();
                final codigo = (m['codigo'] ?? '').toString();
                final monto = (m['monto'] is num)
                    ? (m['monto'] as num).toDouble()
                    : double.tryParse(m['monto'].toString()) ?? 0.0;


                // Unificar: solo mostrar COMPRA y RECARGA
                String tituloBase;
                if (tipo == 'recarga') {
                  tituloBase = 'RECARGA';
                } else {
                  tituloBase = 'COMPRA';
                }

                // Forzar items vacío para todos los gastos si no existe, para mostrar comprobante detallado
                final datosAdicionales = Map<String, dynamic>.from(m);
                if (tipo == 'gasto' && datosAdicionales['items'] == null) {
                  datosAdicionales['items'] = <dynamic>[];
                }
                // Solo mostrar COMPRA y RECARGA en la lista
                if (tituloBase == 'COMPRA' || tituloBase == 'RECARGA') {
                  return ListTile(
                    leading: Icon(
                      tituloBase == 'RECARGA' ? Icons.add_circle : Icons.payment,
                      color: tituloBase == 'RECARGA' ? Colors.green : Colors.blue,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$tituloBase: S/. ${monto.toStringAsFixed(2)}'),
                        // Mostrar solo si hay un descuento real de la wallet
                        if (tituloBase == 'COMPRA')
                          (() {
                            final wallet = m['wallet'] is num ? (m['wallet'] as num).toDouble() : null;
                            if (wallet != null && wallet > 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF0D6EFD)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Descontado de wallet: -S/. ${wallet.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF0D6EFD)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          })(),
                      ],
                    ),
                    subtitle: Text(
                      '$metodo | $fecha\nRef: $referencia',
                    ),
                    trailing: Text(
                      codigo,
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    onTap: () {
                      final simpleMovimiento = simple.Movimiento(
                        titulo: tituloBase,
                        monto: monto,
                        tipo: tipo,
                        fecha: fecha,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleMovimientoPage(
                            movimiento: simpleMovimiento,
                            datosAdicionales: datosAdicionales,
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
    );
  }
}
