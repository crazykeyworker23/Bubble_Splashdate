import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/globals.dart';

class SessionManager {
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    // Ajusta la clave según cómo guardes el id en SharedPreferences
    return prefs.getInt('user_id');
  }

  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_id_token') ?? prefs.getString('use_txt_fcm');
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_email') ?? prefs.getString('savedEmail');
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    // Prioridad: google_name > use_txt_fullname > savedEmail
    final name = prefs.getString('google_name');
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final altName = prefs.getString('use_txt_fullname');
    if (altName != null && altName.trim().isNotEmpty) return altName.trim();
    final email = prefs.getString('savedEmail');
    if (email != null && email.trim().isNotEmpty) return email.trim();
    return null;
  }

  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('google_photo');
  }

  static Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    bool remember = prefs.getBool('rememberMe') ?? false;

    // Trigger Firebase and Google Sign-Out concurrently in background.
    // We set a short timeout of 500ms so network delay won't block the UI logout.
    try {
      await Future.wait([
        FirebaseAuth.instance.signOut().timeout(const Duration(milliseconds: 500)).catchError((_) => null),
        GoogleSignIn().signOut().timeout(const Duration(milliseconds: 500)).catchError((_) => null),
      ]);
    } catch (_) {}

    // Limpia la sesión en paralelo (optimización de llamadas a canal nativo)
    await Future.wait([
      prefs.setBool('isLoggedIn', false),
      prefs.remove('fcm_token'),
      prefs.remove('access_token'),
      prefs.remove('refresh_token'),
      prefs.remove('google_id_token'),
      prefs.remove('google_name'),
      prefs.remove('google_email'),
      prefs.remove('google_photo'),
      prefs.remove('google_id'),
      if (!remember) prefs.remove('savedEmail'),
    ]);

    // Redirigir al login usando la llave global
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
