import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/constants/backend_config.dart';

class AuthService {
  /// Intenta refrescar el token de acceso usando el refresh token guardado.
  /// Devuelve true si se refrescó correctamente, false si no.
  static Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final url = BackendConfig.api('auth/token/refresh/');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access'] != null) {
        await prefs.setString('access_token', data['access']);
        return true;
      }
    }
    return false;
  }
}
