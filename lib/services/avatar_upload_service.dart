import 'dart:convert';
import 'dart:io';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sube la foto de perfil al backend, que la re-comprime (WebP + resize) y la
/// guarda como archivo. En la base de datos solo queda la URL, de modo que la
/// app nunca tenga que descargar una imagen pesada ni un base64.
class AvatarUploadService {
  /// Endpoint de subida optimizada de imágenes.
  static Uri get _uploadEndpoint =>
      BackendConfig.api('bubblesplash/media/upload/');

  /// Sube [file] y devuelve la URL pública ya optimizada.
  static Future<String> uploadAvatar(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = (prefs.getString('access_token') ?? '').trim();

    if (accessToken.isEmpty) {
      throw Exception('No hay sesión activa para subir la foto de perfil.');
    }

    final request = http.MultipartRequest('POST', _uploadEndpoint)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Accept'] = 'application/json'
      ..fields['folder'] = 'avatars'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      String detalle = 'Error ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] != null) {
          detalle = decoded['detail'].toString();
        }
      } catch (_) {}
      throw Exception('No se pudo subir la foto de perfil: $detalle');
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      final url = (data['url'] ?? data['avatar_url'])?.toString();
      if (url != null && url.isNotEmpty) {
        // El backend puede devolver una ruta relativa (/media/...): la
        // convertimos en absoluta para que CachedNetworkImage la resuelva.
        if (url.startsWith('http://') || url.startsWith('https://')) {
          return url;
        }
        final base =
            BackendConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
        return '$base${url.startsWith('/') ? '' : '/'}$url';
      }
    }

    throw Exception('Respuesta inesperada al subir la foto: ${response.body}');
  }
}
