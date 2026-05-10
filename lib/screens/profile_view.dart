import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});
  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // Controladores Usuario
  final _nombres = TextEditingController();
  final _apPaterno = TextEditingController();
  final _apMaterno = TextEditingController();
  final _tel = TextEditingController();
  
  // Controladores Emergencia
  final _emNombre = TextEditingController();
  final _emTel = TextEditingController();
  final _emParentesco = TextEditingController();
  
  bool _isEditing = false;
  bool _isLoading = true;
  bool _hasEmergencyContact = false; 
  
  String _userEmail = "";
  String _avatarUrl = 'https://via.placeholder.com/150'; // Imagen por defecto
  int _idIdioma = 201; 
  int _idMedida = 301;
  DateTime? _fechaNac;
  late int _personaId;

  final Color brandTeal = const Color(0xFF0F988A);
  final Color brandOrange = const Color(0xFFF57C00);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      _userEmail = user?.email ?? "";
      
      final data = await Supabase.instance.client
          .from('personas')
          .select('*, contactos_emergencia(*)')
          .eq('id_usuario', user!.id)
          .maybeSingle();
      
      if (data != null) {
        setState(() {
          _avatarUrl = data['avatar_url'] ?? 'https://via.placeholder.com/150';
          _personaId = data['id'];
          _nombres.text = data['nombres'] ?? '';
          _apPaterno.text = data['apellido_paterno'] ?? '';
          _apMaterno.text = data['apellido_materno'] ?? '';
          _tel.text = data['telefono'] ?? '';
          _idIdioma = data['id_idioma_fav'] ?? 201;
          _idMedida = data['id_sistema_medida'] ?? 301;
          
          if (data['fecha_nacimiento'] != null) {
            _fechaNac = DateTime.parse(data['fecha_nacimiento']);
          }

          final emData = data['contactos_emergencia'];
          if (emData != null && emData.isNotEmpty) {
            final contact = emData[0];
            _emNombre.text = contact['nombre_contacto'] ?? '';
            _emTel.text = contact['telefono'] ?? '';
            _emParentesco.text = contact['parentesco'] ?? '';
            _hasEmergencyContact = true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
// --- FUNCIÓN PARA GUARDAR LOS DATOS (¡La que faltaba!) ---
  Future<void> _updateProfile() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Actualizar tabla Personas (Datos, Idioma y Medida)
      await Supabase.instance.client.from('personas').update({
        'nombres': _nombres.text.trim(),
        'apellido_paterno': _apPaterno.text.trim(),
        'apellido_materno': _apMaterno.text.trim(),
        'telefono': _tel.text.trim(),
        'fecha_nacimiento': _fechaNac?.toIso8601String().split('T')[0],
        'id_idioma_fav': _idIdioma,
        'id_sistema_medida': _idMedida,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _personaId);

      // 2. Manejar tabla Contactos de Emergencia
      final emPayload = {
        'nombre_contacto': _emNombre.text.trim(),
        'telefono': _emTel.text.trim(),
        'parentesco': _emParentesco.text.trim(),
        'id_persona': _personaId,
      };

      if (_hasEmergencyContact) {
        await Supabase.instance.client.from('contactos_emergencia').update(emPayload).eq('id_persona', _personaId);
      } else {
        await Supabase.instance.client.from('contactos_emergencia').insert(emPayload);
        _hasEmergencyContact = true; // Ya tiene contacto para la próxima
      }

      if (mounted) {
        setState(() {
          _isEditing = false; // Vuelve al modo lectura
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Datos guardados con éxito!'), backgroundColor: Color(0xFF0F988A)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  Future<void> _uploadProfilePicture() async {
    try {
      // 1. Abrir la galería para seleccionar la imagen
      final picker = ImagePicker();
      final XFile? imageFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600, // Comprimimos un poco para ahorrar datos
        maxHeight: 600,
      );

      if (imageFile == null) return; // Si el usuario cancela, no hacemos nada

      setState(() => _isLoading = true);

      // 2. Preparar el archivo y el nombre para Supabase
      final file = File(imageFile.path);
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$_personaId/$fileName'; // Guardamos en una carpeta con el ID del usuario

      // 3. Subir la imagen al Bucket 'avatars'
      await Supabase.instance.client.storage.from('avatars').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      // 4. Obtener la URL pública de la imagen recién subida
      final String publicUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);

      // 5. Actualizar la tabla 'personas' con la nueva URL
      await Supabase.instance.client.from('personas').update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _personaId);

      // 6. Actualizar la interfaz
      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto de perfil actualizada!'), backgroundColor: Color(0xFF0F988A)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: brandTeal));

    return Scaffold(
      backgroundColor: const Color(0xFFF2FBFF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopHeader(),
            _buildAvatarSection(),
            _buildStatsGrid(),

            _buildSectionHeader("Información Personal"),
            if (!_isEditing) _buildViewPersonal() else _buildEditPersonal(),

            _buildSectionHeader("Contacto de Emergencia"),
            if (!_isEditing) _buildViewEmergency() else _buildEditEmergency(),

            _buildSectionHeader("Preferencias"),
            if (!_isEditing) _buildViewPrefs() else _buildEditPrefs(),

            _buildActionButtons(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- VISTAS DE LECTURA (Aquí añadimos los teléfonos) ---
  Widget _buildViewPersonal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(children: [
        _infoTile(Icons.person_outline, "Nombre", "${_nombres.text} ${_apPaterno.text}"),
        _infoTile(Icons.phone_android, "Mi Teléfono", _tel.text.isEmpty ? "No registrado" : _tel.text),
        _infoTile(Icons.calendar_today, "Nacimiento", _fechaNac == null ? "No registrado" : "${_fechaNac!.day}/${_fechaNac!.month}/${_fechaNac!.year}"),
      ]),
    );
  }

  Widget _buildViewEmergency() {
    if (!_hasEmergencyContact) return _noEmergencyAlert();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(children: [
        _infoTile(Icons.contact_emergency, "Contacto", "${_emNombre.text} (${_emParentesco.text})"),
        _infoTile(Icons.phone_forwarded, "Teléfono Emergencia", _emTel.text),
      ]),
    );
  }

  Widget _buildViewPrefs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(children: [
        _infoTile(Icons.language, "Idioma", _idIdioma == 201 ? "Español" : "Inglés"),
        _infoTile(Icons.straighten, "Sistema", _idMedida == 301 ? "Métrico" : "Imperial"),
      ]),
    );
  }

  // --- VISTAS DE EDICIÓN ---
  Widget _buildEditPersonal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        _modernInput(_nombres, "Nombres", Icons.badge_outlined),
        _modernInput(_apPaterno, "Apellido Paterno", Icons.person_outline),
        _modernInput(_tel, "Mi Teléfono", Icons.phone_android),
        _buildDatePicker(),
      ]),
    );
  }

  Widget _buildEditEmergency() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        _modernInput(_emNombre, "Nombre Contacto", Icons.contact_emergency),
        _modernInput(_emTel, "Teléfono de Emergencia", Icons.phone_forwarded),
        _modernInput(_emParentesco, "Parentesco", Icons.family_restroom),
      ]),
    );
  }

  Widget _buildEditPrefs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        _dropdownBox(label: "Idioma", icon: Icons.language, child: DropdownButton<int>(
          value: _idIdioma, isExpanded: true, underline: const SizedBox(),
          items: const [DropdownMenuItem(value: 201, child: Text("Español")), DropdownMenuItem(value: 202, child: Text("Inglés"))],
          onChanged: (v) => setState(() => _idIdioma = v!),
        )),
        const SizedBox(height: 10),
        _dropdownBox(label: "Medida", icon: Icons.straighten, child: DropdownButton<int>(
          value: _idMedida, isExpanded: true, underline: const SizedBox(),
          items: const [DropdownMenuItem(value: 301, child: Text("Métrico (km, °C)")), DropdownMenuItem(value: 302, child: Text("Imperial (mi, °F)"))],
          onChanged: (v) => setState(() => _idMedida = v!),
        )),
      ]),
    );
  }

  // --- COMPONENTES UI ---
  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Icon(icon, color: brandTeal, size: 20),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black45)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _modernInput(TextEditingController ctrl, String hint, IconData icon) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: TextField(controller: ctrl, decoration: InputDecoration(labelText: hint, icon: Icon(icon, color: brandTeal), border: InputBorder.none)));

  Widget _dropdownBox({required String label, required IconData icon, required Widget child}) => Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(icon, color: brandTeal), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)), child]))]));

  Widget _buildDatePicker() => GestureDetector(onTap: _pickDate, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.calendar_month, color: brandTeal), const SizedBox(width: 15), Text(_fechaNac == null ? "Fecha de Nacimiento" : "${_fechaNac!.day}/${_fechaNac!.month}/${_fechaNac!.year}")])));

  Widget _noEmergencyAlert() => Container(margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 5), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: brandOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)), child: const Text("⚠️ Sin contacto de emergencia.", style: TextStyle(fontSize: 12, color: Colors.orange)));

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _fechaNac ?? DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
    if (date != null) setState(() => _fechaNac = date);
  }

  Widget _buildTopHeader() => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Hola, Explorer 👋', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00685E))), const Icon(Icons.search, color: Colors.black45)])));
 Widget _buildAvatarSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _uploadProfilePicture, // <--- Llama a la función al tocar
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50, 
                backgroundColor: Colors.grey[300],
                backgroundImage: NetworkImage(_avatarUrl), // <--- Usa la variable dinámica
              ),
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 16, 
                backgroundColor: brandTeal, 
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white), // Cambié a icono de cámara
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text("${_nombres.text} ${_apPaterno.text}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(_userEmail, style: const TextStyle(color: Colors.black45, fontSize: 12))
      ],
    );
  }
  Widget _buildStatsGrid() => Padding(padding: const EdgeInsets.all(20), child: Row(children: [_statBox("24", "VISITAS", brandTeal, Icons.location_on), const SizedBox(width: 15), _statBox("1,250", "KM", brandOrange, Icons.route)]));
  Widget _statBox(String val, String label, Color col, IconData icon) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: col, size: 18), const SizedBox(height: 5), Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 8, color: Colors.black45))])));
  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.fromLTRB(25, 20, 20, 10), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))));
  
  Widget _buildActionButtons() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    if (!_isEditing) ElevatedButton(onPressed: () => setState(() => _isEditing = true), style: ElevatedButton.styleFrom(backgroundColor: brandTeal, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("Editar Perfil", style: TextStyle(color: Colors.white)))
    else Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditing = false), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("Cancelar"))),
      const SizedBox(width: 15),
      Expanded(child: ElevatedButton(onPressed: _updateProfile, style: ElevatedButton.styleFrom(backgroundColor: brandTeal, minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("Guardar", style: TextStyle(color: Colors.white)))),
    ]),
    TextButton(onPressed: _signOut, child: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent))),
  ]));

  Future<void> _signOut() async { await Supabase.instance.client.auth.signOut(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }
}