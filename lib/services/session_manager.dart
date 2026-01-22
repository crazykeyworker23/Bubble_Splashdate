import 'package:shared_preferences/shared_preferences.dart';

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
}
