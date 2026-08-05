import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bubblesplash/services/notificacion_router.dart';
import 'package:bubblesplash/services/notificaciones_store.dart';

import 'fcm_service.dart';
import 'package:bubblesplash/widgets/in_app_notification_banner.dart';

// ------------------------------------------------------
// 1) HANDLER DE MENSAJES EN BACKGROUND (TOP-LEVEL)
// ------------------------------------------------------
// ------------------------------------------------------
// 0) HELPER: EXTRAER TÍTULO Y CUERPO DE FORMA ULTRA SEGURA Y CON FALLBACKS
// ------------------------------------------------------
Map<String, String> _extractTitleAndBody(RemoteMessage message) {
  final data = message.data;
  final notification = message.notification;

  String? title = notification?.title;
  if (title == null || title.trim().isEmpty) {
    title = data['title']?.toString() ??
            data['headline']?.toString() ??
            data['header']?.toString() ??
            data['subject']?.toString() ??
            'Notificación';
  }

  String? body = notification?.body;
  if (body == null || body.trim().isEmpty) {
    body = data['body']?.toString() ??
           data['message']?.toString() ??
           data['content']?.toString() ??
           data['desc']?.toString() ??
           data['description']?.toString() ??
           data['text']?.toString() ??
           data['msg']?.toString() ??
           '';
  }

  return {'title': title, 'body': body};
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('⚡ [BG] Mensaje en background: \'${message.messageId}\'');
  
  final extracted = _extractTitleAndBody(message);
  final title = extracted['title']!;
  final body = extracted['body']!;

  print('⚡ [BG] Title Extraído: $title');
  print('⚡ [BG] Body Extraído: $body');
  print('⚡ [BG] Data: ${message.data}');

  // Se archiva también aquí. Este handler corre en su propio isolate y no
  // pasa por `showLocalNotification`, así que sin esta línea todo lo que
  // llegara con la app cerrada faltaría luego en el listado.
  await NotificacionesStore.guardar(
    id: message.messageId ?? '',
    titulo: title,
    cuerpo: body,
    datos: Map<String, dynamic>.from(message.data),
  );

  // Si es un mensaje de tipo datos sin notificación directa del SO,
  // levantamos nosotros la notificación local en el isolate de background.
  if (message.notification == null) {
    if (title.isNotEmpty || body.isNotEmpty) {
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (_) {},
      );

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Notificaciones',
        channelDescription: 'Notificaciones generales de la app',
        importance: Importance.max,
        priority: Priority.max,
        color: Color(0xFF0B3D4A), // Color azul marino de la marca
        colorized: true, // Pinta el fondo de la notificación con el color de marca
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'), // drawable/, NO mipmap
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title.isNotEmpty ? title : 'Notificación',
        body,
        platformDetails,
        payload: _armarPayload(message, title, body),
      );
      print('✅ [BG] Notificación local de datos mostrada en background');
    }
  }
}

// ------------------------------------------------------
// 2) INSTANCIA GLOBAL DE NOTIFICACIONES LOCALES
// ------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Canal para Android 8+
const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
  'high_importance_channel', // ID
  'Notificaciones', // Nombre visible
  description: 'Notificaciones generales de la app',
  importance: Importance.max,
);

// ------------------------------------------------------
// 3) FUNCIÓN: PERMISOS DE NOTIFICACIÓN (iOS + Android 13+)
// ------------------------------------------------------
Future<void> requestNotificationPermissions() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  print('📲 Estado permiso notificaciones: ${settings.authorizationStatus}');

  // iOS → mostrar notificaciones también cuando la app está abierta
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

// ------------------------------------------------------
// 4) FUNCIÓN: INICIALIZAR NOTIFICACIONES LOCALES
// ------------------------------------------------------
Future<void> initLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('ic_notification');

  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      print('🟢 [LOCAL] Notificación tocada → ${details.payload}');
      // El payload viaja como JSON para poder llevar `tipo` y `ruta`: sin
      // ellos no hay forma de saber a qué pantalla corresponde el aviso.
      final datos = _leerPayload(details.payload);
      NotificacionRouter.abrir(
        datos,
        titulo: (datos['_titulo'] ?? '').toString(),
        cuerpo: (datos['_cuerpo'] ?? '').toString(),
      );
    },
  );

  // Crear canal en Android
  final androidImpl = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidImpl?.createNotificationChannel(defaultChannel);
}

/// Empaqueta la notificación para poder recuperarla cuando la toquen.
///
/// Va en JSON y no con `toString()`: el `toString()` de un Map no se puede
/// volver a leer de forma fiable, así que el `tipo` y la `ruta` que manda el
/// servidor —lo único que dice a qué pantalla lleva el aviso— se perdían por
/// el camino.
///
/// El título y el cuerpo se guardan con nombres que empiezan por guion bajo
/// para no chocar con ninguna clave que envíe el backend.
String _armarPayload(RemoteMessage message, String title, String body) {
  try {
    return jsonEncode({
      ...message.data,
      '_titulo': title,
      '_cuerpo': body,
    });
  } catch (_) {
    return jsonEncode({'_titulo': title, '_cuerpo': body});
  }
}

/// Vuelve a leer lo que guardó `_armarPayload`.
///
/// Nunca lanza: un payload corrupto debe abrir la app, no romperla.
Map<String, dynamic> _leerPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return {};
}

// ------------------------------------------------------
// 5) FUNCIÓN: MOSTRAR NOTIFICACIÓN LOCAL
// ------------------------------------------------------
Future<void> showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;

  // Se archiva aquí porque es el punto por el que pasan todas: las de primer
  // plano y las de segundo. El `messageId` evita que una misma notificación
  // entre dos veces cuando ambos caminos la procesan.
  final _guardado = _extractTitleAndBody(message);
  NotificacionesStore.guardar(
    id: message.messageId ?? '',
    titulo: _guardado['title'] ?? '',
    cuerpo: _guardado['body'] ?? '',
    datos: Map<String, dynamic>.from(message.data),
  );

  print('🔔 [LOCAL] Preparando notificación local...');
  print('🔔 [LOCAL] data: ${message.data}');

  // Extraer título y cuerpo usando el helper ultra seguro
  final extracted = _extractTitleAndBody(message);
  final title = extracted['title']!;
  final body = extracted['body']!;

  print('🔔 [LOCAL] Title Extraído: $title, Body Extraído: $body');

  if (title.isEmpty && body.isEmpty) {
    print('⚠️ [LOCAL] Mensaje sin contenido de texto (título y cuerpo vacíos). No se muestra.');
    return;
  }

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    defaultChannel.id,
    defaultChannel.name,
    channelDescription: defaultChannel.description,
    importance: Importance.max,
    priority: Priority.max,
    color: const Color(0xFF0B3D4A), // Color azul marino de la marca
    colorized: true, // Pinta el fondo de la notificación con el color de marca
    largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'), // drawable/, NO mipmap
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title.isNotEmpty ? title : 'Notificación',
    body,
    platformDetails,
    payload: _armarPayload(message, title, body),
  );

  print('✅ [LOCAL] Notificación local mostrada');
}

// ------------------------------------------------------
// 6) FUNCIÓN PRINCIPAL DE INICIALIZACIÓN DE SERVICIOS
// ------------------------------------------------------
Future<void> initializeAppServices() async {
  bool isFirebaseInitialized = false;

  // Inicializar Firebase
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
    print('✅ [INIT] Firebase inicializado con éxito');
  } catch (e) {
    print('⚠️ [INIT] Error al inicializar Firebase (archivo config faltante o corrupto): $e');
  }

  if (isFirebaseInitialized) {
    try {
      // Registrar handler de background
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('⚠️ [INIT] Error al registrar FCM background handler: $e');
    }
  }

  // Inicializar notificaciones locales
  try {
    await initLocalNotifications();
  } catch (e) {
    print('⚠️ [INIT] Error al inicializar notificaciones locales: $e');
  }

  if (isFirebaseInitialized) {
    // Pedir permiso para mostrar notificaciones (popup SO)
    try {
      await requestNotificationPermissions();
    } catch (e) {
      print('⚠️ [INIT] Error al solicitar permisos de notificación: $e');
    }

    // Listener: cuando llega un mensaje con la app ABIERTA (foreground)
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📩 [FG] Mensaje en FOREGROUND: ${message.messageId}');
        print('📩 [FG] Data: ${message.data}');

        // Extraer título y cuerpo usando el helper ultra seguro
        final extracted = _extractTitleAndBody(message);
        final title = extracted['title']!;
        final body = extracted['body']!;

        print('📩 [FG] Title Extraído: $title, Body Extraído: $body');

        if (title.isNotEmpty || body.isNotEmpty) {
          InAppNotificationBanner.show(
            title: title.isNotEmpty ? title : 'Notificación',
            body: body,
            // Con la app abierta el aviso sale como banner. Tocarlo tiene que
            // llevar al mismo sitio que tocarlo en la bandeja: si uno navega
            // y el otro no, el comportamiento depende de dónde estabas
            // mirando, que es justo lo que confunde.
            onTap: () => NotificacionRouter.abrir(
              Map<String, dynamic>.from(message.data),
              titulo: title,
              cuerpo: body,
            ),
          );
        }

        showLocalNotification(message);
      });
    } catch (e) {
      print('⚠️ [INIT] Error en onMessage listener: $e');
    }

    // Listener: cuando el usuario toca una notificación y abre la app
    try {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🚪 [OPEN] Notificación abierta desde bandeja: ${message.messageId}');
        final extraido = _extractTitleAndBody(message);
        NotificacionRouter.abrir(
          Map<String, dynamic>.from(message.data),
          titulo: extraido['title'] ?? '',
          cuerpo: extraido['body'] ?? '',
        );
      });
    } catch (e) {
      print('⚠️ [INIT] Error en onMessageOpenedApp listener: $e');
    }

    // Manejo de la notificación que abrió la app desde un estado TERMINADO (tercer plano)
    try {
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print('🚀 [INITIAL] App abierta desde notificación terminada: ${message.messageId}');
          final extraido = _extractTitleAndBody(message);
          // Se espera a que haya un Navigator montado: en este punto la app
          // aún está arrancando y navegar ahora no llevaría a ninguna parte.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificacionRouter.abrir(
              Map<String, dynamic>.from(message.data),
              titulo: extraido['title'] ?? '',
              cuerpo: extraido['body'] ?? '',
            );
          });
        }
      });
    } catch (e) {
      print('⚠️ [INIT] Error en getInitialMessage: $e');
    }

    // Inicializar/actualizar token FCM y enviarlo al backend de forma asíncrona
    FcmService.initAndSendTokenIfPossible().catchError((e) {
      print('⚠️ Error al inicializar/enviar token FCM (app_init): $e');
    });
  }
}
