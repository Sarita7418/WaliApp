// lib/screens/explore_view.dart
import 'package:flutter/material.dart';

class ExploreView extends StatelessWidget {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('Wali La Paz', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {})],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de búsqueda moderna
                TextField(
                  decoration: InputDecoration(
                    hintText: '¿A dónde vamos hoy?',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 25),
                const Text('Categorías', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildCategories(),
                const SizedBox(height: 25),
                const Text('Recomendado para ti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                _buildPlaceCard(context, 'Mirador Killi Killi', 'Vista 360° de la ciudad', '4.9', 'Gratis'),
                _buildPlaceCard(context, 'Valle de la Luna', 'Formaciones geológicas únicas', '4.7', '15 BOB'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    final categories = ['Museos', 'Miradores', 'Teleféricos', 'Gastronomía', 'Vida Nocturna'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, i) => Container(
          margin: const EdgeInsets.only(right: 10),
          child: Chip(
            label: Text(categories[i]),
            backgroundColor: const Color(0xFF0F988A).withValues(alpha: 0.1),
            side: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, String title, String sub, String rating, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: Colors.grey[300], // Aquí iría la imagen
            ),
            child: const Center(child: Icon(Icons.image, size: 50, color: Colors.white)),
          ),
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(sub),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                // Módulo 8: Tarifas recomendadas
                Text(price, style: const TextStyle(color: Color(0xFF0F988A), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}