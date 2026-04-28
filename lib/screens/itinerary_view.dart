import 'package:flutter/material.dart';

class ItineraryView extends StatelessWidget {
  const ItineraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus Itinerarios IA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Ruta sugerida para hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFF0F988A).withValues(alpha: 0.1),
            child: const ListTile(
              leading: Icon(Icons.auto_awesome, color: Color(0xFF0F988A)),
              title: Text('Día 1: Centro Histórico'),
              subtitle: Text('Generado por Wali IA basado en tus gustos'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
          ),
        ],
      ),
    );
  }
}