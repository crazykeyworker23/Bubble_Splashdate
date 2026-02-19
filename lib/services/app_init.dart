import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'fcm_service.dart';

// ------------------------------------------------------
// 1) HANDLER DE MENSAJES EN BACKGROUND (TOP-LEVEL)
// ------------------------------------------------------
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('⚡ [BG] Mensaje en background: \'${message.messageId}\'');
  print('⚡ [BG] Title: ${message.notification?.title}');
  print('⚡ [BG] Body: ${message.notification?.body}');
  print('⚡ [BG] Data: ${message.data}');
}

// ------------------------------------------------------
// 2) INSTANCIA GLOBAL DE NOTIFICACIONES LOCALES
// ------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Canal para Android 8+
const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
  'default_channel', // ID
  'Notificaciones', // Nombre visible
  description: 'Notificaciones generales de la app',
  importance: Importance.high,
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
      AndroidInitializationSettings('@mipmap/ic_launcher');

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
  final data = message.data;

  print('🔔 [LOCAL] Preparando notificación local...');
  print(
    '🔔 [LOCAL] notification: title=${notification?.title}, body=${notification?.body}',
  );
  print('🔔 [LOCAL] data: $data');

  // Título y cuerpo desde notification o, si no hay, desde data
  final String? title = notification?.title ?? data['title']?.toString();
  final String? body = notification?.body ?? data['body']?.toString();

  if (title == null && body == null) {
    print(
      '⚠️ [LOCAL] Mensaje sin notification ni campos title/body en data: ${message.data}',
    );
    return;
  }

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    defaultChannel.id,
    defaultChannel.name,
    channelDescription: defaultChannel.description,
    importance: Importance.high,
    priority: Priority.high,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title ?? 'Notificación',
    body ?? '',
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

  // Inicializar/actualizar token FCM y, si hay sesión iniciada,
  // enviarlo al backend para actualizar use_txt_fcm.
  await FcmService.initAndSendTokenIfPossible();

  // Listener: cuando llega un mensaje con la app ABIERTA (foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 [FG] Mensaje en FOREGROUND: ${message.messageId}');
    print('📩 [FG] Title: ${message.notification?.title}');
    print('📩 [FG] Body: ${message.notification?.body}');
    print('📩 [FG] Data: ${message.data}');
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
}
