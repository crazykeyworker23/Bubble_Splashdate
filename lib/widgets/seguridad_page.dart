import 'package:flutter/material.dart';

class SeguridadPage extends StatelessWidget {
  const SeguridadPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color mainColor = Color.fromARGB(255, 27, 111, 129);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Seguridad",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Configuración de seguridad",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Administra las opciones de seguridad de tu cuenta. Puedes cambiar tu contraseña, habilitar autenticación adicional o cerrar sesiones activas.",
            style: TextStyle(color: Colors.black54, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 25),

          // 🔒 Cambiar contraseña
          _securityCard(
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

          // 📱 Verificación en dos pasos
          _securityCard(
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

          // 💻 Sesiones activas
          _securityCard(
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

 
        ],
      ),
    );
  }

  // 🔹 Widget personalizado para opciones de seguridad
  Widget _securityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color.fromARGB(255, 27, 111, 129), size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black87)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
