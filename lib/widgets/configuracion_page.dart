import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔹 Importa las páginas a las que navegarás
import 'mi_perfil_page.dart';
import 'seguridad_page.dart';
import 'terminos_page.dart';
import 'eliminar_cuenta_page.dart';

class ConfiguracionPage extends StatelessWidget {
  const ConfiguracionPage({super.key});

Future<void> logout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();

  // Comprobamos si el usuario marcó "Remember me"
  bool remember = prefs.getBool('rememberMe') ?? false;

  // Siempre cerramos la sesión
  await prefs.setBool('isLoggedIn', false);

  // Limpiar el token FCM para forzar uno nuevo en el próximo login
  await prefs.remove('fcm_token');

  // Si NO marcó "Remember me", eliminamos el correo
  if (!remember) {
    await prefs.remove('savedEmail');
  }

  // Luego navegamos al login
  Navigator.pushReplacementNamed(context, '/login');
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 27, 111, 129),
        title: const Text(
          "Configuración",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.asset(
              'assets/bebidas.png',
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFB3E5FC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _opcionItem(
                      icon: Icons.person_outline,
                      text: 'Mi Perfil',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MiPerfilPage()),
                        );
                      },
                    ),
                    _opcionItem(
                      icon: Icons.lock_outline,
                      text: 'Seguridad',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SeguridadPage()),
                        );
                      },
                    ),
                    _opcionItem(
                      icon: Icons.description_outlined,
                      text: 'Términos y condiciones',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TerminosPage()),
                        );
                      },
                    ),
                    _opcionItem(
                      icon: Icons.delete_outline,
                      text: 'Eliminar Cuenta',
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EliminarCuentaPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcionItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
      onTap: onTap,
    );
  }
}
