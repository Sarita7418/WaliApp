import 'package:flutter/material.dart';
import 'explore_view.dart';
import 'itinerary_view.dart';
import 'chat_view.dart';
import 'profile_view.dart';
import 'gastro_view.dart'; // Ahora se llamará desde el "+"

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Los 4 pilares de la barra inferior (dejando el centro para el +)
  final List<Widget> _views = [
    const ExploreView(),   // 0
    const ItineraryView(), // 1
    const ChatView(),      // 2
    const ProfileView(),   // 3
  ];

  // Colores de tu marca WALI
  final Color brandTeal = const Color(0xFF0F988A);
  final Color brandOrange = const Color(0xFFF57C00);

  // Función para abrir el menú de módulos faltantes
  void _showModulesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Color(0xFFF2FBFF), // Fondo celeste muy claro (surface)
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("Módulos Adicionales", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00685E))),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                mainAxisSpacing: 20,
                children: [
                  // Módulo Gastro (que pediste integrar)
                  _buildModuleItem(Icons.restaurant, "Gastronomía", const Color(0xFFE64A19), () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const GastroView()));
                  }),
                  // Módulos que faltaban según tu diseño HTML
                  _buildModuleItem(Icons.museum, "Cultura", Colors.brown, () {}),
                  _buildModuleItem(Icons.translate, "Traductor", Colors.blueAccent, () {}),
                  _buildModuleItem(Icons.emergency_share, "S.O.S", Colors.red, () {}),
                  _buildModuleItem(Icons.history_edu, "Historia", Colors.amber, () {}),
                  _buildModuleItem(Icons.settings_outlined, "Ajustes", Colors.grey, () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos IndexedStack para que no se pierda el progreso al cambiar de pestaña
      body: IndexedStack(
        index: _currentIndex,
        children: _views,
      ),

      // BOTÓN CENTRAL "+" (Explora)
      floatingActionButton: FloatingActionButton(
        onPressed: _showModulesMenu,
        backgroundColor: brandTeal,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // BARRA INFERIOR MODERNA
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, "Inicio", 0),
              _buildNavItem(Icons.map_outlined, "Rutas", 1),
              const SizedBox(width: 40), // Espacio para el FloatingActionButton
              _buildNavItem(Icons.smart_toy_outlined, "Wali IA", 2),
              _buildNavItem(Icons.person_outline, "Perfil", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? brandTeal : Colors.black38, size: 26),
          Text(label, style: TextStyle(color: isSelected ? brandTeal : Colors.black38, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}