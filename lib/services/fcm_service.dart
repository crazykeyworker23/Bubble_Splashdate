import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/services/auth_service.dart';
import 'package:bubblesplash/constants/backend_config.dart';

class FcmService {
  /// Fuerza la renovación del token FCM del dispositivo
  /// (borra el anterior y pide uno nuevo), lo guarda en
  /// SharedPreferences y, si existe access_token, envía un PATCH
  /// al backend para actualizar `use_txt_fcm`.
  static Future<void> initAndSendTokenIfPossible() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final String? token = await messaging.getToken();

      print('🔑 FCM Token desde FcmService: $token');

      final prefs = await SharedPreferences.getInstance();

      if (token != null && token.isNotEmpty) {
        // Guardar token localmente
        await prefs.setString('fcm_token', token);

        final accessToken = prefs.getString('access_token');
        if (accessToken != null && accessToken.isNotEmpty) {
          try {
            // Obtener el id real del usuario desde /auth/me
            final meUrl = BackendConfig.api('auth/me/');
            http.Response meResponse = await http.get(
              meUrl,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
            );

            if (meResponse.statusCode == 401) {
              print('❌ Sesión expirada al obtener /auth/me (FcmService)');
              return;
            }

            if (meResponse.statusCode == 200) {
              final meData = jsonDecode(meResponse.body);
              final userId = meData['use_int_id'];

              if (userId != null) {
                final patchBody = {'use_txt_fcm': token};
                final url = BackendConfig.api('auth/users/$userId/');

                http.Response response = await http.patch(
                  url,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer ${prefs.getString('access_token')}',
                  },
                  body: jsonEncode(patchBody),
                );

                if (response.statusCode == 200 || response.statusCode == 204) {
                  print(
                    '✅ PATCH FCM enviado correctamente (FcmService): '
                    '${response.statusCode}',
                  );
                } else {
                  print(
                    '❌ PATCH FCM falló (FcmService): '
                    '${response.statusCode} ${response.body}',
                  );
                }
              } else {
                print(
                  '❌ No se pudo obtener el id de usuario para el PATCH FCM (FcmService)',
                );
              }
            } else {
              print(
                '❌ Error al obtener /auth/me (FcmService): '
                '${meResponse.statusCode} ${meResponse.body}',
              );
            }
          } catch (e) {
            print('Error enviando FCM al backend (FcmService): $e');
          }
        } else {
          print('❌ No hay accessToken para enviar PATCH FCM (FcmService)');
        }
      } else {
        print('❌ No se obtuvo token FCM para enviar (FcmService)');
      }
    } catch (e) {
      print('❌ Error general en FcmService.initAndSendTokenIfPossible: $e');
    }
  }
}
