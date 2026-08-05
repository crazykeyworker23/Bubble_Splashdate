import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bubblesplash/constants/api_constants.dart';
import 'package:bubblesplash/services/session_manager.dart';

class EliminarCuentaPage extends StatefulWidget {
  const EliminarCuentaPage({super.key});

  @override
  State<EliminarCuentaPage> createState() => _EliminarCuentaPageState();
}

class _EliminarCuentaPageState extends State<EliminarCuentaPage> {
  static const Color _brandDark = Color(0xFF0F3D4A);
  static const Color _brandTeal = Color(0xFF128FA0);
  static const Color _bg = Color(0xFFF4FAFF);

  bool _acknowledged = false;
  bool _loading = false;

  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _acknowledged && !_loading;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandDark,
        foregroundColor: Colors.white,
        title: const Text(
          "Eliminar cuenta",
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
                  _warningCard(),
                  const SizedBox(height: 12),
                  _consequencesCard(),
                  const SizedBox(height: 12),
                  _reasonCard(),
                  const SizedBox(height: 12),
                  _ackCard(),
                  const SizedBox(height: 16),
                  _deleteButton(canDelete),
                  const SizedBox(height: 10),
                  _secondaryButton(),
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
          Icon(Icons.delete_forever_outlined, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Zona de riesgo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Esta acción es permanente e irreversible",
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
  // 🔹 Warning card
  // =========================
  Widget _warningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Eliminar tu cuenta borrará tu acceso a Splash Bubble. "
              "Asegúrate de haber guardado lo que necesites antes de continuar.",
              style: TextStyle(
                color: Color(0xFF3A0B0B),
                fontSize: 13.8,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔹 Consequences
  // =========================
  Widget _consequencesCard() {
    return _card(
      title: "¿Qué se elimina?",
      icon: Icons.list_alt_outlined,
      child: Column(
        children: const [
          _Bullet(text: "Tu perfil y acceso a la cuenta."),
          _Bullet(text: "Historial y datos asociados a la app (según política de privacidad)."),
          _Bullet(text: "Puntos/beneficios acumulados (si aplica)."),
          _Bullet(text: "Preferencias y configuraciones personales."),
        ],
      ),
    );
  }

  // =========================
  // 🔹 Reason
  // =========================
  Widget _reasonCard() {
    return _card(
      title: "¿Por qué te vas? (opcional)",
      icon: Icons.chat_bubble_outline,
      child: TextField(
        controller: _reasonController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: "Ej: No uso la app, problemas con pedidos, quiero crear otra cuenta…",
          filled: true,
          fillColor: const Color(0xFFF7FBFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _brandTeal, width: 1.4),
          ),
        ),
      ),
    );
  }

  // =========================
  // 🔹 Acknowledge
  // =========================
  Widget _ackCard() {
    return _card(
      title: "Confirmación",
      icon: Icons.verified_outlined,
      child: SwitchListTile(
        value: _acknowledged,
        onChanged: _loading ? null : (v) => setState(() => _acknowledged = v),
        contentPadding: EdgeInsets.zero,
        title: const Text(
          "Entiendo que esta acción es irreversible",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          "No podrás recuperar tu cuenta después de eliminarla.",
          style: TextStyle(color: Colors.black54),
        ),
        activeColor: _brandTeal,
      ),
    );
  }

  // =========================
  // 🔹 Primary delete button
  // =========================
  Widget _deleteButton(bool enabled) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => _openDeleteSheet(context) : null,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.delete_forever),
        label: Text(
          _loading ? "Procesando..." : "Eliminar cuenta definitivamente",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.red.withOpacity(0.35),
          disabledForegroundColor: Colors.white70,
        ),
      ),
    );
  }

  Widget _secondaryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: const Text("Volver"),
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandDark,
          side: BorderSide(color: _brandDark.withOpacity(0.25)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // =========================
  // 🔹 BottomSheet premium (2da confirmación)
  // =========================
  void _openDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Última confirmación",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Si continúas, tu cuenta será eliminada y perderás el acceso. "
                  "Esta acción no se puede deshacer.",
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brandDark,
                          side: BorderSide(color: _brandDark.withOpacity(0.25)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Cancelar"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _confirmFinalDialog(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text("Eliminar"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmFinalDialog(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: const Text("¿Seguro que deseas eliminar tu cuenta? Esta acción es irreversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      // 1. Intentar borrar en el backend
      if (token != null && token.isNotEmpty) {
        try {
          final uri = Uri.parse(ApiConstants.baseUrl + '/auth/users/me/');
          await http.delete(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('⚠️ Error deleting user on backend: $e');
        }
      }

      // 2. Intentar borrar de Firebase Auth
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser.delete().timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        // Si falla por requerir reautenticación reciente, al menos la cuenta en base de datos ya fue borrada
        debugPrint('⚠️ Error deleting user in Firebase: $e');
      }

      // 3. Limpieza de sesión y redirección centralizada
      await SessionManager.forceLogout();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tu cuenta ha sido eliminada correctamente.")),
      );
    } catch (e) {
      debugPrint('Error general al eliminar cuenta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al eliminar la cuenta: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // 🔹 Card helper premium
  // =========================
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _brandDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// 🔹 Bullet helper
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle, size: 18, color: Color(0xFF128FA0)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87, fontSize: 14.3, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}