import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  int _currentStep = 1; // 1: Email, 2: Código, 3: Nueva Clave
  bool _isLoading = false;
  bool _isPasswordVisible = false; // Controla el "ojo" de la contraseña
  bool _isConfirmPasswordVisible = false;
  final _confirmPasswordController =
      TextEditingController(); // Nuevo controlador

  // PASO 1: Enviar correo de recuperación
  Future<void> _sendResetEmail() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.resetPasswordForEmail(_emailController.text.trim());

      // SEGURIDAD: ¿La pantalla sigue ahí después del await?
      if (!mounted) return;

      setState(() => _currentStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Código enviado a tu correo")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // PASO 2: Verificar el código de 8 dígitos en Supabase
  Future<void> _verifyCode() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
        type: OtpType
            .recovery, // Esto le dice a Supabase que es para recuperar clave
      );

      if (!mounted) return; // Seguridad para BuildContext

      // Si el código es correcto, pasamos al Paso 3 (Nueva Contraseña)
      setState(() => _currentStep = 3);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Código inválido. Revisa tu correo nuevamente."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // PASO 3: Guardar nueva contraseña
  Future<void> _resetPassword() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text.trim()),
      );

      if (!mounted) return; // Seguridad post-await

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contraseña actualizada con éxito")),
      );
      Navigator.pop(context); // Vuelve al Login
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandTeal = Color(0xFF0F988A);
    const brandOrange = Color(0xFFFF9C3C);

    return Scaffold(
      body: Stack(
        children: [
          // Fondo Inmersivo Opaco
          Positioned.fill(
            child: Image.asset(
              'assets/images/bienvenida.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.8)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Cabecera con botón volver
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'WALI',
                        style: TextStyle(
                          color: brandTeal,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: _buildStepContent(brandTeal, brandOrange),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: brandTeal)),
        ],
      ),
    );
  }

  Widget _buildStepContent(Color teal, Color orange) {
    switch (_currentStep) {
      case 1:
        return _stepEmail(teal);
      case 2:
        return _stepVerify(teal);
      case 3:
        return _stepNewPassword(teal);
      default:
        return Container();
    }
  }

  // UI del Paso 1
  Widget _stepEmail(Color teal) {
    return Column(
      children: [
        const Icon(Icons.lock_reset, size: 60, color: Colors.black26),
        const SizedBox(height: 20),
        const Text(
          '¿Olvidaste tu contraseña?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ingresa tu correo para recibir un código de recuperación.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 25),
        _actionButton('Enviar código', _sendResetEmail, teal),
      ],
    );
  }

  // UI del Paso 2
  Widget _stepVerify(Color teal) {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 60,
          color: Colors.black26,
        ),
        const SizedBox(height: 20),
        const Text(
          '¿Revisaste tu correo?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ingresa el código de 6 dígitos que enviamos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
        const SizedBox(height: 25),
        _actionButton('Verificar código', _verifyCode, teal),
      ],
    );
  }

  // UI del Paso 3
  Widget _stepNewPassword(Color teal) {
    return Column(
      children: [
        const Icon(Icons.security_outlined, size: 60, color: Colors.black26),
        const SizedBox(height: 15),
        const Text(
          'Crea tu nueva contraseña',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Asegúrate de que sea una combinación segura.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
        const SizedBox(height: 25),

        // CAMPO 1: NUEVA CONTRASEÑA
        TextField(
          controller: _newPasswordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.black26,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),

        const SizedBox(height: 15),

        // CAMPO 2: CONFIRMAR CONTRASEÑA
        TextField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_reset_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.black26,
              ),
              onPressed: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),

        const SizedBox(height: 25),

        // BOTÓN DE ACCIÓN
        _actionButton('Restablecer contraseña', () {
          if (_newPasswordController.text == _confirmPasswordController.text) {
            _resetPassword();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Las contraseñas no coinciden")),
            );
          }
        }, teal),
      ],
    );
  }

  Widget _actionButton(String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
