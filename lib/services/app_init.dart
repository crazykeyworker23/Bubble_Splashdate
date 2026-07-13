import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
        largeIcon: DrawableResourceAndroidBitmap('ic_launcher'), // Logo de la app a color
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
        payload: message.data.toString(),
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
      // Aquí podrías navegar usando un navigatorKey global si quieres
    },
  );

  // Crear canal en Android
  final androidImpl = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidImpl?.createNotificationChannel(defaultChannel);
}

// ------------------------------------------------------
// 5) FUNCIÓN: MOSTRAR NOTIFICACIÓN LOCAL
// ------------------------------------------------------
Future<void> showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;

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
    largeIcon: const DrawableResourceAndroidBitmap('ic_launcher'), // Logo de la app a color
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
    payload: message.data.toString(),
  );

  print('✅ [LOCAL] Notificación local mostrada');
}

// ------------------------------------------------------
// 6) FUNCIÓN PRINCIPAL DE INICIALIZACIÓN DE SERVICIOS
// ------------------------------------------------------
Future<void> initializeAppServices() async {
  // Inicializar Firebase
  await Firebase.initializeApp();

  // Registrar handler de background
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Inicializar notificaciones locales
  await initLocalNotifications();

  // Pedir permiso para mostrar notificaciones (popup SO)
  await requestNotificationPermissions();

  // Listener: cuando llega un mensaje con la app ABIERTA (foreground)
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
      );
    }

    showLocalNotification(message);
  });

  // Listener: cuando el usuario toca una notificación y abre la app
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🚪 [OPEN] Notificación abierta desde bandeja: ${message.messageId}');
    print('🚪 [OPEN] Title: ${message.notification?.title}');
    print('🚪 [OPEN] Body: ${message.notification?.body}');
    print('🚪 [OPEN] Data: ${message.data}');
    // Aquí puedes navegar, por ejemplo:
    // navigatorKey.currentState?.pushNamed('/detalle', arguments: message.data);
  });

  // Manejo de la notificación que abrió la app desde un estado TERMINADO (tercer plano)
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('🚀 [INITIAL] App abierta desde notificación terminada: ${message.messageId}');
      print('🚀 [INITIAL] Title: ${message.notification?.title}');
      print('🚀 [INITIAL] Body: ${message.notification?.body}');
      print('🚀 [INITIAL] Data: ${message.data}');
    }
  });

  // Inicializar/actualizar token FCM y enviarlo al backend de forma asíncrona
  FcmService.initAndSendTokenIfPossible().catchError((e) {
    print('⚠️ Error al inicializar/enviar token FCM (app_init): $e');
  });
}
