import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'explore_view.dart';
import 'itinerary_view.dart';
import 'routes_view.dart';
import 'chat_view.dart';
import 'profile_view.dart';
import 'rates_view.dart';
import 'ocr_view.dart';

// ─────────────────────────────────────────
//  MODELOS DE DATOS
// ─────────────────────────────────────────

class PuntoTuristico {
  final int id;
  final String nombre;
  final String descripcion;
  final String? imagenUrl;
  final double? precioNacional;
  final int idCategoria;

  const PuntoTuristico({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.imagenUrl,
    this.precioNacional,
    required this.idCategoria,
  });

  factory PuntoTuristico.fromMap(Map<String, dynamic> map) {
    return PuntoTuristico(
      id: map['id'] as int,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      imagenUrl: map['imagen_url'] as String?,
      precioNacional: (map['precio_nacional'] as num?)?.toDouble(),
      idCategoria: map['id_categoria'] as int? ?? 0,
    );
  }
}

class Ruta {
  final int id;
  final String nombre;
  final String descripcion;
  final bool iaGenerado;
  final int idTipoRuta;

  const Ruta({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.iaGenerado,
    required this.idTipoRuta,
  });

  factory Ruta.fromMap(Map<String, dynamic> map) {
    return Ruta(
      id: map['id'] as int,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      iaGenerado: map['ia_generado'] as bool? ?? false,
      idTipoRuta: map['id_tipo_ruta'] as int? ?? 0,
    );
  }
}

class ZonaRiesgo {
  final int id;
  final String nombre;
  final String descripcion;
  final int idNivelRiesgo;

  const ZonaRiesgo({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.idNivelRiesgo,
  });

  factory ZonaRiesgo.fromMap(Map<String, dynamic> map) {
    return ZonaRiesgo(
      id: map['id'] as int,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      idNivelRiesgo: map['id_nivel_riesgo'] as int? ?? 0,
    );
  }
}

// ─────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  // ── COLORES MARCA WALI ──
  static const Color bgLight        = Color(0xFFF2FBFF);
  static const Color brandTeal      = Color(0xFF0F988A);
  static const Color brandEmerald   = Color(0xFF197D61);
  static const Color brandAmber     = Color(0xFFD27817);
  static const Color brandTerracota = Color(0xFF7A3928);
  static const Color brandOrange    = Color(0xFFF25C05);
  static const Color brandOrangeOld = Color(0xFFF57C00);
  static const Color brandDark      = Color(0xFF23373E);

  // ── DATOS ──
  bool _isLoading = true;
  List<PuntoTuristico> _allPuntos = [];
  List<Ruta> _allRutas = [];
  List<ZonaRiesgo> _zonas = [];
  String? _error;

  // ── NOMBRE DE USUARIO desde tabla personas ──
  String _userName = '';

  // ── FILTROS (IDs del diccionario de datos WALI) ──
  final List<_CategoryFilter> _categories = const [
    _CategoryFilter(label: 'Cultural',    icon: Icons.account_balance_rounded, categoriaIds: [401, 405], tipoRutaIds: [701]),
    _CategoryFilter(label: 'Gastronomía', icon: Icons.restaurant_rounded,      categoriaIds: [406],      tipoRutaIds: [702]),
    _CategoryFilter(label: 'Historia',    icon: Icons.history_edu_rounded,      categoriaIds: [401, 403], tipoRutaIds: [701]),
    _CategoryFilter(label: 'Miradores',   icon: Icons.landscape_rounded,        categoriaIds: [402],      tipoRutaIds: [703]),
    _CategoryFilter(label: 'Compras',     icon: Icons.shopping_bag_rounded,     categoriaIds: [406, 407], tipoRutaIds: [704]),
    _CategoryFilter(label: 'Teleférico',  icon: Icons.cable_rounded,            categoriaIds: [404],      tipoRutaIds: [703]),
  ];

  int _selectedCategory = 0;
  late final PageController _cardController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  // Auto-scroll
  late final AnimationController _autoScrollController;

  // Búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cardController = PageController(viewportFraction: 0.84);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _autoScrollController = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _autoScrollController.reset();
          if (_cardController.hasClients) {
            final currentPage = _cardController.page?.round() ?? 0;
            final itemCount = _filteredCards.length;
            if (itemCount > 1) {
              final nextPage = (currentPage + 1) % itemCount;
              _cardController.animateToPage(
                nextPage,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
              );
            }
          }
          _autoScrollController.forward();
        }
      });
    _fetchData();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    _autoScrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────
  //  SUPABASE: Carga de datos
  // ─────────────────────────────────────
  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final sb = Supabase.instance.client;

      // ── Cargar nombre del usuario desde tabla personas ──
      final userId = sb.auth.currentUser?.id;
      if (userId != null) {
        final personaRes = await sb
            .from('personas')
            .select('nombres')
            .eq('id_usuario', userId)
            .maybeSingle();
        if (personaRes != null) {
          final nombres = personaRes['nombres'] as String? ?? '';
          // Tomar solo el primer nombre
          _userName = nombres.split(' ').first;
        }
      }

      final pRes = await sb
          .from('punto_turistico')
          .select('id, nombre, descripcion, imagen_url, precio_nacional, id_categoria')
          .eq('estado', true)
          .order('nombre');

      final rRes = await sb
          .from('rutas')
          .select('id, nombre, descripcion, ia_generado, id_tipo_ruta')
          .eq('estado', true)
          .order('nombre');

      final zRes = await sb
          .from('zonas_riesgo')
          .select('id, nombre, descripcion, id_nivel_riesgo')
          .eq('estado', true)
          .order('id_nivel_riesgo', ascending: false)
          .limit(6);

      if (!mounted) return;
      setState(() {
        _allPuntos = (pRes as List).map((e) => PuntoTuristico.fromMap(e)).toList();
        _allRutas  = (rRes  as List).map((e) => Ruta.fromMap(e)).toList();
        _zonas     = (zRes  as List).map((e) => ZonaRiesgo.fromMap(e)).toList();
        _isLoading = false;
      });
      _fadeController.forward();
      // Iniciar auto-scroll solo si hay más de 1 card
      if (_filteredCards.length > 1) {
        _autoScrollController.forward();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ─────────────────────────────────────
  //  FILTRADO DINÁMICO
  // ─────────────────────────────────────
  List<_CardItem> get _filteredCards {
    final cat = _categories[_selectedCategory];
    final q   = _searchQuery.toLowerCase();
    final List<_CardItem> cards = [];

    for (final p in _allPuntos) {
      if (!cat.categoriaIds.contains(p.idCategoria)) continue;
      if (q.isNotEmpty && !p.nombre.toLowerCase().contains(q) && !p.descripcion.toLowerCase().contains(q)) continue;
      cards.add(_CardItem.fromPunto(p));
    }
    for (final r in _allRutas) {
      if (!cat.tipoRutaIds.contains(r.idTipoRuta)) continue;
      if (q.isNotEmpty && !r.nombre.toLowerCase().contains(q) && !r.descripcion.toLowerCase().contains(q)) continue;
      cards.add(_CardItem.fromRuta(r));
    }

    if (cards.isEmpty && q.isEmpty) {
      _allPuntos.take(6).forEach((p) => cards.add(_CardItem.fromPunto(p)));
      _allRutas.take(3).forEach((r)  => cards.add(_CardItem.fromRuta(r)));
    }
    return cards;
  }

  List<PuntoTuristico> get _destacados {
    final q = _searchQuery.toLowerCase();
    if (q.isEmpty) return _allPuntos.take(8).toList();
    return _allPuntos
        .where((p) => p.nombre.toLowerCase().contains(q) || p.descripcion.toLowerCase().contains(q))
        .toList();
  }

  void _onCategoryTap(int index) {
    if (_selectedCategory == index) return;
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _selectedCategory = index);
      try { _cardController.jumpToPage(0); } catch (_) {}
      _fadeController.forward();
      // Reiniciar auto-scroll al cambiar categoría
      _autoScrollController.reset();
      if (_filteredCards.length > 1) _autoScrollController.forward();
    });
  }

  // ─────────────────────────────────────
  //  MENÚ MÓDULOS
  // ─────────────────────────────────────
  void _showModulesMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: brandTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.keyboard_arrow_down_rounded, color: brandTeal, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildModuleItem(Icons.route_rounded, 'Itinerarios', brandTeal, () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 6);
                }),
                _buildModuleItem(Icons.payments_outlined, 'Tarifas', brandOrangeOld, () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 4);
                }),
                _buildModuleItem(Icons.camera_alt_rounded, 'Cámara OCR', const Color(0xFFE64A19), () {
                  Navigator.pop(context);
                  setState(() => _currentIndex = 5);
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildModuleItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  BUILD PRINCIPAL
  // ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),       // 0 — Inicio
          const RoutesView(),    // 1 — Mapas (barra de navegación)
          const ChatView(),      // 2 — Wali IA
          const ProfileView(),   // 3 — Perfil
          const RatesView(),     // 4 — Tarifas (menú +)
          const OcrView(),       // 5 — Cámara OCR (menú +)
          const ItineraryView(), // 6 — Itinerarios (menú +)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showModulesMenu,
        backgroundColor: brandTeal,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.white,
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 60,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _buildNavItem(Icons.home_filled,        'Inicio',  0),
            _buildNavItem(Icons.map_outlined,       'Mapas',   1),
            const SizedBox(width: 40),
            _buildNavItem(Icons.smart_toy_outlined, 'Wali IA', 2),
            _buildNavItem(Icons.person_outline,     'Perfil',  3),
          ]),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: isSelected ? brandTeal : Colors.black38, size: 26),
        Text(label, style: TextStyle(
          color: isSelected ? brandTeal : Colors.black38,
          fontSize: 10, fontWeight: FontWeight.bold,
        )),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  HOME TAB
  // ─────────────────────────────────────
  Widget _buildHomeTab() {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1️⃣ Encabezado de la app (logo/iconos) — PRIMERO
          SliverToBoxAdapter(child: _buildAppHeader()),
          // 2️⃣ Saludo con nombre real del usuario
          SliverToBoxAdapter(child: _buildGreeting()),
          // 3️⃣ Barra de búsqueda — DEBAJO del saludo
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategoryFilters()),
          SliverToBoxAdapter(child: _buildCarousel()),
          SliverToBoxAdapter(child: _buildSectionHeader('Destacados en La Paz', onTap: () {})),
          SliverToBoxAdapter(child: _buildDestacadosGrid()),
          if (_zonas.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionHeader(
              'Zonas de Precaución',
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFE53935),
            )),
            SliverToBoxAdapter(child: _buildZonasCarrusel()),
          ],
          SliverToBoxAdapter(child: _buildIaBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  APP HEADER — Logo + iconos (arriba de todo)
  // ─────────────────────────────────────
  Widget _buildAppHeader() {
    return Container(
      color: bgLight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo / nombre de la app
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: brandTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.explore_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 8),
            const Text(
              'WALI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: brandTeal,
                letterSpacing: 1.5,
              ),
            ),
          ]),
          // Iconos de notificaciones y filtros
          Row(children: [
            _headerIconBtn(Icons.notifications_outlined),
            const SizedBox(width: 8),
            _headerIconBtn(Icons.tune_rounded),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  BARRA DE BÚSQUEDA — separada, debajo del saludo
  // ─────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: bgLight,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: const TextStyle(fontSize: 14, color: brandDark),
          decoration: InputDecoration(
            hintText: '¿Qué quieres explorar hoy?',
            hintStyle: TextStyle(color: brandDark.withValues(alpha: 0.38), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: brandDark.withValues(alpha: 0.38), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                    child: Icon(Icons.close_rounded, color: brandDark.withValues(alpha: 0.38), size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Icon(icon, color: brandDark.withValues(alpha: 0.65), size: 20),
    );
  }

  // ─────────────────────────────────────
  //  SALUDO — con nombre real desde Supabase
  // ─────────────────────────────────────
  Widget _buildGreeting() {
    // Nombre a mostrar: si ya cargó, el nombre real; si no, 'Explorer'
    final displayName = _userName.isNotEmpty ? _userName : 'Explorer';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: brandDark,
                letterSpacing: -0.3,
              ),
              children: [
                const TextSpan(text: '¡Hola, '),
                TextSpan(
                  text: displayName,
                  style: const TextStyle(color: brandTeal),
                ),
                const TextSpan(text: '! 👋'),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '¿A dónde exploramos hoy?',
            style: TextStyle(fontSize: 13, color: brandDark.withValues(alpha: 0.48)),
          ),
        ])),
        CircleAvatar(
          radius: 22,
          backgroundColor: brandTeal.withValues(alpha: 0.15),
          child: _userName.isNotEmpty
              ? Text(
                  _userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: brandTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                )
              : const Icon(Icons.person_rounded, color: brandTeal, size: 24),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  FILTROS DE CATEGORÍA
  // ─────────────────────────────────────
  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isActive = _selectedCategory == i;
          return GestureDetector(
            onTap: () => _onCategoryTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 8, top: 5, bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? brandEmerald : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? brandEmerald : brandDark.withValues(alpha: 0.10)),
                boxShadow: isActive
                    ? [BoxShadow(color: brandEmerald.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: brandDark.withValues(alpha: 0.04), blurRadius: 5)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(cat.icon, size: 15, color: isActive ? Colors.white : brandDark.withValues(alpha: 0.55)),
                const SizedBox(width: 6),
                Text(cat.label, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : brandDark.withValues(alpha: 0.65),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────
  //  CARRUSEL PRINCIPAL — con auto-scroll
  // ─────────────────────────────────────
  Widget _buildCarousel() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 238,
        child: _isLoading
            ? _buildSkeletonList(238, 285)
            : _error != null
                ? _buildErrorWidget()
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: _filteredCards.isEmpty
                        ? _buildEmptyWidget()
                        : Column(
                            children: [
                              Expanded(
                                child: PageView.builder(
                                  controller: _cardController,
                                  itemCount: _filteredCards.length,
                                  physics: const BouncingScrollPhysics(),
                                  onPageChanged: (_) {
                                    // Reiniciar el timer de auto-scroll al deslizar manualmente
                                    _autoScrollController.reset();
                                    if (_filteredCards.length > 1) {
                                      _autoScrollController.forward();
                                    }
                                  },
                                  itemBuilder: (ctx, i) => _buildMainCard(_filteredCards[i], i),
                                ),
                              ),
                              // Indicadores de página (dots)
                              if (_filteredCards.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _buildPageIndicator(),
                                ),
                            ],
                          ),
                  ),
      ),
    );
  }

  // Indicadores de posición del carrusel
  Widget _buildPageIndicator() {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, _) {
        final currentPage = _cardController.hasClients
            ? (_cardController.page?.round() ?? 0)
            : 0;
        final count = _filteredCards.length;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count > 5 ? 5 : count, (i) {
            // Si hay más de 5, mostrar solo 5 dots
            final isActive = i == (currentPage % (count > 5 ? 5 : count));
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? brandTeal : brandDark.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMainCard(_CardItem card, int index) {
    final List<List<Color>> grads = [
      [brandTeal, brandEmerald],
      [brandAmber, brandTerracota],
      [brandEmerald, brandDark],
      [brandOrange, brandTerracota],
      [brandDark, brandTeal],
    ];
    final grad = grads[index % grads.length];

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(fit: StackFit.expand, children: [
            if (card.imagenUrl != null && card.imagenUrl!.isNotEmpty)
              Image.network(card.imagenUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradBox(grad))
            else
              _gradBox(grad),
            Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.70)],
                stops: const [0.28, 1.0],
              ),
            )),
            Positioned(top: 14, left: 14,
              child: _badge(
                icon: card.isRuta ? Icons.route_rounded : Icons.place_rounded,
                label: card.isRuta ? 'RUTA' : 'POPULAR',
                color: card.isRuta ? brandAmber : brandTeal,
              )),
            if (card.iaGenerado)
              Positioned(top: 14, right: 14,
                child: _badge(
                  icon: Icons.auto_awesome,
                  label: 'IA',
                  color: Colors.white.withValues(alpha: 0.20),
                  border: true,
                )),
            Positioned(left: 16, right: 16, bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(card.nombre,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(card.descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.80), height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(children: [
                  if (!card.isRuta && card.precio != null) ...[
                    _infoChip(Icons.sell_rounded, 'Bs. ${card.precio!.toStringAsFixed(0)}'),
                    const SizedBox(width: 6),
                  ],
                  _infoChip(Icons.star_rounded, '4.7'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: const Text('Explorar →',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _gradBox(List<Color> colors) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
  );

  Widget _badge({required IconData icon, required String label, required Color color, bool border = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: border ? Border.all(color: Colors.white.withValues(alpha: 0.4)) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  SECTION HEADER REUTILIZABLE
  // ─────────────────────────────────────
  Widget _buildSectionHeader(String title, {VoidCallback? onTap, IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: (iconColor ?? brandTeal).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor ?? brandTeal),
          ),
          const SizedBox(width: 8),
        ],
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brandDark, letterSpacing: -0.2)),
        const Spacer(),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text('Ver todo', style: TextStyle(fontSize: 13, color: brandTeal, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  DESTACADOS — scroll horizontal
  // ─────────────────────────────────────
  Widget _buildDestacadosGrid() {
    if (_isLoading) return _buildSkeletonList(158, 138);
    final puntos = _destacados;
    if (puntos.isEmpty) return _buildEmptyWidget(height: 80);
    return SizedBox(
      height: 158,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: puntos.length,
        itemBuilder: (ctx, i) => _buildMiniCard(puntos[i], i),
      ),
    );
  }

  Widget _buildMiniCard(PuntoTuristico p, int index) {
    final List<Color> colors = [brandTeal, brandEmerald, brandAmber, brandTerracota, brandOrange, brandDark];
    final color = colors[index % colors.length];
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 138,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.09), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            if (p.imagenUrl != null && p.imagenUrl!.isNotEmpty)
              Image.network(p.imagenUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: color.withValues(alpha: 0.8)))
            else
              Container(color: color.withValues(alpha: 0.8)),
            Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
              ),
            )),
            Positioned(bottom: 10, left: 10, right: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(p.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                const Row(children: [
                  Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFC107)),
                  SizedBox(width: 2),
                  Text('4.7', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  ZONAS DE RIESGO — carrusel compacto
  // ─────────────────────────────────────
  Widget _buildZonasCarrusel() {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _zonas.length,
        itemBuilder: (ctx, i) => _buildZonaCard(_zonas[i]),
      ),
    );
  }

  Widget _buildZonaCard(ZonaRiesgo zona) {
    final colorMap    = {801: const Color(0xFFFFF3E0), 802: const Color(0xFFFFEBEE), 803: const Color(0xFFFCE4EC)};
    final iconColorMap= {801: const Color(0xFFF57C00), 802: const Color(0xFFE53935), 803: const Color(0xFFAD1457)};
    final bgColor   = colorMap[zona.idNivelRiesgo]    ?? const Color(0xFFFFF3E0);
    final iconColor = iconColorMap[zona.idNivelRiesgo] ?? const Color(0xFFF57C00);

    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.location_on_rounded, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(zona.nombre,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: iconColor),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(zona.descripcion,
            style: TextStyle(fontSize: 11, color: brandDark.withValues(alpha: 0.58), height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  BANNER IA — navega al ChatView
  // ─────────────────────────────────────
  Widget _buildIaBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = 2),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [brandEmerald, brandTeal],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.36), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white70),
                const SizedBox(width: 5),
                Text('WALI IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.75), letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 6),
              const Text('Crea tu itinerario\nideal con IA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Text('Planificar viaje →',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brandEmerald)),
              ),
            ])),
            const SizedBox(width: 10),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded, size: 38, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────
  //  ESTADOS: Skeleton / Error / Vacío
  // ─────────────────────────────────────
  Widget _buildSkeletonList(double height, double itemWidth) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (_, i) => _SkeletonBox(
          width: itemWidth, height: height - 8,
          margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 30, color: brandTerracota),
      const SizedBox(height: 8),
      Text('Sin conexión', style: TextStyle(color: brandDark.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _fetchData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: brandTeal, borderRadius: BorderRadius.circular(12)),
          child: const Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    ]));
  }

  Widget _buildEmptyWidget({double height = 238}) {
    return SizedBox(
      height: height,
      child: Center(child: Text(
        'Sin resultados para esta categoría',
        style: TextStyle(color: brandDark.withValues(alpha: 0.42), fontSize: 14),
      )),
    );
  }
}

// ─────────────────────────────────────────
//  MODELOS INTERNOS
// ─────────────────────────────────────────

class _CategoryFilter {
  final String label;
  final IconData icon;
  final List<int> categoriaIds;
  final List<int> tipoRutaIds;
  const _CategoryFilter({
    required this.label, required this.icon,
    required this.categoriaIds, required this.tipoRutaIds,
  });
}

class _CardItem {
  final int id;
  final String nombre;
  final String descripcion;
  final String? imagenUrl;
  final bool isRuta;
  final bool iaGenerado;
  final double? precio;

  const _CardItem({
    required this.id, required this.nombre, required this.descripcion,
    this.imagenUrl, required this.isRuta, this.iaGenerado = false, this.precio,
  });

  factory _CardItem.fromPunto(PuntoTuristico p) => _CardItem(
    id: p.id, nombre: p.nombre, descripcion: p.descripcion,
    imagenUrl: p.imagenUrl, isRuta: false, precio: p.precioNacional);

  factory _CardItem.fromRuta(Ruta r) => _CardItem(
    id: r.id, nombre: r.nombre, descripcion: r.descripcion,
    isRuta: true, iaGenerado: r.iaGenerado);
}

// ─────────────────────────────────────────
//  SKELETON ANIMADO
// ─────────────────────────────────────────
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final EdgeInsets margin;
  final double radius;

  const _SkeletonBox({
    required this.width, required this.height,
    required this.margin, this.radius = 18,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFDCF0FA), const Color(0xFFBCD8EC), _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}