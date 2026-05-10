import 'package:flutter/material.dart';

class ItineraryView extends StatelessWidget {
  const ItineraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Itinerarios Inteligentes"), backgroundColor: const Color(0xFF0F988A), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildRouteCard("Ruta del Casco Viejo", "45 min", Icons.history_toggle_off),
          _buildRouteCard("Circuito de Miradores", "2 h 30 min", Icons.landscape),
          _buildRouteCard("Tour Gastronómico", "3 h", Icons.restaurant),
        ],
      ),
    );
  }

  Widget _buildRouteCard(String title, String time, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0F988A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Tiempo estimado: $time"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}