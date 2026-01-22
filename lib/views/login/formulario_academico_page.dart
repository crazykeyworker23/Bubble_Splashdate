import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';
import 'guardando_datos_page.dart';
import 'home_page.dart';

class FormularioAcademicoPage extends StatefulWidget {
  const FormularioAcademicoPage({super.key});

  @override
  State<FormularioAcademicoPage> createState() => _FormularioAcademicoPageState();
}

class _FormularioAcademicoPageState extends State<FormularioAcademicoPage> {
  String? gradoSeleccionado;
  String? ocupacionSeleccionada;

  final List<String> grados = [
    "Secundaria",
    "Universidad",
    "Técnico",
    "Bachillerato",
  ];

  final Map<String, List<String>> ocupacionesPorGrado = {
    "Secundaria": ["Estudiante", "Otro"],
    "Universidad": ["Estudiante universitario", "Ingeniero", "Otro"],
    "Técnico": ["Estudiante técnico", "Profesional tecnológico", "Otro"],
    "Bachillerato": ["Educador o profesor", "Ingeniero", "Otro"],
  };

  List<String> ocupacionesFiltradas = [];

  void _actualizarOcupaciones(String grado) {
    setState(() {
      gradoSeleccionado = grado;
      ocupacionSeleccionada = null;
      ocupacionesFiltradas = ocupacionesPorGrado[grado] ?? [];
    });
  }

  Future<void> _guardarDatos() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GuardandoDatosPage()),
    );

    await Future.delayed(const Duration(seconds: 3));

if (mounted) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: "Registro exitoso",
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, _, __) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1B6F81),
                size: 75,
              ),
              const SizedBox(height: 18),
              Text(
                "¡Registro Exitoso!",
                style: GoogleFonts.paytoneOne(
                  fontSize: 22,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tus datos se guardaron correctamente.",
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6F81),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    "Continuar",
                    style: GoogleFonts.paytoneOne(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none, // 🔹 Elimina subrayado
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          "Regístrate",
          style: GoogleFonts.paytoneOne(
            fontSize: 21,
            color: const Color(0xFF045378),
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Encabezado principal
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.school_rounded, size: 60, color: Color(0xFF1B6F81)),
                      const SizedBox(height: 10),
                      Text(
                        "Información Académica",
                        style: GoogleFonts.paytoneOne(
                          fontSize: 19,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Completa los campos para continuar con tu registro",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // 🔹 Grado Académico
                Text("Grado Académico",
                    style: GoogleFonts.paytoneOne(
                        fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: gradoSeleccionado,
                    hint: const Text("Seleccione su grado"),
                    items: grados
                        .map((grado) => DropdownMenuItem(
                              value: grado,
                              child: Text(grado),
                            ))
                        .toList(),
                    onChanged: (value) => _actualizarOcupaciones(value!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Seleccione el nivel de grado máximo alcanzado.",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),

                const SizedBox(height: 30),

                // 🔹 Ocupación
                Text("Ocupación",
                    style: GoogleFonts.paytoneOne(
                        fontSize: 15, color: Colors.black87)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: ocupacionSeleccionada,
                    hint: const Text("Seleccione su ocupación"),
                    items: ocupacionesFiltradas
                        .map((ocupacion) => DropdownMenuItem(
                              value: ocupacion,
                              child: Text(ocupacion),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => ocupacionSeleccionada = value),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Seleccione su ocupación actual.",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),

                const SizedBox(height: 45),

                // 🔹 Botón de envío
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: gradoSeleccionado != null &&
                              ocupacionSeleccionada != null
                          ? _guardarDatos
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B6F81),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      label: Text(
                        "Enviar",
                        style: GoogleFonts.paytoneOne(
                          fontSize: 17,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),
                Center(
                  child: Text(
                    "Paso final antes del registro completo",
                    style: GoogleFonts.openSans(
                      fontSize: 13,
                      color: Colors.black45,
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
}
