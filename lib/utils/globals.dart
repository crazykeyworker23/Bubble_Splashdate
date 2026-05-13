import 'package:flutter/material.dart';

/// Llave global para manejar la navegación desde cualquier parte de la app
/// sin necesidad de pasar el [BuildContext].
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
