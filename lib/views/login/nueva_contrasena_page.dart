import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';

class NuevaContrasenaPage extends StatefulWidget {
  const NuevaContrasenaPage({super.key});

  @override
  State<NuevaContrasenaPage> createState() => _NuevaContrasenaPageState();
}

class _NuevaContrasenaPageState extends State<NuevaContrasenaPage>
    with SingleTickerProviderStateMixin {
  bool _obscureContrasena = true;
  bool _obscureConfirmar = true;

  final TextEditingController contrasenaController = TextEditingController();
  final TextEditingController confirmarController = TextEditingController();

  bool tieneLongitud = false;
  bool tieneMayuscula = false;
  bool tieneNumero = false;
  bool tieneEspecial = false;

  double _barraProgreso = 0;

  void validarEnTiempoReal(String value) {
    setState(() {
      tieneLongitud = value.length >= 8;
      tieneMayuscula = RegExp(r'[A-Z]').hasMatch(value);
      tieneNumero = RegExp(r'[0-9]').hasMatch(value);
      tieneEspecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=~`]').hasMatch(value);

      int reglasCumplidas = [
        tieneLongitud,
        tieneMayuscula,
        tieneNumero,
        tieneEspecial,
      ].where((e) => e).length;
      _barraProgreso = reglasCumplidas / 4;
    });
  }

  String? validarContrasenaFinal(String contrasena) {
    if (contrasena.isEmpty) return 'Por favor, ingrese una contraseña.';
    if (!tieneLongitud) return 'Debe tener al menos 8 caracteres.';
    if (!tieneMayuscula) return 'Debe contener al menos una letra mayúscula.';
    if (!tieneNumero) return 'Debe contener al menos un número.';
    if (!tieneEspecial) return 'Debe contener al menos un carácter especial.';
    return null;
  }

  @override
  void dispose() {
    contrasenaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Regístrate",
          style: GoogleFonts.paytoneOne(
            fontSize: 20,
            color: const Color(0xFF045378),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Crea tu nueva contraseña",
                  style: GoogleFonts.paytoneOne(
                    fontSize: 19,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                // Contraseña
                Text(
                  "Contraseña",
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: contrasenaController,
                  obscureText: _obscureContrasena,
                  onChanged: validarEnTiempoReal,
                  decoration: InputDecoration(
                    hintText: 'Ingrese su nueva contraseña',
                    hintStyle:
                        const TextStyle(color: Colors.black38, fontSize: 14),
                    enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.grey.shade400, width: 1.3),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF2D8EFF), width: 1.8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureContrasena
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[700],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureContrasena = !_obscureContrasena;
                        });
                      },
                    ),
                  ),
                ),

                // Barra de progreso
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade300,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _barraProgreso,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _barraProgreso <= 0.25
                            ? Colors.red
                            : _barraProgreso <= 0.5
                                ? Colors.orange
                                : _barraProgreso < 1
                                    ? Colors.amber
                                    : Colors.green,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    reglaItem("Mínimo 8 caracteres", tieneLongitud),
                    reglaItem("Al menos una mayúscula", tieneMayuscula),
                    reglaItem("Al menos un número", tieneNumero),
                    reglaItem("Al menos un carácter especial", tieneEspecial),
                  ],
                ),

                const SizedBox(height: 35),

                // Confirmar contraseña
                Text(
                  "Confirmar contraseña",
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: confirmarController,
                  obscureText: _obscureConfirmar,
                  decoration: InputDecoration(
                    hintText: 'Repita su nueva contraseña',
                    hintStyle:
                        const TextStyle(color: Colors.black38, fontSize: 14),
                    enabledBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.grey.shade400, width: 1.3),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF2D8EFF), width: 1.8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmar
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[700],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmar = !_obscureConfirmar;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 45),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _validarYContinuar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B6F81),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      'Crear',
                      style: GoogleFonts.paytoneOne(
                        fontSize: 15,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validarYContinuar() {
    final contrasena = contrasenaController.text.trim();
    final confirmar = confirmarController.text.trim();
    final error = validarContrasenaFinal(contrasena);

    if (error != null) {
      _mostrarSnack(error, Colors.red);
      return;
    }

    if (contrasena != confirmar) {
      _mostrarSnack('Las contraseñas no coinciden.', Colors.red);
      return;
    }

    // ✅ Todo correcto → Mostrar modal de éxito
    _mostrarModalExitoso();
  }

  void _mostrarSnack(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Widget reglaItem(String texto, bool cumplido) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            cumplido ? Icons.check_circle : Icons.cancel,
            color: cumplido ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: GoogleFonts.inter(
              color: cumplido ? Colors.green : Colors.red,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Modal de registro exitoso
  void _mostrarModalExitoso() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 80),
                const SizedBox(height: 20),
                Text(
                  "¡Registro exitoso!",
                  style: GoogleFonts.paytoneOne(
                    fontSize: 20,
                    color: const Color(0xFF045378),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Tu contraseña ha sido creada correctamente.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Cierra el diálogo
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6F81),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Continuar",
                    style: GoogleFonts.paytoneOne(
                      color: Colors.white,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
