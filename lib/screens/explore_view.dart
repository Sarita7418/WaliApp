import 'package:flutter/material.dart';

class ExploreView extends StatelessWidget {
  const ExploreView({super.key});

  // Colores extraídos de tu diseño Tailwind
  static const Color primaryColor = Color(0xFF00685E);
  static const Color backgroundColor = Color(0xFFF2FBFF);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color errorText = Color(0xFFBA1A1A);
  static const Color orangeWali = Color(0xFFFF9C3C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. TopAppBar con efecto de desenfoque
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: false,
            backgroundColor: Colors.white.withValues(alpha: 0.5),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFD0E6EF),
                          backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Hola, Explorer 👋',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontFamily: 'SpaceGrotesk', // Asegúrate de tenerla en pubspec
                          ),
                        ),
                      ],
                    ),
                    Image.asset('assets/images/logoWALI.jpeg', height: 32),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Search Bar
                  _buildSearchBar(),
                  const SizedBox(height: 30),

                  // 3. Categorías (Horizontal)
                  _buildCategories(),
                  const SizedBox(height: 30),

                  // 4. Destacados en La Paz (Horizontal Cards)
                  _buildSectionHeader("Destacados en La Paz"),
                  const SizedBox(height: 15),
                  _buildHighlightsList(),
                  const SizedBox(height: 30),

                  // 5. Recomendado para ti
                  _buildSectionHeader("Recomendado para ti"),
                  const SizedBox(height: 15),
                  _buildRecommendedCard(),
                  const SizedBox(height: 30),

                  // 6. Zonas de Riesgo (Alertas Rojas)
                  _buildSectionHeader("Zonas de Riesgo"),
                  const SizedBox(height: 15),
                  _buildRiskAlert("Bloqueo en Plaza Murillo", "Manifestaciones reportadas. Evitar la zona.", Icons.warning),
                  const SizedBox(height: 12),
                  _buildRiskAlert("Trabajos en Av. Arce", "Cierre parcial de vías. Tráfico lento.", Icons.block),
                  const SizedBox(height: 30),

                  // 7. Grid Final (Mercado Lanza + WALI AI)
                  _buildFinalGrid(),
                  const SizedBox(height: 100), // Espacio para el menú inferior
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE SOPORTE ---

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: '¿Qué quieres explorar hoy?',
          prefixIcon: Icon(Icons.search, color: Colors.black54),
          suffixIcon: Icon(Icons.tune, color: primaryColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _categoryItem(Icons.map, "Mapa Cultural", const Color(0xFF008377)),
          _categoryItem(Icons.headphones, "Audioguía", orangeWali),
          _categoryItem(Icons.restaurant, "Gastronomía", const Color(0xFFAB604C)),
          _categoryItem(Icons.route, "Itinerarios", const Color(0xFFFEC636)),
        ],
      ),
    );
  }

  Widget _categoryItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHighlightsList() {
    return SizedBox(
      height: 220,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _highlightCard("Mi Teleférico", "La Paz, Bolivia", "4.9", 'assets/images/teleferico.jpg'),
          _highlightCard("Valle de la Luna", "Mallasa, La Paz", "4.8", 'assets/images/valle.jpg'),
        ],
      ),
    );
  }

  Widget _highlightCard(String title, String sub, String rate, String img) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.grey[300]),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(img, fit: BoxFit.cover),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)]))),
          Positioned(top: 10, right: 10, child: CircleAvatar(backgroundColor: Colors.white70, radius: 15, child: Icon(Icons.favorite, size: 16, color: primaryColor))),
          Positioned(
            bottom: 15, left: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(children: [const Icon(Icons.location_on, color: Colors.white70, size: 12), Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAlert(String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: errorText.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: errorContainer, child: Icon(icon, color: errorText)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCard() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: Image.asset('assets/images/sagarnaga.jpg', width: double.infinity, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Calle Sagárnaga", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Mercado de Brujas", style: TextStyle(fontSize: 12, color: Colors.black38)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [Icon(Icons.star, color: Color(0xFFFEC636), size: 14), Text(" 4.7", style: TextStyle(fontWeight: FontWeight.bold))]),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFinalGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 150,
            decoration: BoxDecoration(color: surfaceLowest, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: Image.asset('assets/images/lanza.jpg', fit: BoxFit.cover))),
                const Padding(padding: EdgeInsets.all(8.0), child: Text("Mercado Lanza", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Container(
            height: 150,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF1F333A), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF69D9C9)),
                const Text("Crea tu itinerario ideal con WALI AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF69D9C9), foregroundColor: Colors.black, textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  child: const Text("Probar ahora"),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'SpaceGrotesk', color: Color(0xFF091E25)));
  }
}