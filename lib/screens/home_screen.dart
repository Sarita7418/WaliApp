import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'explore_view.dart';
import 'itinerary_view.dart';
import 'diary_screen.dart';
import 'chat_view.dart';
import 'profile_view.dart';
import 'rates_view.dart';
import 'ocr_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // Guardamos los datos del itinerario para pasarlos a la vista dinámica
  Map<String, dynamic>? _itinerarioData;

  // Colores WALI
  final Color brandTeal = const Color(0xFF0F988A);
  final Color brandOrange = const Color(0xFFF57C00);

  // --- LÓGICA DE NAVEGACIÓN INTERNA ---
  Future<void> _gestionarItinerario() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Pequeño feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sincronizando itinerario...'), duration: Duration(milliseconds: 800)),
    );

    try {
      final data = await Supabase.instance.client
          .from('itinerarios')
          .select('''
            *,
            itinerario_dias (
              id,
              numero_dia,
              fecha_calendario,
              itinerario_actividades (
                id,
                nombre,
                hora_inicio,
                hora_fin,
                precio,
                es_prioridad,
                notas_usuario
              )
            )
          ''')
          .eq('id_persona', user.id)
          .maybeSingle();

      setState(() {
        _itinerarioData = data;
        // Si hay datos, el "módulo" mostrará DiaryScreen, si no, ItineraryView
        // Pero ambos vivirán en la misma posición de la barra
        _currentIndex = 6; // Activamos la vista de itinerarios
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _currentIndex = 6); // Fallback al formulario de creación
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las vistas aquí para poder pasar _itinerarioData dinámicamente
    final List<Widget> views = [
      const ExploreView(),                 // 0
      const Center(child: Text("Rutas")),  // 1 (Módulo independiente)
      const ChatView(),                    // 2
      const ProfileView(),                 // 3
      const RatesView(),                   // 4
      const OcrView(),                     // 5
      // 6: EL MÓDULO DINÁMICO DE ITINERARIOS
      _itinerarioData != null 
          ? DiaryScreen(itinerarioData: _itinerarioData!) 
          : const ItineraryView(),
    ];

    return Scaffold(
      // IndexedStack mantiene el estado y la barra inferior visible
      body: IndexedStack(
        index: _currentIndex,
        children: views,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showModulesMenu,
        backgroundColor: brandTeal,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, "Inicio", 0),
              _buildNavItem(Icons.map_outlined, "Rutas", 1),
              const SizedBox(width: 40),
              _buildNavItem(Icons.smart_toy_outlined, "Wali IA", 2),
              _buildNavItem(Icons.person_outline, "Perfil", 3),
            ],
          ),
        ),
      ),
    );
  }

  void _showModulesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Color(0xFFF2FBFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                children: [
                  _buildModuleItem(Icons.route_rounded, "Itinerarios", brandTeal, () {
                    Navigator.pop(context);
                    _gestionarItinerario(); // Dispara la lógica interna
                  }),
                  _buildModuleItem(Icons.payments_outlined, "Tarifas", brandOrange, () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 4);
                  }),
                  _buildModuleItem(Icons.camera_alt_rounded, "Cámara OCR", const Color(0xFFE64A19), () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 5);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    // Si estamos en Itinerarios (6), no resaltamos ninguna de la barra inferior
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? brandTeal : Colors.black38),
          Text(label, style: TextStyle(color: isSelected ? brandTeal : Colors.black38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildModuleItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}