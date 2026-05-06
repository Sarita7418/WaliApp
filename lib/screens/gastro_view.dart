import 'package:flutter/material.dart';

class GastroView extends StatelessWidget {
  const GastroView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guía Gastronómica')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _buildGastroCard('Platos Típicos', Icons.restaurant_menu),
          _buildGastroCard('Escaneo OCR', Icons.camera_alt),
          _buildGastroCard('Mercados', Icons.shopping_basket),
          _buildGastroCard('Alérgenos', Icons.warning_amber),
        ],
      ),
    );
  }

  Widget _buildGastroCard(String title, IconData icon) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: const Color(0xFF0F988A)),
          const SizedBox(height: 10),
          Text(title),
        ],
      ),
    );
  }
}