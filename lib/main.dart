import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/splash_screen.dart'; // Importamos la nueva pantalla de carga
import 'screens/mapa_riesgos_screen.dart';
import 'services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _handleNotificationResponse(NotificationResponse notificationResponse) {
  final String? actionId = notificationResponse.actionId;
  final String? payload = notificationResponse.payload;

  if (actionId == 'open_zonas_riesgo' || payload == 'open_zonas_riesgo') {
    navigatorKey.currentState?.pushNamed('/mapa_riesgos');
  } else {
    debugPrint('Notification tapped: payload=$payload actionId=$actionId');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga variables .env
  await dotenv.load(fileName: ".env");

  // Inicializa Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await initializeDateFormatting('es', null);

  // Inicializa el servicio de notificaciones locales
  NotificationService().setOnDidReceiveNotificationResponse(_handleNotificationResponse);
  await NotificationService().init();

  runApp(const WaliApp());

  // Mostrar notificación de bienvenida después de arrancar la app
  Future.microtask(() => NotificationService().showAppStartNotification());
}

class WaliApp extends StatelessWidget {
  const WaliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      routes: {
        '/mapa_riesgos': (_) => const MapaRiesgosScreen(),
      },
      title: 'Wali App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F988A),
          primary: const Color(0xFF0F988A),
          secondary: const Color(0xFFFF7043),
          tertiary: const Color(0xFFFFCA28),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),

      // Temporalmente luego pondrás TestMap aquí
      home: const SplashScreen(),
    );
  }
}