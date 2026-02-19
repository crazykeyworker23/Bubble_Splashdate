import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/colors.dart';
import 'routes/app_routes.dart';
import 'controllers/cart_controller.dart';
import 'utils/route_observer.dart';
import 'services/app_init.dart';

import 'views/login/login_page.dart';
import 'views/login/home_page.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _bootstrapAndReadSession();

    // En cuanto Flutter pinta el primer frame, quitamos el splash nativo
    // para que se vea el splash animado de la app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<bool> _readIsLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedInFlag = prefs.getBool('isLoggedIn') ?? false;
    final String accessToken = (prefs.getString('access_token') ?? '').trim();

    // Si por algún motivo la bandera está en true pero no hay access_token,
    // consideramos que NO hay sesión válida y forzamos a login nuevamente.
    if (!isLoggedInFlag || accessToken.isEmpty) {
      // Limpieza suave de bandera para no dejar el estado inconsistente.
      if (isLoggedInFlag && accessToken.isEmpty) {
        await prefs.setBool('isLoggedIn', false);
      }
      return false;
    }

    return true;
  }

  /// Inicializa servicios de la app (Firebase, FCM, notificaciones, etc.)
  /// y luego lee el estado de sesión.
  Future<bool> _bootstrapAndReadSession() async {
    await initializeAppServices();
    return _readIsLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Mientras se resuelve la sesión mostramos un pequeño splash
          // con el logo y puntos de carga animados.
          return const _SessionSplashLoading();
        }

        final isLoggedIn = snapshot.data ?? false;
        return isLoggedIn ? const HomePage() : const LoginPage();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartController(),
      child: MaterialApp(
        title: 'Splash Bubble',
        theme: ThemeData(
          primaryColor: const Color.fromARGB(255, 255, 255, 255),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color.fromARGB(255, 255, 255, 255),
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        home: const SessionGate(),
        routes: {...AppRoutes.routes},
      ),
    );
  }
}

/// Splash corto que se muestra mientras se lee el estado de sesión
/// al iniciar la app. Incluye el logo y puntos de carga animados.
class _SessionSplashLoading extends StatefulWidget {
  const _SessionSplashLoading();

  @override
  State<_SessionSplashLoading> createState() => _SessionSplashLoadingState();
}

class _SessionSplashLoadingState extends State<_SessionSplashLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos el color principal de la app para que
      // el splash combine con el fondo que tenías antes.
      backgroundColor: const Color.fromARGB(255, 27, 111, 129),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logob.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 16),
            const Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final t = (_controller.value + index * 0.2) % 1.0;
                    final scale = 0.7 + 0.6 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
