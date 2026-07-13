import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/constants/service_code.dart';

class AuthService {
  /// Intenta refrescar el token de acceso usando el refresh token guardado.
  /// Devuelve true si se refrescó correctamente, false si el token de refresco es inválido
  /// (lo que requiere cerrar sesión), y propaga excepciones para errores de red o del servidor.
  static Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Intentar refresco para usuario de Google (si corresponde)
    final googleEmail = prefs.getString('google_email');
    final googleId = prefs.getString('google_id');
    if (googleEmail != null && googleId != null) {
      try {
        debugPrint('🔄 Intentando refresco silencioso con Google para $googleEmail...');
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final oauthCredential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
          final user = userCredential.user;
          if (user != null) {
            final firebaseIdToken = await user.getIdToken(true);
            
            final url = BackendConfig.api('auth/firebase/');
            final res = await http.post(
              url,
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'application/json',
                'X-Service-Code': kServiceCode,
                'X-ServiceCode': kServiceCode,
              },
              body: jsonEncode({'firebase_id_token': firebaseIdToken}),
            ).timeout(const Duration(seconds: 12));

            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              final dynamic tokenContainer = (data['data'] is Map<String, dynamic>) ? data['data'] : data;
              final dynamic accessRaw = tokenContainer['access'] ?? tokenContainer['access_token'] ?? tokenContainer['token'];
              final dynamic refreshRaw = tokenContainer['refresh'] ?? tokenContainer['refresh_token'];
              
              final String accessToken = accessRaw?.toString().trim() ?? '';
              final String refreshTokenVal = refreshRaw?.toString().trim() ?? '';
              
              if (accessToken.isNotEmpty) {
                await prefs.setString('access_token', accessToken);
                if (refreshTokenVal.isNotEmpty) {
                  await prefs.setString('refresh_token', refreshTokenVal);
                }
                debugPrint('🔄 Token de Google refrescado silenciosamente con éxito!');
                return true;
              }
            } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
              // Reclusión/Expiración explícita de credenciales de Google en el backend
              debugPrint('⚠️ Servidor rechazó las credenciales de Google (${res.statusCode}): ${res.body}');
              return false;
            } else {
              // Error temporal del servidor (500, etc.), lanzar excepción para no desloguear
              throw Exception('Error temporal del servidor al refrescar Google (${res.statusCode})');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error al refrescar silenciosamente con Google: $e');
        if (e is SocketException || e is TimeoutException) {
          rethrow; // Propagar errores de red
        }
      }
    }

    // 2. Refresco estándar (JWT)
    final refreshTokenVal = prefs.getString('refresh_token');
    if (refreshTokenVal == null || refreshTokenVal.isEmpty) return false;

    final url = BackendConfig.api('auth/token/refresh/');
    
    // Hacemos el post y controlamos timeout de red
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh': refreshTokenVal}),
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['access'] != null) {
        await prefs.setString('access_token', data['access']);
        debugPrint('🔄 Token JWT de acceso refrescado con éxito!');
        return true;
      }
    } else if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
      // El refresh token ha sido explícitamente rechazado o ha expirado.
      debugPrint('⚠️ Refresh token rechazado o expirado (${response.statusCode}): ${response.body}');
      return false;
    } else {
      // Error temporal del servidor, lanzar excepción para no desloguear al usuario
      throw Exception('Error temporal del servidor al refrescar token (${response.statusCode})');
    }

    return false;
  }
}

