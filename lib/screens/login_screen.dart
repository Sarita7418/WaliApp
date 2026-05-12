import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';// <-- Importante: Añadimos Google Sign In
import 'home_screen.dart';
import 'register_screen.dart';
import 'welcome_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    const brandTeal = Color(0xFF0F988A);
    const brandOrange = Color(0xFFFF9C3C);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Imagen de fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/bienvenida.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Capa oscura opaca
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.75)),
          ),

          // 4. Tarjeta de Login Centrada
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 25,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFA),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.black26,
                          size: 24,
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WelcomeScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    // TÍTULO WALI
                    RichText(
                      text: const TextSpan(
                        text: 'WALI',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: brandTeal,
                          letterSpacing: 4,
                        ),
                        children: [
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: brandOrange, fontSize: 50),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    // LOGO CIRCULAR
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logoWALI.jpeg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Descubre La Paz, a tu manera.',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),

                    const SizedBox(height: 35),

                    // FORMULARIO
                    _buildInput(
                      _emailController,
                      'Correo electrónico',
                      Icons.mail_outline,
                    ),
                    const SizedBox(height: 15),
                    _buildInput(
                      _passwordController,
                      'Contraseña',
                      Icons.lock_outline,
                      isPass: true,
                    ),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          color: brandTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // BOTÓN INICIAR SESIÓN (Normal)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleEmailLogin,
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // BOTÓN GOOGLE (Ahora conectado a la función)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : _signInWithGoogle, // <-- Conectado aquí
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons
                                  .account_circle_outlined, // Aquí podrías poner el logo de Google luego si quieres
                              color: Colors.black54,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Continuar con Google',
                              style: TextStyle(
                                color: Color(0xFF2D3E42),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // REGISTRO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes cuenta? ',
                          style: TextStyle(color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          ),
                          child: const Text(
                            'Regístrate aquí',
                            style: TextStyle(
                              color: brandTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: brandTeal)),
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPass = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.black26),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF0F988A)),
        ),
      ),
    );
  }

  Future<void> _handleEmailLogin() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Credenciales incorrectas")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- LÓGICA COMPLETA DE GOOGLE ---
  // --- LÓGICA COMPLETA DE GOOGLE ---
  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      // 1. TU ID DE APLICACIÓN WEB DE GOOGLE CLOUD
      const webClientId = '958561798841-4b7vvh6svt49qlmvo5br7fsp5h4jn6ti.apps.googleusercontent.com';

      // 2. INICIALIZACIÓN CORRECTA
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      // 3. ABRIR POP-UP
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }

      // 4. OBTENER TOKENS
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No se pudo obtener el ID Token de Google.';
      }

      // 5. INICIAR SESIÓN EN SUPABASE
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken, 
      );

      // 6. VERIFICAR USUARIO EN TABLA PERSONAS
      if (response.user != null) {
        await _checkAndCreateUserRecord(response.user!);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error con Google: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndCreateUserRecord(User user) async {
    final client = Supabase.instance.client;

    final existingUser = await client
        .from('personas')
        .select('id')
        .eq('id_usuario', user.id)
        .maybeSingle();

    if (existingUser == null) {
      final fullName = user.userMetadata?['full_name'] ?? '';
      List<String> names = fullName.split(' ');
      String name = names.isNotEmpty ? names[0] : 'Explorer';
      String lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      await client.from('personas').insert({
        'id_usuario': user.id,
        'nombres': name,
        'apellido_paterno': lastName,
        'id_idioma_fav': 201,
        'id_sistema_medida': 301,
      });
    }
  }
}
