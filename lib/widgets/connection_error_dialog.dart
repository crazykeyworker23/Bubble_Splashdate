import 'package:flutter/material.dart';
import 'package:bubblesplash/services/session_manager.dart';

/// Flag global para evitar que se abran múltiples modales de error de conexión simultáneamente.
bool isConnectionDialogOpen = false;

/// Muestra un modal premium de error de conexión (offline/sin señal)
/// con opciones para Reintentar o Cerrar Sesión.
void showConnectionErrorDialog(BuildContext context, {required VoidCallback onRetry}) {
  if (isConnectionDialogOpen) return;
  isConnectionDialogOpen = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Text(
              'Sin Conexión',
              style: TextStyle(
                color: Color(0xFF062B35),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'No se pudo establecer conexión con el servidor. Comprueba tu señal de Internet e intenta de nuevo.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    // Cerrar el diálogo de error de conexión
                    Navigator.pop(context);

                    // Mostrar dialog con spinloader de cerrando sesión
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

                    // Pequeña espera para una animación de feedback visual fluida
                    await Future.delayed(const Duration(milliseconds: 1000));

                    // Ejecutar el logout que redirigirá automáticamente al login
                    await SessionManager.forceLogout();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onRetry();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6F81),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 1,
                  ),
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  ).then((_) {
    isConnectionDialogOpen = false;
  });
}
