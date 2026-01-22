import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../services/fcm_service.dart';
import '../../constants/service_code.dart';

import '../../widgets/custom_button.dart';
import '../login/register_page.dart';
import 'home_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool rememberMe = false;
  bool _obscurePassword = true;

  bool _loadingGoogle = false;
  bool _loadingEmail = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('savedEmail') ?? '';
    final savedRememberMe = prefs.getBool('rememberMe') ?? false;

    if (savedEmail.isNotEmpty && savedRememberMe) {
      setState(() {
        _emailController.text = savedEmail;
        rememberMe = true;
      });
    }
  }

  Future<void> _saveLoginEmailOnly() async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString('savedEmail', _emailController.text.trim());
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('savedEmail');
      await prefs.setBool('rememberMe', false);
    }

    await prefs.setBool('isLoggedIn', true);
  }

  Future<void> _saveGoogleLogin({
    required String email,
    required String? name,
    required String? photoUrl,
    required String? googleId,
    required String? idToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('google_email', email);
    if (name != null) await prefs.setString('google_name', name);
    if (photoUrl != null) await prefs.setString('google_photo', photoUrl);
    if (googleId != null) await prefs.setString('google_id', googleId);

    if (idToken != null && idToken.isNotEmpty) {
      await prefs.setString('google_id_token', idToken);
    }

    await prefs.setString('savedEmail', email);
    await prefs.setBool('rememberMe', true);
    await prefs.setBool('isLoggedIn', true);
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  void _printLong(String text, {int chunkSize = 500}) {
    var remaining = text;
    while (remaining.isNotEmpty) {
      final size = remaining.length > chunkSize ? chunkSize : remaining.length;
      // ignore: avoid_print
      print(remaining.substring(0, size));
      remaining = remaining.substring(size);
    }
  }

  // === Colores estilo imagen ===
  Color get _brandColor => const Color.fromARGB(255, 255, 255, 255); // morado
  Color get _bgPink => const Color.fromARGB(255, 25, 108, 119); // rosado claro
  Color get _deepPink => const Color.fromARGB(255, 231, 231, 231); // acento

  bool get busy => _loadingEmail || _loadingGoogle;

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(0.45),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: Colors.black54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _brandColor, width: 1.6),
      ),
    );
  }

  Future<Map<String, dynamic>> _loginBackendWithFirebase({
    required String firebaseIdToken,
    required String serviceCode,
  }) async {
    final uri = Uri.parse('https://services.fintbot.pe/api/auth/firebase/');

    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            'X-Service-Code': serviceCode,
            'X-ServiceCode': serviceCode,
          },
          body: jsonEncode({'firebase_id_token': firebaseIdToken}),
        )
        .timeout(const Duration(seconds: 20));

    debugPrint('➡️ STATUS: ${res.statusCode}');
    debugPrint('➡️ BODY: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Backend ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend: ${res.body}');
    }
    return data;
  }

  Future<String> _getFirebaseIdTokenOrThrow(User user) async {
    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception("No se pudo obtener Firebase ID Token");
    }
    _printLong(
      "\n===== Firebase ID Token =====\n$token\n==============================\n",
    );
    return token;
  }

  Future<void> _handleEmailPasswordLogin() async {
    try {
      setState(() => _loadingEmail = true);

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Por favor, completa los campos.');
      }
      if (!_validateEmail(email)) {
        throw Exception('Por favor, ingresa un email válido.');
      }

      final url = Uri.parse('https://services.fintbot.pe/api/auth/login/');
      final body = {'username': email, 'password': password};

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('google_name');
        await prefs.remove('google_email');
        await prefs.remove('google_photo');
        await prefs.remove('google_id');
        await prefs.remove('google_id_token');

        if (data['access'] != null) {
          await prefs.setString('access_token', data['access']);
        }
        if (data['refresh'] != null) {
          await prefs.setString('refresh_token', data['refresh']);
        }

        if (data['user'] != null) {
          if (data['user']['use_txt_fullname'] != null) {
            await prefs.setString('google_name', data['user']['use_txt_fullname']);
            await prefs.setString('use_txt_fullname', data['user']['use_txt_fullname']);
          }
          if (data['user']['use_txt_email'] != null) {
            await prefs.setString('google_email', data['user']['use_txt_email']);
          }
        }

        await _saveLoginEmailOnly();
        await FcmService.initAndSendTokenIfPossible();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        var msg = 'Error: ${res.body}';
        if (res.statusCode == 401) {
          msg = 'Credenciales incorrectas.';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('❌ Error Email/Password: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _loadingGoogle = true);

      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) throw Exception('No se pudo iniciar sesión con Firebase.');

      final firebaseIdToken = await _getFirebaseIdTokenOrThrow(user);
      final backendData = await _loginBackendWithFirebase(
        firebaseIdToken: firebaseIdToken,
        serviceCode: kServiceCode,
      );

      final prefs = await SharedPreferences.getInstance();
      if (backendData['access'] != null) {
        await prefs.setString('access_token', backendData['access']);
      }
      if (backendData['refresh'] != null) {
        await prefs.setString('refresh_token', backendData['refresh']);
      }

      await _saveGoogleLogin(
        email: googleUser.email,
        name: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
        googleId: googleUser.id,
        idToken: googleAuth.idToken,
      );

      await FcmService.initAndSendTokenIfPossible();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      debugPrint('❌ Error Google Sign-In: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Widget _bubble({required double size, required double top, required double left, double opacity = 0.25}) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo rosado
          Container(color: _bgPink),

          // Burbujas / círculos decorativos (como la imagen)
          _bubble(size: 140, top: -40, left: -30, opacity: 0.18),
          _bubble(size: 90, top: 40, left: 260, opacity: 0.22),
          _bubble(size: 30, top: 120, left: 310, opacity: 0.25),
          _bubble(size: 65, top: 170, left: 30, opacity: 0.20),
          _bubble(size: 110, top: 520, left: 250, opacity: 0.18),
          _bubble(size: 55, top: 610, left: 35, opacity: 0.18),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // “Hero” (ilustración). Usamos tu mismo asset para no agregar nuevos.
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/logob.png',
                            width: 92,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Disfruta de BubbleSplash',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color.fromARGB(255, 255, 255, 255),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
 
                      const SizedBox(height: 14),

 
                      const SizedBox(height: 14),

                      AbsorbPointer(
                        absorbing: busy,
                        child: Opacity(
                          opacity: busy ? 0.95 : 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_loadingEmail || _loadingGoogle)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      minHeight: 4,
                                      backgroundColor: Colors.white.withOpacity(0.35),
                                      color: _deepPink,
                                    ),
                                  ),
                                if (_loadingEmail || _loadingGoogle) const SizedBox(height: 14),

                                _fieldLabel('Correo electrónico'),
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.username],
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: _inputDecoration(
                                    hint: 'Ingresa tu correo',
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _fieldLabel('Contraseña'),

                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSubmitted: (_) {
                                    if (!busy) _handleEmailPasswordLogin();
                                  },
                                  decoration: _inputDecoration(
                                    hint: 'Ingresa tu contraseña',
                                    icon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.black54,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Checkbox(
                                      value: rememberMe,
                                      activeColor: _brandColor,
                                      onChanged: (value) => setState(() => rememberMe = value ?? false),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Recordarme',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.88),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                        );
                                      },
                                      child: Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: _brandColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // Tu CustomButton (se mantiene)
                                CustomButton(
                                  text: _loadingEmail ? 'Autenticando...' : 'Login',
                                  onPressed: busy ? null : _handleEmailPasswordLogin,
                                ),

                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.55))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                      child: Text(
                                        'O inicia sesión con',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.55))),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _loadingGoogle ? null : _handleGoogleSignIn,
                                    icon: _loadingGoogle
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Image.asset('assets/google.png', width: 20, height: 20),
                                    label: Text(
                                      _loadingGoogle ? 'Conectando...' : 'Google',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'No tiene una cuenta?',
                              style: TextStyle(fontSize: 13, color: const Color.fromARGB(255, 241, 241, 241)),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: busy
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                                      );
                                    },
                              child: Text(
                                'Crear una cuenta',
                                style: TextStyle(
                                  color: _brandColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
