import 'package:flutter/material.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Animación de rotación de los anillos
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Animación de pulso del brillo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // ANIMACIÓN DE LA BARRA (De 0 a 100%)
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _loadingController.forward(); // Inicia el movimiento de la barra
    _checkAuth();
  }

  // En el método _checkAuth() de tu SplashScreen, cambia la navegación:
  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    // Ahora siempre mandamos a la WelcomeScreen al terminar la carga
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandTeal = Color(0xFF0F988A);
    const brandOrange = Color(0xFFFF9C3C);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo de patrón (ocupa toda la pantalla)
          const Positioned.fill(child: AndeanPatternPainter()),

          // CONTENIDO CENTRALIZADO
          SizedBox.expand(
            // Obliga al contenido a usar todo el ancho
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Centra horizontalmente
              children: [
                // Área del Logo con Anillos
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Brillo de fondo
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brandTeal.withValues(
                            alpha: 0.05 * _pulseController.value,
                          ),
                        ),
                      ),
                    ),
                    // Anillo giratorio
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: brandTeal.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ),
                    // Logo Blanco Centrado
                    Container(
                      width: 200,
                      height: 200,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(25),
                      child: Image.asset(
                        'assets/images/logoWALI.jpeg', // <--- REVISA SI ES .png O .jpeg
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.terrain,
                              size: 80,
                              color: brandTeal,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                const Text(
                  'WALI',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: Color(0xFF091E25),
                  ),
                ),
                const Text(
                  'TURISMO INTELIGENTE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: brandTeal,
                  ),
                ),
                const SizedBox(height: 60),

                // BARRA DE CARGA ANIMADA Y CENTRADA
                Container(
                  width: 220,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor:
                          _progressAnimation.value, // Esto hace que se mueva
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [brandTeal, brandOrange],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: brandTeal.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor de puntos (Optimizado)
class AndeanPatternPainter extends StatelessWidget {
  const AndeanPatternPainter({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PatternPainter());
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F988A).withValues(alpha: 0.05);
    for (double i = 0; i < size.width; i += 32) {
      for (double j = 0; j < size.height; j += 32) {
        canvas.drawCircle(Offset(i, j), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}
