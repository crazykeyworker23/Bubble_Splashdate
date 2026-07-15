import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_http.dart' as http;
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/models/category.dart';

class MenuPrefetcher {
  static const String _categoriesCacheKey = 'menu_categories_cache';
  static const String _categoriesCacheTimeKey = 'menu_categories_cache_time';
  static const int _cacheValidityDurationMs = 15 * 60 * 1000; // 15 minutos

  /// Almacén en memoria para cargar el menú de forma instantánea al abrir la vista.
  static List<Category> inMemoryCategories = [];

  /// Inicia la precarga silenciosa del menú de productos en segundo plano.
  static Future<void> prefetchMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String token = (prefs.getString('access_token') ?? '').trim();

      if (!isLoggedIn || token.isEmpty) {
        debugPrint('ℹ️ [MenuPrefetcher] Usuario no autenticado. Omitiendo precarga de productos.');
        return;
      }

      // 1. Si ya tenemos caché en SharedPreferences, cargarla en memoria inmediatamente
      // para que esté lista antes de que el usuario pulse "Menú"
      final String? cached = prefs.getString(_categoriesCacheKey);
      final int cacheTime = prefs.getInt(_categoriesCacheTimeKey) ?? 0;
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int cacheAge = now - cacheTime;

      if (cached != null && cached.trim().isNotEmpty) {
        try {
          final categories = await compute(_parseCategoriesIsolate, cached);
          inMemoryCategories = categories;
          debugPrint('⚡ [MenuPrefetcher] Menú cargado a memoria desde caché local (${categories.length} categorías).');
        } catch (e) {
          debugPrint('⚠️ [MenuPrefetcher] Error al decodificar caché inicial: $e');
        }
      }

      // 2. Si la caché de SharedPreferences es válida (menos de 15 minutos), no llamamos a la API
      if (cacheTime > 0 && cacheAge < _cacheValidityDurationMs) {
        debugPrint('⚡ [MenuPrefetcher] Caché de productos válida (${(cacheAge / 1000 / 60).toStringAsFixed(1)} min). Omitiendo petición de red.');
        return;
      }

      debugPrint('🔄 [MenuPrefetcher] Iniciando precarga del menú de productos desde la API...');
      final uri = BackendConfig.api('bubblesplash/categorias/');

      // Intentar obtener el menú con token de autenticación
      http.Response? response;
      try {
        response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (e) {
        debugPrint('⚠️ [MenuPrefetcher] Falló la llamada con token: $e');
      }

      // Fallback anónimo si falló la primera petición
      if (response == null || response.statusCode != 200) {
        debugPrint('🔄 [MenuPrefetcher] Reintentando obtener menú de forma anónima...');
        try {
          response = await http.get(
            uri,
            headers: {'Accept': 'application/json'},
          );
        } catch (e) {
          debugPrint('⚠️ [MenuPrefetcher] Falló la llamada anónima: $e');
        }
      }

      if (response != null && response.statusCode == 200 && response.body.isNotEmpty) {
        await prefs.setString(_categoriesCacheKey, response.body);
        await prefs.setInt(_categoriesCacheTimeKey, now);

        final categories = await compute(_parseCategoriesIsolate, response.body);
        inMemoryCategories = categories;
        debugPrint('✅ [MenuPrefetcher] Menú de productos precargado y guardado en caché de memoria con éxito.');
      } else {
        debugPrint('⚠️ [MenuPrefetcher] No se pudo obtener respuesta válida para precarga.');
      }
    } catch (e) {
      debugPrint('⚠️ [MenuPrefetcher] Error en flujo de precarga: $e');
    }
  }
}

/// Función top-level para procesar en Isolate
List<Category> _parseCategoriesIsolate(String rawJson) {
  final List<dynamic> data = jsonDecode(rawJson) as List<dynamic>;
  return data
      .whereType<Map<String, dynamic>>()
      .map(Category.fromJson)
      .where((c) => c.status.toUpperCase() == 'ACTIVO')
      .where((c) => c.products.isNotEmpty)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}
