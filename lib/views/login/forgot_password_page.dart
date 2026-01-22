import 'package:flutter/material.dart';

// 🔹 Página final — Restablecer contraseña
class NuevaContrasenaPage extends StatefulWidget {
  const NuevaContrasenaPage({super.key});

  @override
  State<NuevaContrasenaPage> createState() => _NuevaContrasenaPageState();
}

class _NuevaContrasenaPageState extends State<NuevaContrasenaPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static const Color _primaryColor = Color(0xFF1B6F81);

  // Estados de validación
  bool _tieneMayuscula = false;
  bool _tieneNumero = false;
  bool _tieneEspecial = false;
  bool _tieneLongitud = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      _validarEnTiempoReal();
      setState(() {}); // Para actualizar la barra de progreso
    });
  }

  void _validarEnTiempoReal() {
    final pass = _passwordController.text;

    setState(() {
      _tieneMayuscula = RegExp(r'[A-Z]').hasMatch(pass);
      _tieneNumero = RegExp(r'\d').hasMatch(pass);
      _tieneEspecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(pass);
      _tieneLongitud = pass.length >= 8;
    });
  }

  double _calcularNivelContrasena() {
    int puntos = 0;
    if (_tieneLongitud) puntos++;
    if (_tieneMayuscula) puntos++;
    if (_tieneNumero) puntos++;
    if (_tieneEspecial) puntos++;
    return puntos / 4;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        centerTitle: true,
        title: const Text(
          "Restablecer Contraseña",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              const Icon(Icons.lock_reset_rounded,
                  color: _primaryColor, size: 80),
              const SizedBox(height: 15),
              const Text(
                "Ingrese su nueva contraseña para continuar",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 35),

              // Campo contraseña
              _buildLabel("Nueva Contraseña"),
              _buildPasswordField(
                controller: _passwordController,
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),

              const SizedBox(height: 8),

              // Barra de progreso para fortaleza
              LinearProgressIndicator(
                value: _calcularNivelContrasena(),
                minHeight: 5,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _calcularNivelContrasena() <= 0.25
                      ? Colors.red
                      : _calcularNivelContrasena() <= 0.5
                          ? Colors.orange
                          : _calcularNivelContrasena() <= 0.75
                              ? Colors.yellow[700]!
                              : Colors.green,
                ),
              ),

              const SizedBox(height: 12),

              // Indicadores de validación
              _buildLiveHints(),

              const SizedBox(height: 25),
              _buildLabel("Confirmar Contraseña"),
              _buildPasswordField(
                controller: _confirmController,
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),

              const SizedBox(height: 40),

              // Botón principal
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _validarContrasena,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    shadowColor: Colors.black26,
                  ),
                  child: const Text(
                    "Restablecer Contraseña",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
      );

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey.shade700,
          ),
          onPressed: onToggle,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildLiveHints() {
    Widget buildHint(String text, bool ok) {
      return Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel,
              color: ok ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: ok ? Colors.green : Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildHint("Mínimo 8 caracteres", _tieneLongitud),
        buildHint("Una letra mayúscula", _tieneMayuscula),
        buildHint("Un número", _tieneNumero),
        buildHint("Un carácter especial (!, _, *, ...)", _tieneEspecial),
      ],
    );
  }

void _validarContrasena() {
  final pass = _passwordController.text.trim();
  final confirm = _confirmController.text.trim();

  if (pass.isEmpty || confirm.isEmpty) {
    _showMessage("Complete todos los campos.");
    return;
  }

  if (pass != confirm) {
    _showMessage("Las contraseñas no coinciden.");
    return;
  }

  if (!_tieneMayuscula ||
      !_tieneNumero ||
      !_tieneEspecial ||
      !_tieneLongitud) {
    _showMessage("La contraseña no cumple con los requisitos.");
    return;
  }

  _showMessage("✅ Contraseña restablecida correctamente.", onOk: () {
    Navigator.pop(context); // Cierra esta pantalla solo cuando el usuario cierre el popup
  });
}

void _showMessage(String msg, {VoidCallback? onOk}) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.info_outline, size: 40, color: Color(0xFF1B6F81)),
        content: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1B6F81),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (onOk != null) {
                  onOk();
                }
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        contentPadding:
            const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 12),
      );
    },
  );
}


}





// 🔹 Pantalla principal — Olvidé mi contraseña
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  bool _codeSent = false;
  bool _isValidating = false;

  final TextEditingController _emailController =
      TextEditingController(text: 'usuario@correo.com');
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());

  static const Color _buttonColor = Color(0xFF1B6F81);
  static const Color _validateButtonColor = Color(0xFF0E5C13);

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildCodeBox(int index) => Container(
        width: 48,
        height: 55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400, width: 1.3),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
              blurRadius: 4,
            )
          ],
        ),
        child: TextField(
          controller: _codeControllers[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              FocusScope.of(context).nextFocus();
            }
          },
        ),
      );

  Future<void> _validarCodigo() async {
    final enteredCode = _codeControllers.map((c) => c.text).join().trim();

    if (enteredCode.length != 6) {
      _showMessage('Por favor ingrese los 6 dígitos.');
      return;
    }

    setState(() => _isValidating = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isValidating = false);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NuevaContrasenaPage(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 2,
            shadowColor: Colors.black12,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Olvidé mi Contraseña",
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
          ),
          body: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28.0, vertical: 25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.email_outlined, size: 80, color: _buttonColor),
                const SizedBox(height: 15),
                const Text(
                  "Generar código de recuperación",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Ingrese el correo afiliado a su cuenta para recibir el código de verificación.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Correo Electrónico",
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 15),
                    hintText: "Ingrese su correo",
                    hintStyle: const TextStyle(color: Colors.black45),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.shade600, width: 1),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: _buttonColor, width: 1.5),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _codeSent = true);
                      _showMessage(
                          'Código de recuperación enviado. Revisa tu correo.');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _buttonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                    child: Text(
                      _codeSent ? "Reenviar Código" : "Enviar Código",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 25),
                  Text(
                    "Código enviado al correo ${_emailController.text}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Ingrese el código de seguridad:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _buildCodeBox),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _validarCodigo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _validateButtonColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        "Validar Código",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 🔹 Modal de carga limpio y elegante
        if (_isValidating)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 35, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 65,
                      height: 65,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: Color(0xFF1B6F81),
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Validando código...",
                      style: TextStyle(
                        color: Color(0xFF1B6F81),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Por favor, espere unos segundos",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

 
