import 'package:shared_preferences/shared_preferences.dart';
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

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('fcm_token');

    // Limpia completamente la sesión
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('google_id_token');
    await prefs.remove('google_name');
    await prefs.remove('google_email');
    await prefs.remove('google_photo');
    await prefs.remove('google_id');

    if (!remember) {
      await prefs.remove('savedEmail');
    }

    // Redirigir al login usando la llave global
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
