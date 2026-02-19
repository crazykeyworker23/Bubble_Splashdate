// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app.dart';

// ------------------------------------------------------
// MAIN PRINCIPAL (solo configuración mínima y arranque de la app)
// ------------------------------------------------------
Future<void> main() async {
  final WidgetsBinding widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();

  // Mantener el splash nativo hasta que Flutter pinte el primer frame.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Limitar orientación vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Barra de navegación y status bar transparentes (Android)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Arrancamos rápido la app; la inicialización pesada (Firebase, FCM, etc.)
  // se hace ya dentro de Flutter mientras mostramos un splash animado.
  runApp(const MyApp());
}
