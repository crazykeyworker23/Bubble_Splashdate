import 'package:flutter/material.dart';

class SeguridadPage extends StatelessWidget {
  const SeguridadPage({super.key});

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
          "Seguridad",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                children: [
                  _sectionCard(
                    title: "Centro de seguridad",
                    icon: Icons.shield_outlined,
                    children: const [
                      Text(
                        "Administra la protección de tu cuenta. "
                        "Cambia tu contraseña, activa una capa adicional de seguridad "
                        "y revisa las sesiones donde has iniciado sesión.",
                        style: TextStyle(color: Colors.black54, fontSize: 14.5, height: 1.5),
                      ),
                    ],
                  ),
                  _securityTile(
                    context,
                    icon: Icons.lock_outline,
                    title: "Cambiar contraseña",
                    subtitle: "Actualiza tu contraseña para mantener tu cuenta segura.",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Función para cambiar contraseña próximamente")),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _securityTile(
                    context,
                    icon: Icons.verified_user_outlined,
                    title: "Verificación en dos pasos",
                    subtitle: "Agrega una capa adicional de seguridad a tu cuenta.",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Función de verificación en dos pasos próximamente")),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _securityTile(
                    context,
                    icon: Icons.devices_other_outlined,
                    title: "Sesiones activas",
                    subtitle: "Revisa los dispositivos donde has iniciado sesión.",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Función de gestión de sesiones próximamente")),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _infoHint(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // 🔹 HEADER PREMIUM
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Protege tu cuenta",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Gestiona contraseña, verificación y sesiones activas",
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
  // 🔹 SECTION CARD
  // =========================
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _brandTeal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _brandTeal, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _brandDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // =========================
  // 🔹 SECURITY TILE PREMIUM
  // =========================
  Widget _securityTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
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
                    style: const TextStyle(color: Colors.black54, fontSize: 13.5, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black38),
          ],
        ),
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
              "Tip: usa una contraseña larga y única. Cuando actives verificación en dos pasos, "
              "tu cuenta quedará mucho más protegida.",
              style: TextStyle(color: _brandDark, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}