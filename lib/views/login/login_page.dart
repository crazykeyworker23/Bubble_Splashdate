import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

import '../../constants/api_constants.dart';
import 'package:http/http.dart' as http;

import '../../services/fcm_service.dart';
import '../../constants/service_code.dart';
import '../../services/user_info_service.dart';

import '../../widgets/custom_button.dart';
import '../login/register_page.dart';
import 'home_page.dart';
import 'forgot_password_page.dart';
import 'package:bubblesplash/services/notificaciones_store.dart';

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
  bool _loadingApple = false;
  bool _loadingGuest = false;

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

    await Future.wait([
      if (rememberMe) ...[
        prefs.setString('savedEmail', _emailController.text.trim()),
        prefs.setBool('rememberMe', true),
      ] else ...[
        prefs.remove('savedEmail'),
        prefs.setBool('rememberMe', false),
      ],
      prefs.setBool('isLoggedIn', true),
      // Se descarta el historial de quien usara antes este teléfono.
      NotificacionesStore.limpiar(),
      prefs.setBool('isGuest', false),
    ]);
  }

  Future<void> _saveGoogleLogin({
    required String email,
    required String? name,
    required String? photoUrl,
    required String? googleId,
    required String? idToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.setString('google_email', email),
      if (name != null) prefs.setString('google_name', name),
      if (photoUrl != null) prefs.setString('google_photo', photoUrl),
      if (googleId != null) prefs.setString('google_id', googleId),
      if (idToken != null && idToken.isNotEmpty) prefs.setString('google_id_token', idToken),
      prefs.setString('savedEmail', email),
      prefs.setBool('rememberMe', true),
      prefs.setBool('isLoggedIn', true),
      // Se descarta el historial de quien usara antes este teléfono.
      NotificacionesStore.limpiar(),
      prefs.setBool('isGuest', false),
    ]);
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

  bool get busy => _loadingEmail || _loadingGoogle || _loadingApple || _loadingGuest;

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
    final uri = Uri.parse(ApiConstants.baseUrl + '/auth/firebase/');

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

      final url = Uri.parse(ApiConstants.baseUrl + '/auth/login/');
      final body = {'username': email, 'password': password};

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Respuesta inválida del backend de login.');
        }

        final prefs = await SharedPreferences.getInstance();

        // Permite que el backend envíe los tokens tanto en la raíz
        // como dentro de una clave "data", y con distintos nombres.
        final dynamic tokenContainer =
            (decoded['data'] is Map<String, dynamic>) ? decoded['data'] : decoded;

        final dynamic accessRaw = tokenContainer['access'] ??
            tokenContainer['access_token'] ??
            tokenContainer['token'];
        final dynamic refreshRaw =
            tokenContainer['refresh'] ?? tokenContainer['refresh_token'];

        final String accessToken = accessRaw?.toString().trim() ?? '';
        final String refreshToken = refreshRaw?.toString().trim() ?? '';

        if (accessToken.isEmpty) {
          throw Exception('No se recibió access_token desde el backend de login.');
        }

        // Datos de usuario: pueden venir en tokenContainer['user'] o en decoded['user'].
        final dynamic userData =
            (tokenContainer['user'] is Map<String, dynamic>)
                ? tokenContainer['user']
                : decoded['user'];

        String? fullName;
        String? emailUser;
        if (userData is Map<String, dynamic>) {
          fullName = userData['use_txt_fullname']?.toString();
          emailUser = userData['use_txt_email']?.toString();
        }

        // Guardar todos los datos y limpiar estados de Google en paralelo
        await Future.wait([
          prefs.remove('google_name'),
          prefs.remove('google_email'),
          prefs.remove('google_photo'),
          prefs.remove('google_id'),
          prefs.remove('google_id_token'),
          prefs.setString('access_token', accessToken),
          if (refreshToken.isNotEmpty) prefs.setString('refresh_token', refreshToken),
          if (fullName != null && fullName.trim().isNotEmpty) ...[
            prefs.setString('google_name', fullName),
            prefs.setString('use_txt_fullname', fullName),
          ],
          if (emailUser != null && emailUser.trim().isNotEmpty)
            prefs.setString('google_email', emailUser),
        ]);

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
        _showErrorDialog(title: 'Error de ingreso', message: msg);
      }
    } catch (e) {
      debugPrint('❌ Error Email/Password: $e');
      if (!mounted) return;
      _handleLoginError(e);
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  void _handleLoginError(dynamic e) {
    final errStr = e.toString().toLowerCase();
    final isNetwork = errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('clientexception') ||
        errStr.contains('handshake') ||
        errStr.contains('network') ||
        errStr.contains('connection') ||
        errStr.contains('network_error') ||
        errStr.contains('apiexception: 7');

    final title = isNetwork ? 'Error de Conexión' : 'Ocurrió un inconveniente';
    final message = isNetwork
        ? 'No se pudo conectar con el servidor o Google. Comprueba tu señal de Internet e intenta de nuevo.'
        : 'No se pudo completar el inicio de sesión. Por favor, comprueba tus datos e intenta de nuevo.';

    _showErrorDialog(title: title, message: message);
  }

  void _showErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF062B35),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: Color(0xFF1B6F81),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _loadingGoogle = true);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(const Duration(seconds: 20));
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication.timeout(const Duration(seconds: 15));

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

      final dynamic tokenContainer =
          (backendData['data'] is Map<String, dynamic>) ? backendData['data'] : backendData;

      final dynamic accessRaw = tokenContainer['access'] ?? tokenContainer['access_token'] ?? tokenContainer['token'];
      final dynamic refreshRaw = tokenContainer['refresh'] ?? tokenContainer['refresh_token'];

      final String accessToken = accessRaw?.toString().trim() ?? '';
      final String refreshToken = refreshRaw?.toString().trim() ?? '';

      if (accessToken.isEmpty) {
        throw Exception('No se recibió access_token desde el backend para Google.');
      }

      // Guardar todos los tokens y credenciales de Google en paralelo
      await Future.wait([
        prefs.setString('access_token', accessToken),
        if (refreshToken.isNotEmpty) prefs.setString('refresh_token', refreshToken),
        _saveGoogleLogin(
          email: googleUser.email,
          name: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
          googleId: googleUser.id,
          idToken: googleAuth.idToken,
        ),
      ]);

      // Asegurar que el usuario de Google tenga sucursal asociada
      await UserInfoService.ensureUserHasServiceId();

      await FcmService.initAndSendTokenIfPossible();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      debugPrint('❌ Error Google Sign-In: $e');
      if (!mounted) return;
      _handleLoginError(e);
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() => _loadingApple = true);

      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('fullName');

      final userCredential = await FirebaseAuth.instance.signInWithProvider(appleProvider);
      final user = userCredential.user;
      if (user == null) throw Exception('No se pudo iniciar sesión con Firebase.');

      final firebaseIdToken = await _getFirebaseIdTokenOrThrow(user);
      final backendData = await _loginBackendWithFirebase(
        firebaseIdToken: firebaseIdToken,
        serviceCode: kServiceCode,
      );

      final prefs = await SharedPreferences.getInstance();

      final dynamic tokenContainer =
          (backendData['data'] is Map<String, dynamic>) ? backendData['data'] : backendData;

      final dynamic accessRaw = tokenContainer['access'] ?? tokenContainer['access_token'] ?? tokenContainer['token'];
      final dynamic refreshRaw = tokenContainer['refresh'] ?? tokenContainer['refresh_token'];

      final String accessToken = accessRaw?.toString().trim() ?? '';
      final String refreshToken = refreshRaw?.toString().trim() ?? '';

      if (accessToken.isEmpty) {
        throw Exception('No se recibió access_token desde el backend para Apple.');
      }

      // Guardar todos los tokens y credenciales en paralelo
      String? displayName = user.displayName;
      if (displayName == null || displayName.trim().isEmpty) {
        displayName = user.email?.split('@').first ?? 'Usuario de Apple';
      }

      await Future.wait([
        prefs.setString('access_token', accessToken),
        if (refreshToken.isNotEmpty) prefs.setString('refresh_token', refreshToken),
        prefs.setString('google_email', user.email ?? ''),
        if (displayName != null && displayName.isNotEmpty) prefs.setString('google_name', displayName),
        prefs.setBool('rememberMe', true),
        prefs.setBool('isLoggedIn', true),
      // Se descarta el historial de quien usara antes este teléfono.
      NotificacionesStore.limpiar(),
        prefs.setBool('isGuest', false),
      ]);

      // Asegurar que el usuario de Apple tenga sucursal asociada
      await UserInfoService.ensureUserHasServiceId();

      await FcmService.initAndSendTokenIfPossible();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      debugPrint('❌ Error Apple Sign-In: $e');
      if (e is FirebaseAuthException) {
        debugPrint('   FirebaseAuthException Code: ${e.code}');
        debugPrint('   FirebaseAuthException Message: ${e.message}');
      }
      if (!mounted) return;
      _handleLoginError(e);
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    try {
      setState(() => _loadingGuest = true);

      final prefs = await SharedPreferences.getInstance();

      // Intento silencioso de obtener token demo si hay servidor activo
      try {
        final url = Uri.parse(ApiConstants.baseUrl + '/auth/login/');
        final body = {'username': 'paul@gmail.com', 'password': '12345678'};

        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final dynamic decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic tokenContainer =
                (decoded['data'] is Map<String, dynamic>) ? decoded['data'] : decoded;

            final dynamic accessRaw = tokenContainer['access'] ??
                tokenContainer['access_token'] ??
                tokenContainer['token'];
            final dynamic refreshRaw =
                tokenContainer['refresh'] ?? tokenContainer['refresh_token'];

            final String accessToken = accessRaw?.toString().trim() ?? '';
            final String refreshToken = refreshRaw?.toString().trim() ?? '';

            if (accessToken.isNotEmpty) {
              await prefs.setString('access_token', accessToken);
              if (refreshToken.isNotEmpty) {
                await prefs.setString('refresh_token', refreshToken);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('ℹ️ [GuestLogin] Petición demo omitida o sin conexión: $e');
      }

      // Marcamos como invitado y limpiamos datos de usuario registrado
      await Future.wait([
        prefs.setBool('isLoggedIn', false),
        prefs.setBool('isGuest', true),
        prefs.remove('google_name'),
        prefs.remove('google_email'),
        prefs.remove('google_photo'),
        prefs.remove('google_id'),
      ]);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      debugPrint('❌ Error Guest Sign-in: $e');
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', true);
      await prefs.setBool('isLoggedIn', false);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGuest = false);
      }
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
                        'Disfruta de Splash Bubble',
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
                                if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 48,
                                    child: SignInWithAppleButton(
                                      onPressed: _loadingApple ? () {} : _handleAppleSignIn,
                                      text: 'Iniciar sesión con Apple',
                                      style: SignInWithAppleButtonStyle.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ],
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

                      const SizedBox(height: 18),

                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : _handleGuestSignIn,
                          icon: _loadingGuest
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.explore_outlined, color: Colors.white, size: 22),
                          label: Text(
                            _loadingGuest ? 'Entrando...' : 'Explorar menú como invitado',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 1.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.white.withOpacity(0.12),
                          ),
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
