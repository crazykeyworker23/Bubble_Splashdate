import 'package:flutter/material.dart';

class TerminosPage extends StatelessWidget {
  const TerminosPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Color.fromARGB(255, 27, 111, 129);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Términos y Condiciones",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Última actualización: 8 de noviembre de 2025",
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "1. Aceptación de los términos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Al acceder o utilizar esta aplicación, usted acepta cumplir con los presentes Términos y Condiciones. Si no está de acuerdo con alguno de ellos, le recomendamos no utilizar la aplicación.",
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),

            const Text(
              "2. Uso permitido",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "El usuario se compromete a utilizar la aplicación únicamente para fines legítimos y de acuerdo con la legislación vigente. Está prohibido el uso indebido que pueda afectar el funcionamiento, seguridad o integridad del sistema y de otros usuarios.",
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),

            const Text(
              "3. Privacidad y protección de datos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "La aplicación recopila y trata datos personales de acuerdo con la política de privacidad correspondiente. Nos comprometemos a proteger la información de los usuarios y a no compartirla sin consentimiento, salvo requerimiento legal.",
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),

            const Text(
              "4. Modificaciones",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Nos reservamos el derecho de modificar estos términos en cualquier momento. Las modificaciones se publicarán en esta misma sección y entrarán en vigor inmediatamente después de su publicación.",
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),

            const Text(
              "5. Contacto",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Si tiene preguntas o inquietudes sobre estos términos, puede comunicarse con nosotros a través del correo soporte@miapp.com.",
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),

            const SizedBox(height: 40),

            // ✅ Botón de aceptación
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // vuelve a la pantalla anterior
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "Aceptar y continuar",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
