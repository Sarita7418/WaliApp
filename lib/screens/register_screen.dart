// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _nombres = TextEditingController();
  final _apPaterno = TextEditingController();
  final _apMaterno = TextEditingController();
  final _tel = TextEditingController();
  DateTime? _fechaNacimiento;
  
  // Valores por defecto basados en tu tabla subdominios
  int _idiomaSeleccionado = 201; // Español
  int _medidaSeleccionada = 301; // Métrico

  bool _loading = false;

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.auth.signUp(email: _email.text, password: _pass.text);
      
      if (res.user != null) {
        await supabase.from('personas').insert({
          'id_usuario': res.user!.id,
          'nombres': _nombres.text,
          'apellido_paterno': _apPaterno.text,
          'apellido_materno': _apMaterno.text,
          'telefono': _tel.text,
          'fecha_nacimiento': _fechaNacimiento?.toIso8601String().split('T')[0],
          'id_rol': 1,
          'id_idioma_fav': _idiomaSeleccionado,
          'id_sistema_medida': _medidaSeleccionada,
        });
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Únete a Wali'), backgroundColor: const Color(0xFF0F988A), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildField(_email, 'Correo', Icons.email),
            _buildField(_pass, 'Contraseña', Icons.lock, hide: true),
            const Divider(height: 30),
            const Text('Datos del Turista', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F988A))),
            const SizedBox(height: 15),
            _buildField(_nombres, 'Nombres', Icons.badge),
            _buildField(_apPaterno, 'Apellido Paterno', Icons.person),
            _buildField(_apMaterno, 'Apellido Materno', Icons.person_outline),
            _buildField(_tel, 'Teléfono', Icons.phone),
            
            // Selector de Fecha
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_fechaNacimiento == null ? 'Seleccionar Fecha Nacimiento' : 'Fecha: ${_fechaNacimiento!.toLocal()}'.split(' ')[0]),
              leading: const Icon(Icons.cake, color: Color(0xFF0F988A)),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
                if (date != null) setState(() => _fechaNacimiento = date);
              },
            ),
            const SizedBox(height: 15),

            // Selectores de Preferencias (Dominios)
            // Selectores de Preferencias (Dominios)
            DropdownButtonFormField<int>(
              initialValue: _idiomaSeleccionado, // <--- Cambiado aquí
              decoration: const InputDecoration(labelText: 'Idioma Preferido', prefixIcon: Icon(Icons.language), border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 201, child: Text('Español')),
                DropdownMenuItem(value: 202, child: Text('Inglés')),
                DropdownMenuItem(value: 203, child: Text('Portugués')),
                DropdownMenuItem(value: 204, child: Text('Aymara')),
              ],
              onChanged: (val) => setState(() => _idiomaSeleccionado = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<int>(
              initialValue: _medidaSeleccionada, // <--- Cambiado aquí
              decoration: const InputDecoration(labelText: 'Sistema de Medida', prefixIcon: Icon(Icons.straighten), border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 301, child: Text('Métrico (km, m, °C)')),
                DropdownMenuItem(value: 302, child: Text('Imperial (mi, ft, °F)')),
              ],
              onChanged: (val) => setState(() => _medidaSeleccionada = val!),
            ),
            const SizedBox(height: 30),
            _loading ? const CircularProgressIndicator() : ElevatedButton(
              onPressed: _signUp,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F988A), minimumSize: const Size(double.infinity, 55)),
              child: const Text('Registrarse', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String l, IconData i, {bool hide = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(controller: c, obscureText: hide, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: const Color(0xFF0F988A)), border: const OutlineInputBorder())),
  );
}