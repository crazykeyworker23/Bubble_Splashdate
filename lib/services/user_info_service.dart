import 'dart:convert';
import 'package:bubblesplash/services/app_http.dart' as http;
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

    if (response.statusCode == 401) {
      return null;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['use_int_id'];
    }
    return null;
  }

  /// Verifica si el usuario autenticado tiene sucursal asociada (`srv_int_id` nula o 0).
  /// De ser así, le asigna la sucursal por defecto (`srv_int_id: 1`) mediante PATCH.
  static Future<void> ensureUserHasServiceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) return;

      final url = BackendConfig.api('auth/me/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final userId = data['use_int_id'];
        final srvId = data['srv_int_id'];

        // Se guarda quién es. Sin este dato, lo que se cachea en el teléfono no
        // se puede separar por persona: la única forma de que un usuario no
        // viera los datos de otro era borrarlos al cerrar sesión, y entonces
        // el propio dueño los perdía también.
        if (userId != null) {
          await prefs.setInt(
            'user_id',
            userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
          );
        }

        if (userId != null && (srvId == null || srvId == 0)) {
          print('🔗 Usuario $userId no tiene sucursal asociada. Vinculando a sucursal 1...');
          final patchUrl = BackendConfig.api('auth/users/$userId/');
          final patchRes = await http.patch(
            patchUrl,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'srv_int_id': 1}),
          );

          if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
            print('✅ srv_int_id actualizado exitosamente a 1 para el usuario $userId');
          } else {
            print('⚠️ Error al actualizar srv_int_id: ${patchRes.statusCode} ${patchRes.body}');
          }
        } else {
          print('🔗 El usuario $userId ya tiene sucursal asociada: $srvId');
        }
      }
    } catch (e) {
      print('⚠️ Excepción en ensureUserHasServiceId: $e');
    }
  }
}

