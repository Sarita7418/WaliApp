// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'explore_view.dart';
import 'itinerary_view.dart';
import 'chat_view.dart';
import 'gastro_view.dart';
import 'profile_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const ExploreView(),
    const ItineraryView(),
    const ChatView(),
    const GastroView(),
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _views[_currentIndex],
      // Menú inferior con colores representativos por módulo
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.shifting, // Permite colores de fondo por ítem
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          // Módulo Mapas/Audioguías: Turquesa Wali
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explora', backgroundColor: Color(0xFF0F988A)),
          // Módulo Itinerarios: Naranja Aventura
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Rutas', backgroundColor: Color(0xFFF57C00)),
          // Módulo IA: Morado Tecnológico
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'Wali IA', backgroundColor: Color(0xFF7B1FA2)),
          // Módulo Gastro: Rojo Coral
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Gastro', backgroundColor: Color(0xFFE64A19)),
          // Módulo Perfil: Verde Andino
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil', backgroundColor: Color(0xFF388E3C)),
        ],
      ),
    );
  }
}