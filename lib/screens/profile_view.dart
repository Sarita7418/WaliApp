// lib/screens/profile_view.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nombres = TextEditingController();
  final _apPaterno = TextEditingController();
  final _apMaterno = TextEditingController();
  final _tel = TextEditingController();
  
  int _idiomaFav = 201;
  int _medidaFav = 301;
  DateTime? _fechaNac;
  bool _isLoading = true;
  late int _personaId; // ID de la fila en tabla personas

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    final data = await Supabase.instance.client.from('personas').select().eq('id_usuario', user!.id).single();
    
    setState(() {
      _personaId = data['id'];
      _nombres.text = data['nombres'] ?? '';
      _apPaterno.text = data['apellido_paterno'] ?? '';
      _apMaterno.text = data['apellido_materno'] ?? '';
      _tel.text = data['telefono'] ?? '';
      _idiomaFav = data['id_idioma_fav'] ?? 201;
      _medidaFav = data['id_sistema_medida'] ?? 301;
      if (data['fecha_nacimiento'] != null) {
        _fechaNac = DateTime.parse(data['fecha_nacimiento']);
      }
      _isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    try {
      await Supabase.instance.client.from('personas').update({
        'nombres': _nombres.text,
        'apellido_paterno': _apPaterno.text,
        'apellido_materno': _apMaterno.text,
        'telefono': _tel.text,
        'fecha_nacimiento': _fechaNac?.toIso8601String().split('T')[0],
        'id_idioma_fav': _idiomaFav,
        'id_sistema_medida': _medidaFav,
      }).eq('id', _personaId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Datos guardados con éxito!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF388E3C)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF388E3C)));

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil'), backgroundColor: const Color(0xFF388E3C), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  const CircleAvatar(radius: 50, backgroundColor: Color(0xFF388E3C), child: Icon(Icons.person, size: 50, color: Colors.white)),
                  CircleAvatar(radius: 18, backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.camera_alt, size: 15, color: Color(0xFF388E3C)), onPressed: () {})),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            const Text('Información Personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
            const SizedBox(height: 15),
            _buildInput(_nombres, 'Nombres', Icons.badge),
            _buildInput(_apPaterno, 'Apellido Paterno', Icons.person),
            _buildInput(_apMaterno, 'Apellido Materno', Icons.person_outline),
            _buildInput(_tel, 'Teléfono', Icons.phone),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_fechaNac == null ? 'Fecha Nacimiento' : 'Nacimiento: ${_fechaNac!.toLocal()}'.split(' ')[0]),
              leading: const Icon(Icons.calendar_today, color: Color(0xFF388E3C)),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _fechaNac ?? DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
                if (date != null) setState(() => _fechaNac = date);
              },
            ),

            const Divider(height: 40),
            const Text('Preferencias de Aplicación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
            const SizedBox(height: 15),
            
            DropdownButtonFormField<int>(
              initialValue: _idiomaFav, // <--- Cambiado aquí
              decoration: const InputDecoration(labelText: 'Idioma Preferido', prefixIcon: Icon(Icons.language), border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 201, child: Text('Español')),
                DropdownMenuItem(value: 202, child: Text('Inglés')),
                DropdownMenuItem(value: 203, child: Text('Portugués')),
                DropdownMenuItem(value: 204, child: Text('Aymara')),
              ],
              onChanged: (val) => setState(() => _idiomaFav = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<int>(
              initialValue: _medidaFav, // <--- Cambiado aquí
              decoration: const InputDecoration(labelText: 'Sistema de Medida', prefixIcon: Icon(Icons.straighten), border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 301, child: Text('Métrico (km, m, °C)')),
                DropdownMenuItem(value: 302, child: Text('Imperial (mi, ft, °F)')),
              ],
              onChanged: (val) => setState(() => _medidaFav = val!),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C), minimumSize: const Size(double.infinity, 50)),
              child: const Text('Actualizar Datos', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                // Corrección del BuildContext asíncrono
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                }
              },
              child: const Center(child: Text('Cerrar Sesión', style: TextStyle(color: Colors.red, fontSize: 16))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String l, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextField(controller: c, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: const Color(0xFF388E3C)), border: const OutlineInputBorder())),
  );
}