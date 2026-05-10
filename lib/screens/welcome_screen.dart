// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Imports para las pantallas de destino (asegúrate de que existan)
import 'login_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Controlador para el pulso de brillo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Colores de marca
    const brandTeal = Color(0xFF0F988A);
    const brandOrange = Color(0xFFFF9C3C); 

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Imagen de Fondo Inmersiva
          Positioned.fill(
            child: Image.asset(
              'assets/images/bienvenida.png', // <--- Asegúrate de que esta sea tu foto de fondo
              fit: BoxFit.cover,
            ),
          ),

          // 2. Degradado Cinematográfico Inferior (Para contraste de texto)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.95), // Muy oscuro abajo para letras grandes
                  ],
                  stops: const [0.2, 0.9],
                ),
              ),
            ),
          ),

          // 3. CONTENIDO UI (CENTRALIZADO, COMPACTO Y LLAMATIVO)
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30), // Un poco más ancho el margen
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Título Superior Compacto (Aumentado y con más espacio)
                    RichText(
                      text: const TextSpan(
                        text: 'WALI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22, // <--- AUMENTADO (Llamativo)
                          letterSpacing: 6.0, // <--- MÁS ESPACIADO (Premium)
                          color: brandTeal,
                        ),
                        children: [
                          TextSpan(text: '.', style: TextStyle(color: brandOrange, fontSize: 32)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 35),

                    // 4. LOGO GRANDE Y CENTRAL CON CORTE CIRCULAR PERFECTO
                    // Esta estructura soluciona el problema de Goal 3
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => Container(
                        width: 170, // Mantenemos el tamaño
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white, // Fusiona el fondo blanco del logo
                          boxShadow: [
                            BoxShadow(
                              color: brandTeal.withValues(alpha: 0.3 * _pulseAnimation.value),
                              blurRadius: 25,
                              spreadRadius: 2,
                            )
                          ],
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        padding: EdgeInsets.zero, // Mantenemos sin padding para que sea grande
                        child: ClipOval( // <--- CLAVE PARA META 3: Corta la imagen cuadrada en un círculo perfecto, eliminando las puntas blancas
                          child: Image.asset(
                            'assets/images/logoWALI.jpeg', // <--- Asegúrate de que esta sea tu imagen de logo
                            fit: BoxFit.contain, // Se ajusta perfectamente dentro del recorte circular
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.terrain, size: 80, color: brandTeal),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    // 5. BLOQUE DE TEXTO PREMIUM (GRANDES Y LLAMATIVAS)
                    // Aumentando tamaños para Goals 2 y 4
                    Text(
                      'Descubre La Paz\ncomo nunca antes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w900, // <--- MÁS BOLD (Llamativo)
                        fontSize: 40, // <--- AUMENTADO SIGNIFICATIVAMENTE
                        height: 1.1,
                        color: Colors.white,
                        // EFECTO DE SOMBRA PREMIUM (Suma vibrancia y profundidad)
                        shadows: [
                          Shadow(
                            color: brandTeal.withValues(alpha: 0.5), // Sombra turquesa sutil
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Tu conserje personal para una experiencia premium en la ciudad maravilla.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 17, // <--- AUMENTADO
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.85), // <--- MÁS LEGIBLE
                      ),
                    ),
                    
                    const SizedBox(height: 45), // Más espacio antes de los botones

                    // 6. BOTONES DE ACCIÓN COMPACTOS Y VIBRANTES
                    // Botón Principal "COMENZAR"
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandTeal, // Usando color de marca
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: brandTeal.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () {
                          final session = Supabase.instance.client.auth.currentSession;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => session != null ? const HomeScreen() : const LoginScreen()),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'COMENZAR',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18, // <--- AUMENTADO (Botón más llamativo)
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(width: 10),
                            // El icono es NARANJA para vibrancia (Fix Goals 1 & 4)
                            Icon(Icons.arrow_forward_rounded, color: brandOrange, size: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Botón Outlined "REGISTRARSE"
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                        },
                        child: const Text(
                          'REGISTRARSE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // Enlace de Login
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      },
                      child: RichText(
                        text: const TextSpan(
                          text: '¿Ya tienes una cuenta? ',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'INICIAR SESIÓN',
                              style: TextStyle(
                                color: brandTeal, 
                                fontWeight: FontWeight.bold, 
                                decoration: TextDecoration.underline,
                                decorationColor: brandTeal, 
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}