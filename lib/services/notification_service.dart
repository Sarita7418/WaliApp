import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  void Function(NotificationResponse)? _onNotificationResponse;

  void setOnDidReceiveNotificationResponse(void Function(NotificationResponse) handler) {
    _onNotificationResponse = handler;
  }

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse ?? (details) {
        debugPrint('Notification tapped: ${details.payload}, actionId: ${details.actionId}');
      },
    );

    // Crear canal de notificación (Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'Default Channel',
      description: 'Canal por defecto para la app',
      importance: Importance.high,
      playSound: true,
    );

    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _ensureNotificationPermission();
  }

  Future<bool> _ensureNotificationPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.notification.request();
    if (result.isGranted) {
      return true;
    }

    if (result.isDenied) {
      debugPrint('Notification permission denied');
    } else if (result.isPermanentlyDenied) {
      debugPrint('Notification permission permanently denied');
    }

    return false;
  }

  Future<void> showAppStartNotification() async {
    if (!await _ensureNotificationPermission()) {
      debugPrint('No se puede mostrar notificación de arranque: permiso denegado');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Canal por defecto para la app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      channelShowBadge: true,
      ticker: 'Precaución',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_zonas_riesgo',
          'Ver zonas de riesgo',
          showsUserInterface: true,
        ),
      ],
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      'Precaución',
      'Revisa las zonas de riesgo de hoy en la sección "Zonas de precaución" una vez iniciado sesión',
      details,
      payload: 'open_zonas_riesgo',
    );
  }

  Future<void> showLoginNotification() async {
    if (!await _ensureNotificationPermission()) {
      debugPrint('No se puede mostrar notificación de login: permiso denegado');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Canal por defecto para la app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      channelShowBadge: true,
      ticker: 'Inicio de sesión exitoso',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      1,
      'Inicio de sesión exitoso',
      '¡Bienvenido de nuevo!',
      details,
    );
  }

  Future<void> showZoneNotification(String title, String body, {int id = 2}) async {
    if (!await _ensureNotificationPermission()) {
      debugPrint('No se puede mostrar notificación de zona: permiso denegado');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Canal por defecto para la app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      channelShowBadge: true,
      ticker: 'Zona de riesgo detectada',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      title,
      body,
      details,
    );
  }
}
