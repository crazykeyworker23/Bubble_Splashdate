import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AvatarUploadService {
  /// ENDPOINT de ejemplo para subir avatar.
  /// 🔴 IMPORTANTE: Cambia esta URL por la ruta real de tu backend
  /// que reciba la imagen y devuelva la URL pública.
  static const String avatarUploadEndpoint =
      'https://services.fintbot.pe/REEMPLAZA_CON_ENDPOINT_DE_AVATAR/';

  /// Sube la imagen [file] al backend y devuelve la URL pública del avatar.
  ///
  /// Asume un backend que responde con JSON que contiene la URL en una
  /// propiedad `url` o `avatar_url`. Si tu API usa otra clave o estructura,
  /// ajusta el parseo debajo.
  static Future<String> uploadAvatar(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';

    final uri = Uri.parse(avatarUploadEndpoint);
    final request = http.MultipartRequest('POST', uri);

    if (accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al subir avatar (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      final url = (data['url'] ?? data['avatar_url'])?.toString();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    throw Exception('Respuesta inesperada al subir avatar: ${response.body}');
  }
}
