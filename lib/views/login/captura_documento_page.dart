import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

// 🔹 PANTALLA INICIAL: Captura Documento y Selfie
class CapturaDocumentoPage extends StatefulWidget {
  const CapturaDocumentoPage({super.key});

  @override
  State<CapturaDocumentoPage> createState() => _CapturaDocumentoPageState();
}

class _CapturaDocumentoPageState extends State<CapturaDocumentoPage> {
  File? _selfieImage;
  File? _documentImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isSelfie) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        if (isSelfie) {
          _selfieImage = File(photo.path);
        } else {
          _documentImage = File(photo.path);
        }
      });
    }
  }

  void _validar() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ValidandoPage()),
    );

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CapturaRostroPage()),
      );
    }
  }

  Widget _buildCaptureBox(File? imageFile, bool isSelfie) {
    return GestureDetector(
      onTap: () => _pickImage(isSelfie),
      child: Container(
        height: 200,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🔹 Imagen o ícono de cámara
            Positioned.fill(
              child: imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          "Presiona para capturar",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
            ),

            // 🔹 Botón rectangular "Repetir" en la parte superior izquierda
            if (imageFile != null)
              Positioned(
                top: 10,
                left: 10,
                child: ElevatedButton(
                  onPressed: () => _pickImage(isSelfie),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.75),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "Repetir",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool puedeValidar = _selfieImage != null && _documentImage != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Regístrate",
          style: GoogleFonts.paytoneOne(fontSize: 20, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Para continuar, por favor capture las fotos de manera clara de su documento de identidad siguiendo estas indicaciones:",
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "• Coloque el documento en una superficie plana y bien iluminada.\n"
                "• Asegúrese de que el documento esté completamente visible y sin reflejos.\n"
                "• Evite sombras o movimientos al tomar la foto.\n"
                "• Use la cámara trasera para mejor calidad.\n"
                "• Capture ambos lados si es necesario.",
                style:
                    TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
              ),
              const SizedBox(height: 25),

              // 🔹 Cuadros de captura
              _buildCaptureBox(_selfieImage, true),
              _buildCaptureBox(_documentImage, false),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: puedeValidar ? _validar : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003267),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "VALIDAR",
                    style: GoogleFonts.paytoneOne(
                      fontSize: 16,
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
}

// 🔹 Pantalla de carga “Validando...”
class ValidandoPage extends StatelessWidget {
  const ValidandoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF003267)),
            const SizedBox(height: 20),
            Text("Validando...",
                style: GoogleFonts.paytoneOne(
                    fontSize: 20, color: const Color(0xFF003267))),
          ],
        ),
      ),
    );
  }
}

// 🔹 Captura de rostro
class CapturaRostroPage extends StatefulWidget {
  const CapturaRostroPage({super.key});

  @override
  State<CapturaRostroPage> createState() => _CapturaRostroPageState();
}

class _CapturaRostroPageState extends State<CapturaRostroPage> {
  File? _faceImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _capturarRostro() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _faceImage = File(photo.path);
      });
    }
  }

  void _validarRostro() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ValidandoPage()),
    );

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FormularioAcademicoPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F0FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text("Regístrate",
            style: GoogleFonts.paytoneOne(color: Colors.black87, fontSize: 20)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Por favor captura una foto clara de tu rostro:",
              style: GoogleFonts.openSans(fontSize: 14),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: _capturarRostro,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _faceImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_faceImage!, fit: BoxFit.cover),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text("Presiona para capturar el rostro",
                                style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _faceImage != null ? _validarRostro : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5CB3FF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("VALIDAR",
                    style: GoogleFonts.paytoneOne(
                        color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Formulario académico
class FormularioAcademicoPage extends StatefulWidget {
  const FormularioAcademicoPage({super.key});

  @override
  State<FormularioAcademicoPage> createState() =>
      _FormularioAcademicoPageState();
}

class _FormularioAcademicoPageState extends State<FormularioAcademicoPage> {
  String? gradoSeleccionado;
  String? ocupacionSeleccionada;

  final List<String> grados = [
    "Primaria",
    "Secundaria",
    "Técnico",
    "Universitario",
    "Posgrado",
  ];

  final List<String> ocupaciones = [
    "Estudiante",
    "Empleado",
    "Independiente",
    "Desempleado",
    "Otro",
  ];

  void _guardarDatos() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GuardandoDatosPage()),
    );

    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Registro exitoso"),
          content: const Text("Sus datos se guardaron correctamente ✅"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar popup
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text("Aceptar"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Regístrate"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Por favor seleccione su grado académico, ocupación actual.",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 25),

            // Grado Académico
            Text("Grado Académico",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: gradoSeleccionado,
              hint: const Text("Seleccione su grado"),
              items: grados
                  .map((grado) =>
                      DropdownMenuItem(value: grado, child: Text(grado)))
                  .toList(),
              onChanged: (value) => setState(() => gradoSeleccionado = value),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text("Seleccione el nivel de grado máximo alcanzado."),
            const SizedBox(height: 25),

            // Ocupación
            Text("Ocupación",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: ocupacionSeleccionada,
              hint: const Text("Seleccione su ocupación"),
              items: ocupaciones
                  .map((ocupacion) => DropdownMenuItem(
                      value: ocupacion, child: Text(ocupacion)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => ocupacionSeleccionada = value),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text("Seleccione su ocupación actual."),
            const SizedBox(height: 40),

            // Botón
            Center(
              child: ElevatedButton(
                onPressed:
                    gradoSeleccionado != null && ocupacionSeleccionada != null
                        ? _guardarDatos
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Enviar",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Pantalla de carga “Guardando datos...”
class GuardandoDatosPage extends StatelessWidget {
  const GuardandoDatosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.teal),
            const SizedBox(height: 20),
            Text(
              "Guardando datos...",
              style: GoogleFonts.paytoneOne(
                  fontSize: 20, color: Colors.teal.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
