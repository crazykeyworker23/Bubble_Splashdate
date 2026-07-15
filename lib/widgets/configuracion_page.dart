import 'package:flutter/material.dart';
import 'package:bubblesplash/services/session_manager.dart';

import 'mi_perfil_page.dart';
import 'seguridad_page.dart';
import 'terminos_page.dart';
import 'eliminar_cuenta_page.dart';
import 'canjear_puntos_page.dart';
import 'in_app_notification_banner.dart';

class ConfiguracionPage extends StatelessWidget {
  const ConfiguracionPage({super.key});

  Future<void> logout(BuildContext context) async {
    // Mostrar el spinloader premium de cerrando sesión
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B6F81)),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Cerrando sesión...',
                    style: TextStyle(
                      color: Color(0xFF062B35),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Pequeña espera para una animación de feedback visual fluida (500ms)
    await Future.delayed(const Duration(milliseconds: 500));

    // Ejecutar el logout centralizado que limpiará todo y redirigirá al login
    await SessionManager.forceLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F3D4A),
        title: const Text(
          "Configuración",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _headerPremium(),
            const SizedBox(height: 20),
            _cardOpciones(context),
            const SizedBox(height: 24),
            _logoutButton(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // =========================
  // 🔹 HEADER PREMIUM
  // =========================
  Widget _headerPremium() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F3D4A),
            Color(0xFF128FA0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: const [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 42, color: Color(0xFF128FA0)),
          ),
          SizedBox(height: 12),
          Text(
            "Mi Cuenta",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Gestiona tu información y seguridad",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔹 CARD OPCIONES
  // =========================
  Widget _cardOpciones(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
        ),
        child: Column(
          children: [
            _opcionItem(
              icon: Icons.person_outline,
              text: 'Mi Perfil',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MiPerfilPage()),
              ),
            ),
            _divider(),
            // _opcionItem(
            //   icon: Icons.lock_outline,
            //   text: 'Seguridad',
            //   onTap: () => Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const SeguridadPage()),
            //   ),
            // ),
            // _divider(),
            _opcionItem(
              icon: Icons.card_giftcard_outlined,
              text: 'Canjear puntos',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CanjearPuntosPage()),
              ),
            ),
            _divider(),
            // _opcionItem(
            //   icon: Icons.notifications_active_outlined,
            //   text: 'Simular notificación',
            //   onTap: () {
            //     InAppNotificationBanner.show(
            //       title: '¡Tu Bubble Tea está listo! 🥤',
            //       body: 'Tu pedido #48291 ha sido preparado y está listo para retirar en la barra.',
            //     );
            //   },
            // ),
            // _divider(),
            _opcionItem(
              icon: Icons.description_outlined,
              text: 'Términos y condiciones',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TerminosPage()),
              ),
            ),
            // _divider(),
            // _opcionItem(
            //   icon: Icons.delete_outline,
            //   text: 'Eliminar Cuenta',
            //   color: Colors.red,
            //   onTap: () => Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const EliminarCuentaPage()),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1),
    );
  }

  // =========================
  // 🔹 LOGOUT BUTTON
  // =========================
  Widget _logoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: OutlinedButton.icon(
        onPressed: () => logout(context),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text(
          "Cerrar Sesión",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =========================
  // 🔹 ITEM PREMIUM
  // =========================
  Widget _opcionItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = const Color(0xFF0F3D4A),
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.black45,
      ),
    );
  }
}