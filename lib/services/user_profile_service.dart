import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';

class UserProfileService {
  static Future<bool> updateUserProfileRaw(Map<String, dynamic> patchBody, {required int userId}) async {
    final url = BackendConfig.api('auth/users/$userId/');
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('access_token') ?? '';

    http.Response response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(patchBody),
    );

    // Si el token expiró (401), intentamos refrescar y reintentar una vez
    if (response.statusCode == 401 && await AuthService.refreshToken()) {
      token = prefs.getString('access_token') ?? '';
      if (token.isNotEmpty) {
        response = await http.patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(patchBody),
        );
      }
    }

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      throw Exception('Error al actualizar el perfil: ${response.body}');
    }
  }
}
