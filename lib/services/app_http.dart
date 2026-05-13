import 'dart:convert';
import 'package:http/http.dart' as http_pkg;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'session_manager.dart';

// Exportamos las clases esenciales para no romper el código existente
export 'package:http/http.dart' show Response, MultipartRequest, Request, StreamedResponse, ByteStream, MultipartFile;

class AppHttp {
  /// Verifica si el token existe y está por expirar (faltan 60 segundos o menos).
  /// Si es así, intenta refrescarlo proactivamente.
  static Future<void> _ensureValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      if (_isTokenExpiring(token)) {
        bool refreshed = await AuthService.refreshToken();
        if (!refreshed) {
          // Si el refresh falló, forzamos logout inmediatamente
          await SessionManager.forceLogout();
        }
      }
    }
  }

  /// Decodifica el JWT y verifica si su fecha de expiración está cerca
  static bool _isTokenExpiring(String token, {int thresholdSeconds = 60}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(resp);

      final exp = decoded['exp'];
      if (exp == null) return false;

      final expTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      return expTime.difference(now).inSeconds <= thresholdSeconds;
    } catch (e) {
      return false;
    }
  }

  /// Intercepta respuestas 401 para intentar refrescar el token de manera reactiva.
  static Future<http_pkg.Response> _handleResponse(
    http_pkg.Response response,
    Future<http_pkg.Response> Function() retryRequest,
  ) async {
    if (response.statusCode == 401) {
      bool refreshed = await AuthService.refreshToken();
      if (refreshed) {
        // Reintentamos la petición original
        return await retryRequest();
      } else {
        // Si no se puede refrescar, sesión vencida -> Auto Logout
        await SessionManager.forceLogout();
      }
    }
    return response;
  }

  /// Actualiza los encabezados con el token más reciente, si existe
  static Future<Map<String, String>?> _updateHeaders(Map<String, String>? headers) async {
    if (headers == null || !headers.containsKey('Authorization')) return headers;

    final prefs = await SharedPreferences.getInstance();
    final newToken = prefs.getString('access_token');
    if (newToken != null && newToken.isNotEmpty) {
      final updatedHeaders = Map<String, String>.from(headers);
      updatedHeaders['Authorization'] = 'Bearer $newToken';
      return updatedHeaders;
    }
    return headers;
  }

  // --- MÉTODOS PÚBLICOS ---

  static Future<http_pkg.Response> get(Uri url, {Map<String, String>? headers}) async {
    await _ensureValidToken();
    final currentHeaders = await _updateHeaders(headers);
    var response = await http_pkg.get(url, headers: currentHeaders);

    return _handleResponse(response, () async {
      final updatedHeaders = await _updateHeaders(currentHeaders);
      return await http_pkg.get(url, headers: updatedHeaders);
    });
  }

  static Future<http_pkg.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    await _ensureValidToken();
    final currentHeaders = await _updateHeaders(headers);
    var response = await http_pkg.post(url, headers: currentHeaders, body: body, encoding: encoding);

    return _handleResponse(response, () async {
      final updatedHeaders = await _updateHeaders(currentHeaders);
      return await http_pkg.post(url, headers: updatedHeaders, body: body, encoding: encoding);
    });
  }

  static Future<http_pkg.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    await _ensureValidToken();
    final currentHeaders = await _updateHeaders(headers);
    var response = await http_pkg.put(url, headers: currentHeaders, body: body, encoding: encoding);

    return _handleResponse(response, () async {
      final updatedHeaders = await _updateHeaders(currentHeaders);
      return await http_pkg.put(url, headers: updatedHeaders, body: body, encoding: encoding);
    });
  }

  static Future<http_pkg.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    await _ensureValidToken();
    final currentHeaders = await _updateHeaders(headers);
    var response = await http_pkg.delete(url, headers: currentHeaders, body: body, encoding: encoding);

    return _handleResponse(response, () async {
      final updatedHeaders = await _updateHeaders(currentHeaders);
      return await http_pkg.delete(url, headers: updatedHeaders, body: body, encoding: encoding);
    });
  }

  static Future<http_pkg.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    await _ensureValidToken();
    final currentHeaders = await _updateHeaders(headers);
    var response = await http_pkg.patch(url, headers: currentHeaders, body: body, encoding: encoding);

    return _handleResponse(response, () async {
      final updatedHeaders = await _updateHeaders(currentHeaders);
      return await http_pkg.patch(url, headers: updatedHeaders, body: body, encoding: encoding);
    });
  }
}

// Exportamos las funciones a nivel de módulo para mantener compatibilidad
// con el alias "as http" en otros archivos.

Future<http_pkg.Response> get(Uri url, {Map<String, String>? headers}) => AppHttp.get(url, headers: headers);
Future<http_pkg.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => AppHttp.post(url, headers: headers, body: body, encoding: encoding);
Future<http_pkg.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => AppHttp.put(url, headers: headers, body: body, encoding: encoding);
Future<http_pkg.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => AppHttp.delete(url, headers: headers, body: body, encoding: encoding);
Future<http_pkg.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => AppHttp.patch(url, headers: headers, body: body, encoding: encoding);
