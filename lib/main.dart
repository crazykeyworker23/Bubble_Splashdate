// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

// ------------------------------------------------------
// MAIN PRINCIPAL (solo configuración mínima y arranque de la app)
// ------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Limitar orientación vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configuración de sistema en modo edge-to-edge sin cambiar colores
  // para evitar el uso de APIs obsoletas en Android 15+.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Arrancamos rápido la app; la inicialización pesada (Firebase, FCM, etc.)
  // se hace ya dentro de Flutter mientras mostramos un splash animado.
  runApp(const MyApp());
}
