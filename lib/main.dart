import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar la conexión central con Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const WaliApp());
}

class WaliApp extends StatelessWidget {
  const WaliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wali App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Usamos el Turquesa de Aventuras Paceñas como color principal
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F988A)), 
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Wali App conectada. ¡Todo listo para el Login y Menú!'),
        ),
      ),
    );
  }
}