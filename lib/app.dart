import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'constants/colors.dart';
import 'routes/app_routes.dart';
import 'controllers/cart_controller.dart';
import 'utils/route_observer.dart';

import 'views/login/login_page.dart';
import 'views/login/home_page.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _isLoggedInFuture;
  bool _removedNativeSplash = false;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _readIsLoggedIn();
  }

  Future<bool> _readIsLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  void _removeNativeSplashOnce() {
    if (_removedNativeSplash) return;
    _removedNativeSplash = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // No mostrar un splash Flutter adicional: el splash nativo sigue visible.
          return const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(),
          );
        }

        _removeNativeSplashOnce();
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
        title: 'Bubble Splash',
        theme: ThemeData(
          primaryColor: kPrimaryColor,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: kPrimaryColor,
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
