import 'package:flutter/material.dart';

class TerminosPage extends StatelessWidget {
  const TerminosPage({super.key});

  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);
  static const Color _bg = Color(0xFFF4FAFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        title: const Text(
          "Términos y Condiciones",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              child: Column(
                children: [
                  _metaCard(
                    title: "Splash Bubble",
                    subtitle: "Última actualización: 28 de enero de 2026",
                    icon: Icons.receipt_long_outlined,
                  ),
                  const SizedBox(height: 12),

                  _sectionCard(
                    number: "1",
                    title: "Aceptación de los términos",
                    content:
                        "Al descargar, registrarte o utilizar Splash Bubble (la “App”), aceptas estos Términos y Condiciones. "
                        "Si no estás de acuerdo con alguno de los puntos, te recomendamos no utilizar la App.",
                  ),

                  _sectionCard(
                    number: "2",
                    title: "Descripción del servicio",
                    content:
                        "Splash Bubble permite explorar productos, realizar pedidos, acceder a promociones, programas de fidelización "
                        "(puntos/beneficios) y recibir notificaciones relacionadas con tu experiencia. Algunas funciones pueden variar "
                        "según tu ciudad, tienda afiliada o disponibilidad.",
                  ),

                  _sectionCard(
                    number: "3",
                    title: "Cuenta y responsabilidad del usuario",
                    content:
                        "Eres responsable de mantener la confidencialidad de tu cuenta y de la información que proporcionas. "
                        "Te comprometes a usar la App de forma lícita y a no realizar actividades que afecten la seguridad, estabilidad "
                        "o funcionamiento del servicio, ni el acceso de otros usuarios.",
                  ),

                  _sectionCard(
                    number: "4",
                    title: "Pedidos, precios y disponibilidad",
                    content:
                        "Los precios, descripciones, promociones y disponibilidad pueden cambiar sin previo aviso. "
                        "Al confirmar un pedido, aceptas los detalles mostrados (productos, cantidades, precios, comisiones, "
                        "tiempos estimados y condiciones de entrega/recogida si aplica).",
                  ),

                  _sectionCard(
                    number: "5",
                    title: "Promociones, cupones y programa de puntos",
                    content:
                        "Las promociones y cupones pueden estar sujetos a condiciones específicas (vigencia, stock, monto mínimo, "
                        "tiendas participantes, productos excluidos). Los puntos o beneficios no son dinero en efectivo, no son transferibles "
                        "salvo que se indique lo contrario, y pueden vencer según la política vigente de la App.",
                  ),

                  _sectionCard(
                    number: "6",
                    title: "Privacidad y datos personales",
                    content:
                        "Splash Bubble puede tratar datos necesarios para operar la App, como datos de cuenta, uso, dispositivo y, "
                        "si lo autorizas, ubicación para mejorar tu experiencia (por ejemplo, tiendas cercanas o validación de delivery). "
                        "Nos comprometemos a proteger la información y a no compartirla sin base legal o consentimiento, salvo obligación "
                        "por ley o para brindar el servicio (por ejemplo, proveedores tecnológicos).",
                  ),

                  _sectionCard(
                    number: "7",
                    title: "Notificaciones y comunicaciones",
                    content:
                        "Podemos enviarte notificaciones sobre pedidos, promociones, seguridad de tu cuenta y actualizaciones del servicio. "
                        "Puedes ajustar tus preferencias desde la configuración del dispositivo o dentro de la App cuando esté disponible.",
                  ),

                  _sectionCard(
                    number: "8",
                    title: "Limitación de responsabilidad",
                    content:
                        "La App se brinda “tal cual” y puede presentar interrupciones o errores. Splash Bubble no será responsable por daños "
                        "indirectos o consecuenciales derivados del uso o imposibilidad de uso del servicio, en la medida permitida por la ley. "
                        "Esto no limita derechos irrenunciables del consumidor cuando aplique.",
                  ),

                  _sectionCard(
                    number: "9",
                    title: "Cambios a los términos",
                    content:
                        "Podemos actualizar estos términos en cualquier momento. Publicaremos la versión vigente en esta sección "
                        "y su uso continuado de la App se considerará aceptación de los cambios.",
                  ),

                  _sectionCard(
                    number: "10",
                    title: "Contacto",
                    content:
                        "Si tienes preguntas sobre estos Términos y Condiciones, contáctanos por: soporte@splashbubble.pe "
                        "o por los canales oficiales publicados en la App.",
                  ),

                  const SizedBox(height: 12),
                  _infoHint(),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        "Aceptar y continuar",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // 🔹 Header premium
  // =========================
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandDark, _brandTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.description_outlined, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Términos y Condiciones",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Lee la información importante antes de continuar",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔹 Meta card
  // =========================
  Widget _metaCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _brandTeal.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _brandTeal, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _brandDark,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔹 Section card
  // =========================
  Widget _sectionCard({
    required String number,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _brandTeal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: _brandTeal,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: _brandDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _brandTeal.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandTeal.withOpacity(0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: _brandTeal),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Recuerda: algunas funciones pueden variar por tienda/ciudad. "
              "Si activas ubicación, podremos mejorar recomendaciones y disponibilidad.",
              style: TextStyle(color: _brandDark, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}