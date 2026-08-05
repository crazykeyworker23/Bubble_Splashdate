import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/services/app_http.dart' as http;

/// Un descuento ya obtenido y todavía sin usar.
///
/// El canje se consume en el momento de obtenerlo —gasta puntos o quema un
/// código— pero solo se aplica al hacer el pedido. Entre esos dos momentos
/// vive aquí, y el cliente tiene que poder encontrarlo.
class CanjePendiente {
  final int id;
  final String titulo;
  final double porcentaje;
  final String tamanoPermitido;

  const CanjePendiente({
    required this.id,
    required this.titulo,
    required this.porcentaje,
    required this.tamanoPermitido,
  });

  /// Descuento expresado como fracción, que es lo que espera el menú.
  double get fraccion => porcentaje / 100;

  factory CanjePendiente.fromJson(Map<String, dynamic> json) {
    final oferta = (json['oferta'] is Map<String, dynamic>)
        ? json['oferta'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return CanjePendiente(
      id: int.tryParse((json['ofc_int_id'] ?? '').toString()) ?? 0,
      titulo: (oferta['off_txt_title'] ?? 'Tu descuento').toString(),
      porcentaje:
          double.tryParse((oferta['off_de_discountpercent'] ?? '0').toString()) ??
              0,
      tamanoPermitido: (oferta['off_txt_allowed_size'] ?? '').toString(),
    );
  }
}

/// Acceso a los canjes del cliente.
///
/// Vive en su propio servicio para que la pantalla que muestra el CONTADOR y
/// la que muestra la LISTA lean exactamente lo mismo. En este proyecto ya
/// costó caro tener dos copias del mismo algoritmo en dos pantallas: el
/// historial de movimientos duplicaba cada compra.
class CanjesService {
  /// Descuentos obtenidos que aún no se han usado en ningún pedido.
  ///
  /// Devuelve lista vacía ante cualquier fallo: no poder consultarlos no debe
  /// romper la pantalla que los pide.
  static Future<List<CanjePendiente>> pendientes() async {
    try {
      final response = await http.get(
        BackendConfig.api('bubblesplash/canjes/'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer __placeholder__',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Canjes: el servidor respondió ${response.statusCode}');
        return const [];
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> lista = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List)
              ? decoded['results'] as List<dynamic>
              : const [];

      return lista
          .whereType<Map<String, dynamic>>()
          .where(
            (c) =>
                (c['ofc_txt_statususe'] ?? '').toString().toUpperCase() ==
                'PENDIENTE',
          )
          .map(CanjePendiente.fromJson)
          .where((c) => c.id > 0)
          .toList();
    } catch (e) {
      debugPrint('Canjes: excepción al consultarlos -> $e');
      return const [];
    }
  }
}
