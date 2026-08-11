import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bubblesplash/services/app_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/constants/service_code.dart';

/// Registro del token FCM del dispositivo contra el backend.
///
/// El token identifica al TELÉFONO, no a la persona. Por eso:
///   - se registra al iniciar sesión (para que las notificaciones lleguen a
///     quien está usando la app en ese momento),
///   - se vuelve a registrar cuando Firebase lo rota (`onTokenRefresh`), que
///     ocurre solo y sin avisar al usuario,
///   - y se suelta al cerrar sesión, para que el siguiente que entre en el
///     mismo teléfono no herede los avisos del anterior.
///
/// El backend, al recibirlo, lo desvincula de cualquier otra cuenta.
class FcmService {
  static bool _escuchandoRefresh = false;

  /// Obtiene el token FCM del dispositivo y lo envía al backend.
  ///
  /// Se llama después de un login exitoso y al arrancar la app. Es seguro
  /// llamarla varias veces: el backend la trata como idempotente.
  static Future<void> initAndSendTokenIfPossible() async {
    try {
      // En iOS hay que esperar a APNs ANTES de pedir el token.
      //
      // Firebase no puede emitir un token FCM hasta que APNs le haya entregado
      // el suyo, y ese registro tarda un momento tras el arranque. Como
      // `getToken()` devuelve null mientras tanto, en iPhone el token no se
      // registraba nunca y el usuario se quedaba sin notificaciones sin que
      // nada lo indicara. En Android no ocurre: el token está disponible de
      // inmediato.
      if (!await _esperarApnsEnIOS()) {
        print('❌ APNs no entregó token: no se puede registrar FCM en iOS');
        return;
      }

      final String? token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        print('❌ No se obtuvo token FCM del dispositivo');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      await _enviarToken(token);
      _escucharRefresh();
    } catch (e) {
      print('❌ Error general en FcmService.initAndSendTokenIfPossible: $e');
    }
  }

  /// Espera a que APNs entregue su token. Solo aplica a iOS.
  ///
  /// En Android devuelve `true` de inmediato: allí el token de Firebase está
  /// disponible sin depender de ningún servicio del sistema.
  ///
  /// En iOS se consulta varias veces con una pausa breve, porque el registro
  /// en APNs es asíncrono y puede no haber terminado cuando el usuario acaba
  /// de iniciar sesión. En el simulador APNs no existe, así que devolverá
  /// `false` y no se registrará token: es lo esperado, hay que probar en un
  /// dispositivo real.
  static Future<bool> _esperarApnsEnIOS() async {
    if (!Platform.isIOS) return true;

    const int intentos = 6;
    const Duration pausa = Duration(seconds: 1);

    for (var i = 0; i < intentos; i++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return true;
      } catch (e) {
        print('⚠️ Error consultando el token APNs: $e');
      }
      await Future.delayed(pausa);
    }

    return false;
  }

  /// Reenvía el token cada vez que Firebase lo renueva.
  ///
  /// Sin esto, el token guardado en el backend queda obsoleto tras una
  /// reinstalación o una limpieza de datos y el usuario deja de recibir
  /// notificaciones sin que nada lo indique.
  static void _escucharRefresh() {
    if (_escuchandoRefresh) return;
    _escuchandoRefresh = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((nuevoToken) async {
      try {
        if (nuevoToken.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', nuevoToken);
        await _enviarToken(nuevoToken);
      } catch (e) {
        print('❌ Error reenviando el token FCM renovado: $e');
      }
    });
  }

  static Future<void> _enviarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = (prefs.getString('access_token') ?? '').trim();

    if (accessToken.isEmpty) {
      // Sin sesión no hay a quién asociar el token; se guardó localmente y se
      // enviará en cuanto el usuario inicie sesión.
      print('ℹ️ Token FCM guardado localmente: aún no hay sesión');
      return;
    }

    try {
      final response = await http.post(
        BackendConfig.api('auth/fcm/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
          // A qué app pertenece este token.
          //
          // Sin esta cabecera el servidor lo guarda en un campo compartido por
          // todos los servicios, y si la persona usa también Date & Doing con
          // la misma cuenta, la última app en iniciar sesión pisa el token de
          // la otra. Las dos acaban sin recibir notificaciones.
          'X-Service-Code': kServiceCode,
        },
        body: jsonEncode({'use_txt_fcm': token}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Token FCM registrado en el backend');
      } else {
        print(
          '❌ No se pudo registrar el token FCM: '
          '${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error enviando el token FCM al backend: $e');
    }
  }

  /// Suelta el token al cerrar sesión.
  ///
  /// Primero se avisa al backend (todavía hay sesión válida) y después se
  /// borra el token del dispositivo, para que el siguiente inicio de sesión
  /// pida uno nuevo y limpio.
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = (prefs.getString('access_token') ?? '').trim();
      final token = (prefs.getString('fcm_token') ?? '').trim();

      if (accessToken.isNotEmpty) {
        try {
          await http.delete(
            BackendConfig.api('auth/fcm/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
              // También al soltarlo: cerrar sesión aquí no debe dejar sin
              // notificaciones a la otra app de la misma cuenta.
              'X-Service-Code': kServiceCode,
            },
            body: jsonEncode({'use_txt_fcm': token}),
          );
        } catch (e) {
          // Que no se pueda avisar al backend no debe impedir cerrar sesión.
          print('⚠️ No se pudo liberar el token FCM en el backend: $e');
        }
      }

      await prefs.remove('fcm_token');
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      print('⚠️ Error limpiando el token FCM: $e');
    }
  }
}
