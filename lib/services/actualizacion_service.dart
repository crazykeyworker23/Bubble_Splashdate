import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bubblesplash/constants/backend_config.dart';
import 'package:bubblesplash/services/app_http.dart' as http;

/// Aviso de actualización de la app.
///
/// Al arrancar se le pregunta al servidor si la versión instalada sigue
/// vigente. Hay dos niveles:
///
///   sugerido    hay una versión nueva; se puede posponer
///   obligatorio la versión instalada ya no está soportada; se bloquea
///
/// El bloqueo se reserva a cambios que de verdad rompen —un contrato de API
/// distinto, un fallo de cobro— porque dejar a un cliente tirado delante del
/// mostrador es caro. Quién es cuál lo decide el servidor, no la app: así se
/// puede endurecer sin publicar una versión nueva.
class ActualizacionService {
  /// Comprueba la versión y muestra el aviso si toca.
  ///
  /// Nunca lanza: no poder comprobar la versión no debe impedir usar la app.
  static Future<void> comprobar(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final plataforma = Platform.isIOS ? 'ios' : 'android';

      final response = await http.get(
        BackendConfig.api(
          'bubblesplash/version/?plataforma=$plataforma&version=${info.version}',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) return;

      final d = jsonDecode(response.body);
      if (d is! Map<String, dynamic> || d['actualizar'] != true) return;
      if (!context.mounted) return;

      await _mostrarAviso(
        context,
        titulo: (d['titulo'] ?? 'Hay una versión nueva').toString(),
        mensaje: (d['mensaje'] ?? '').toString(),
        urlTienda: (d['url_tienda'] ?? '').toString(),
        obligatorio: d['obligatorio'] == true,
      );
    } catch (e) {
      debugPrint('No se pudo comprobar la versión de la app: $e');
    }
  }

  static Future<void> _mostrarAviso(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String urlTienda,
    required bool obligatorio,
  }) async {
    const Color brandTeal = Color(0xFF1B6F81);

    await showDialog<void>(
      context: context,
      // Si es obligatorio no hay forma de esquivarlo: ni tocando fuera ni con
      // el botón atrás del teléfono.
      barrierDismissible: !obligatorio,
      builder: (ctx) => PopScope(
        canPop: !obligatorio,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: brandTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: brandTeal,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F3E47),
                ),
              ),
            ],
          ),
          content: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            if (!obligatorio)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Ahora no',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                final uri = Uri.tryParse(urlTienda);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                // El diálogo obligatorio NO se cierra: si el usuario vuelve
                // sin haber actualizado, se lo sigue encontrando.
                if (!obligatorio && ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text(
                'Actualizar',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
