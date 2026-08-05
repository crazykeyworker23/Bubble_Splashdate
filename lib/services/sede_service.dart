import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sede (local) de Splash Bubble: Iquitos, Jaén, Tarapoto…
///
/// Además de identificar el local, lleva los datos que se imprimen en la
/// boleta: dirección, teléfono, RUC y razón social. Son distintos en cada
/// sede, así que el comprobante los toma de aquí y nunca de constantes
/// escritas en la pantalla.
class Sede {
  final int id;
  final String code;
  final String name;
  final String city;
  final String address;
  final String phone;
  final String ruc;
  final String businessName;

  const Sede({
    required this.id,
    required this.code,
    required this.name,
    this.city = '',
    this.address = '',
    this.phone = '',
    this.ruc = '',
    this.businessName = '',
  });

  factory Sede.fromJson(Map<String, dynamic> json) {
    final rawId = json['sed_int_id'];
    return Sede(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      code: (json['sed_txt_code'] ?? '').toString(),
      name: (json['sed_txt_name'] ?? '').toString(),
      city: (json['sed_txt_city'] ?? '').toString(),
      address: (json['sed_txt_address'] ?? '').toString(),
      phone: (json['sed_txt_phone'] ?? '').toString(),
      ruc: (json['sed_txt_ruc'] ?? '').toString(),
      businessName: (json['sed_txt_business_name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sed_int_id': id,
        'sed_txt_code': code,
        'sed_txt_name': name,
        'sed_txt_city': city,
        'sed_txt_address': address,
        'sed_txt_phone': phone,
        'sed_txt_ruc': ruc,
        'sed_txt_business_name': businessName,
      };

  /// Razón social a imprimir. Cae al nombre de la sede si no está configurada.
  String get razonSocial =>
      businessName.trim().isNotEmpty ? businessName.trim() : 'SPLASH BUBBLE';

  /// Dirección completa del local (dirección + ciudad, sin repetirla).
  String get direccionCompleta {
    final partes = <String>[
      if (address.trim().isNotEmpty) address.trim(),
      if (city.trim().isNotEmpty &&
          !address.toLowerCase().contains(city.trim().toLowerCase()))
        city.trim(),
    ];
    return partes.join(', ');
  }
}

/// Acceso a las sedes y a la sede del usuario.
///
/// La sede determina a qué local llegan los pedidos del cliente y qué
/// catálogo, ofertas y beneficios ve en la app.
class SedeService {
  static const String _cacheKey = 'bubble_sedes_cache';
  static const String _userSedeKey = 'bubble_user_sede';

  /// Último motivo de fallo, para poder mostrarlo en pantalla en vez de un
  /// genérico "revisa tu conexión" que despista al diagnosticar.
  static String? lastError;

  /// Lista de sedes activas.
  ///
  /// Intenta en este orden:
  ///   1. `sedes/publicas/`  -> endpoint abierto, funciona sin sesión (registro).
  ///   2. `sedes/`           -> listado autenticado, por si el backend
  ///                            desplegado aún no tiene el endpoint público.
  ///   3. Caché local        -> para no dejar la pantalla vacía sin conexión.
  static Future<List<Sede>> fetchSedes() async {
    lastError = null;

    final sedes = await _intentarEndpoint(
      'bubblesplash/sedes/publicas/',
      conToken: false,
    );
    if (sedes.isNotEmpty) return sedes;

    // Respaldo autenticado: útil en "Mi perfil", donde sí hay sesión.
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('access_token') ?? '').trim();
    if (token.isNotEmpty) {
      final respaldo = await _intentarEndpoint(
        'bubblesplash/sedes/',
        conToken: true,
      );
      if (respaldo.isNotEmpty) return respaldo;
    }

    final cache = await _cachedSedes();
    if (cache.isNotEmpty) {
      lastError = null;
      return cache;
    }

    return const [];
  }

  static Future<List<Sede>> _intentarEndpoint(
    String path, {
    required bool conToken,
  }) async {
    try {
      final headers = <String, String>{'Accept': 'application/json'};

      if (conToken) {
        final prefs = await SharedPreferences.getInstance();
        final token = (prefs.getString('access_token') ?? '').trim();
        if (token.isEmpty) return const [];
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        BackendConfig.api(path),
        headers: headers,
      );

      if (response.statusCode != 200) {
        lastError = 'El servidor respondió ${response.statusCode} en $path.';
        debugPrint('SedeService: $path -> ${response.statusCode} ${response.body}');
        return const [];
      }

      final decoded = jsonDecode(response.body);

      // `publicas/` devuelve una lista; `sedes/` puede venir paginado.
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['results'] is List)
              ? decoded['results'] as List<dynamic>
              : const [];

      final sedes = items
          .whereType<Map<String, dynamic>>()
          .map(Sede.fromJson)
          .where((s) => s.id > 0 && s.name.isNotEmpty)
          .toList();

      if (sedes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _cacheKey,
          jsonEncode(sedes.map((s) => s.toJson()).toList()),
        );
      } else {
        lastError = 'El servidor no devolvió ninguna sede activa.';
      }

      return sedes;
    } catch (e) {
      lastError = 'No se pudo conectar con el servidor.';
      debugPrint('SedeService: error en $path -> $e');
      return const [];
    }
  }

  static Future<List<Sede>> _cachedSedes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(Sede.fromJson)
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  /// Sede guardada localmente para el usuario en sesión.
  static Future<Sede?> getUserSede() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userSedeKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return Sede.fromJson(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> saveUserSede(Sede? sede) async {
    final prefs = await SharedPreferences.getInstance();
    if (sede == null) {
      await prefs.remove(_userSedeKey);
      return;
    }
    await prefs.setString(_userSedeKey, jsonEncode(sede.toJson()));
  }

  /// Consulta el perfil Bubble del usuario (incluye su sede) y lo cachea.
  ///
  /// Devuelve `null` si no hay sesión o el perfil no está disponible.
  static Future<Map<String, dynamic>?> fetchMyProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('access_token') ?? '').trim();
    if (token.isEmpty) return null;

    try {
      final response = await http.get(
        BackendConfig.api('bubblesplash/me/'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final dynamic sedeJson = decoded['sede'];
      if (sedeJson is Map<String, dynamic>) {
        await saveUserSede(Sede.fromJson(sedeJson));
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Sede con la que se debe emitir un comprobante.
  ///
  /// Prioriza la sede que viene en el pedido o movimiento del backend: es
  /// donde se hizo la venta, y no cambia aunque el cliente se mude de sede
  /// después. Si el registro no la trae (comprobantes antiguos), cae a la sede
  /// del usuario, refrescándola cuando la caché no tiene los datos del
  /// comprobante.
  static Future<Sede?> sedeParaComprobante([
    Map<String, dynamic>? sedeDelBackend,
  ]) async {
    if (sedeDelBackend != null && sedeDelBackend.isNotEmpty) {
      final sede = Sede.fromJson(sedeDelBackend);
      if (sede.id > 0) return sede;
    }

    final cache = await getUserSede();
    if (cache != null && cache.address.trim().isNotEmpty) return cache;

    await fetchMyProfile();
    return await getUserSede() ?? cache;
  }

  /// Asigna/actualiza la sede del usuario en sesión.
  static Future<bool> updateMySede(Sede sede) async {
    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('access_token') ?? '').trim();
    if (token.isEmpty) return false;

    try {
      final response = await http.patch(
        BackendConfig.api('bubblesplash/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'sed_int_id': sede.id}),
      );

      if (response.statusCode == 200) {
        await saveUserSede(sede);
        return true;
      }
    } catch (_) {}

    return false;
  }
}
