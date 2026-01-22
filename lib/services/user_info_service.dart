import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';

class UserInfoService {
  /// Obtiene el id del usuario autenticado usando el access token
  static Future<int?> fetchUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) return null;
    final url = BackendConfig.api('auth/me/');

    http.Response response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    // Si el token expiró (401), intentamos refrescar y reintentar una vez
    if (response.statusCode == 401 && await AuthService.refreshToken()) {
      final newToken = prefs.getString('access_token');
      if (newToken != null && newToken.isNotEmpty) {
        response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $newToken',
          },
        );
      }
    }

    if (response.statusCode == 401) {
      return null;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['use_int_id'];
    }
    return null;
  }
}
