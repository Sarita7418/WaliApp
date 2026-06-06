import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'explore_view.dart';
import 'itinerary_view.dart';
import 'diary_screen.dart';
import 'routes_view.dart';
import 'chat_view.dart';
import 'profile_view.dart';
import 'rates_view.dart';
import 'ocr_view.dart';
import 'route_detail_screen.dart';
import 'place_detail_screen.dart';
import 'mapa_riesgos_screen.dart';

// =============================================================================
//  MODELOS DE DATOS
// =============================================================================

class PuntoTuristico {
  final int id;
  final String nombre;
  final String descripcion;
  final String? imagenUrl;
  final double? precioNacional;
  final double? precioExtranjero;
  final int idCategoria;
  final double? latitud;
  final double? longitud;

  const PuntoTuristico({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.imagenUrl,
    this.precioNacional,
    this.precioExtranjero,
    required this.idCategoria,
    this.latitud,
    this.longitud,
  });

  factory PuntoTuristico.fromMap(Map<String, dynamic> map) {
    return PuntoTuristico(
      id: map['id'] as int,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      imagenUrl: map['imagen_url'] as String?,
      precioNacional: (map['precio_nacional'] as num?)?.toDouble(),
      precioExtranjero: (map['precio_extranjero'] as num?)?.toDouble(),
      idCategoria: map['id_categoria'] as int? ?? 0,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
    );
  }
}

class Ruta {
  final int id;
  final String nombre;
  final String descripcion;
  final bool iaGenerado;
  final int idTipoRuta;
  final List<String> imagenesPuntos;

  const Ruta({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.iaGenerado,
    required this.idTipoRuta,
    this.imagenesPuntos = const [],
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

  Ruta copyWith({List<String>? imagenesPuntos}) => Ruta(
    id: id, nombre: nombre, descripcion: descripcion,
    iaGenerado: iaGenerado, idTipoRuta: idTipoRuta,
    imagenesPuntos: imagenesPuntos ?? this.imagenesPuntos,
  );
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

// =============================================================================
//  INTERFAZ PÚBLICA
// =============================================================================

abstract class HomeNavigator {
  void abrirMapaConPoi({
    required int id,
    required String nombre,
    required String descripcion,
    required int idCategoria,
    required double? lat,
    required double? lng,
    required double? precio,
    required String? imagenUrl,
  });

  void abrirMapaConRuta({
    required int id,
    required String nombre,
    required String descripcion,
    required bool iaGenerado,
    required List<RutaPuntoSimple> puntos,
  });
}

// =============================================================================
//  MODELO INTERNO: petición pendiente al mapa
// =============================================================================

class _MapRequest {
  final int?    poiId;
  final String? poiNombre;
  final String? poiDescripcion;
  final int?    poiIdCategoria;
  final double? poiLat;
  final double? poiLng;
  final double? poiPrecio;
  final String? poiImagenUrl;

  final int?                   rutaId;
  final String?                rutaNombre;
  final String?                rutaDescripcion;
  final bool?                  rutaIaGenerado;
  final List<RutaPuntoSimple>? rutaPuntos;

  final bool isRuta;

  const _MapRequest._({
    this.poiId, this.poiNombre, this.poiDescripcion, this.poiIdCategoria,
    this.poiLat, this.poiLng, this.poiPrecio, this.poiImagenUrl,
    this.rutaId, this.rutaNombre, this.rutaDescripcion, this.rutaIaGenerado,
    this.rutaPuntos, required this.isRuta,
  });

  factory _MapRequest.poi({
    required int    poiId,
    required String poiNombre,
    required String poiDescripcion,
    required int    poiIdCategoria,
    double? poiLat,
    double? poiLng,
    double? poiPrecio,
    String? poiImagenUrl,
  }) => _MapRequest._(
    poiId: poiId, poiNombre: poiNombre, poiDescripcion: poiDescripcion,
    poiIdCategoria: poiIdCategoria, poiLat: poiLat, poiLng: poiLng,
    poiPrecio: poiPrecio, poiImagenUrl: poiImagenUrl, isRuta: false,
  );

  factory _MapRequest.ruta({
    required int                   rutaId,
    required String                rutaNombre,
    required String                rutaDescripcion,
    required bool                  rutaIaGenerado,
    required List<RutaPuntoSimple> rutaPuntos,
  }) => _MapRequest._(
    rutaId: rutaId, rutaNombre: rutaNombre, rutaDescripcion: rutaDescripcion,
    rutaIaGenerado: rutaIaGenerado, rutaPuntos: rutaPuntos, isRuta: true,
  );
}

// =============================================================================
//  HOME SCREEN
// =============================================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin
    implements HomeNavigator {

  int _currentIndex = 0;
  Map<String, dynamic>? _itinerarioData;
  _MapRequest? _pendingMapRequest;

  // ── COLORES ──
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
  List<Ruta>           _allRutas  = [];
  List<ZonaRiesgo>     _zonas     = [];
  String? _error;
  String  _userName = '';

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
  late final Animation<double>   _fadeAnim;
  late final AnimationController _autoScrollController;

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
            final cur = _cardController.page?.round() ?? 0;
            final cnt = _filteredCards.length;
            if (cnt > 1) {
              _cardController.animateToPage(
                (cur + 1) % cnt,
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
  //  SUPABASE
  // ─────────────────────────────────────
  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final sb = Supabase.instance.client;
      final userId = sb.auth.currentUser?.id;

      final results = await Future.wait([
        userId != null
            ? sb.from('personas').select('nombres').eq('id_usuario', userId).maybeSingle()
            : Future.value(null),
        sb.from('punto_turistico')
            .select('id, nombre, descripcion, imagen_url, precio_nacional, precio_extranjero, id_categoria, latitud, longitud')
            .eq('estado', true).order('nombre'),
        sb.from('rutas')
            .select('id, nombre, descripcion, ia_generado, id_tipo_ruta')
            .eq('estado', true).order('nombre'),
        sb.from('zonas_riesgo')
            .select('id, nombre, descripcion, id_nivel_riesgo')
            .eq('estado', true).order('id_nivel_riesgo', ascending: false).limit(6),
        sb.from('ruta_puntos')
            .select('id_ruta, punto_turistico(imagen_url)')
            .order('orden'),
      ]);

      if (!mounted) return;

      final persona = results[0] as Map<String, dynamic>?;
      if (persona != null) {
        _userName = (persona['nombres'] as String? ?? '').split(' ').first;
      }

      final puntos = (results[1] as List).map((e) => PuntoTuristico.fromMap(e)).toList();
      final rutasBase = (results[2] as List).map((e) => Ruta.fromMap(e)).toList();

      final rutaPuntosData = results[4] as List;
      final Map<int, List<String>> imagenesPorRuta = {};
      for (final rp in rutaPuntosData) {
        final idRuta = rp['id_ruta'] as int?;
        final punto = rp['punto_turistico'] as Map<String, dynamic>?;
        final imgUrl = punto?['imagen_url'] as String?;
        if (idRuta != null && imgUrl != null && imgUrl.isNotEmpty) {
          imagenesPorRuta.putIfAbsent(idRuta, () => []);
          if ((imagenesPorRuta[idRuta]!.length) < 4) {
            imagenesPorRuta[idRuta]!.add(imgUrl);
          }
        }
      }

      final rutasConImagenes = rutasBase.map((r) =>
        r.copyWith(imagenesPuntos: imagenesPorRuta[r.id] ?? [])
      ).toList();

      setState(() {
        _allPuntos = puntos;
        _allRutas  = rutasConImagenes;
        _zonas     = (results[3] as List).map((e) => ZonaRiesgo.fromMap(e)).toList();
        _isLoading = false;
      });
      _fadeController.forward();
      if (_filteredCards.length > 1) _autoScrollController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // =============================================================================
  //  HomeNavigator
  // =============================================================================

  @override
  void abrirMapaConPoi({
    required int     id,
    required String  nombre,
    required String  descripcion,
    required int     idCategoria,
    required double? lat,
    required double? lng,
    required double? precio,
    required String? imagenUrl,
  }) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    setState(() {
      _pendingMapRequest = _MapRequest.poi(
        poiId: id, poiNombre: nombre, poiDescripcion: descripcion,
        poiIdCategoria: idCategoria, poiLat: lat, poiLng: lng,
        poiPrecio: precio, poiImagenUrl: imagenUrl,
      );
      _currentIndex = 1;
    });
  }

  @override
  void abrirMapaConRuta({
    required int                   id,
    required String                nombre,
    required String                descripcion,
    required bool                  iaGenerado,
    required List<RutaPuntoSimple> puntos,
  }) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    setState(() {
      _pendingMapRequest = _MapRequest.ruta(
        rutaId: id, rutaNombre: nombre, rutaDescripcion: descripcion,
        rutaIaGenerado: iaGenerado, rutaPuntos: puntos,
      );
      _currentIndex = 1;
    });
  }

  // ─────────────────────────────────────
  //  NAVEGACIÓN A DETALLES
  // ─────────────────────────────────────
  void _navegarADetalle(_CardItem card) {
    if (card.isRuta) {
      final ruta = _allRutas.firstWhere(
        (r) => r.id == card.id,
        orElse: () => Ruta(
          id: card.id, nombre: card.nombre, descripcion: card.descripcion,
          iaGenerado: card.iaGenerado, idTipoRuta: 701,
        ),
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => RouteDetailScreen(ruta: ruta, homeState: this),
      ));
    } else {
      final punto = _allPuntos.firstWhere(
        (p) => p.id == card.id,
        orElse: () => PuntoTuristico(
          id: card.id, nombre: card.nombre, descripcion: card.descripcion,
          imagenUrl: card.imagenUrl, precioNacional: card.precio, idCategoria: 401,
        ),
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(punto: punto, homeState: this),
      ));
    }
  }

  void _navegarAPuntoDetalle(PuntoTuristico punto) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlaceDetailScreen(punto: punto, homeState: this),
    ));
  }

  void _navegarARutaDetalle(Ruta ruta) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RouteDetailScreen(ruta: ruta, homeState: this),
    ));
  }

  // ── ITINERARIOS ──
  Future<void> _gestionarItinerario() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sincronizando itinerario...'), duration: Duration(milliseconds: 800)));
    try {
      final data = await Supabase.instance.client.from('itinerarios').select('''
        *, itinerario_dias (id, numero_dia, fecha_calendario,
          itinerario_actividades (id, nombre, hora_inicio, hora_fin, precio, es_prioridad, notas_usuario))
      ''').eq('id_persona', user.id).maybeSingle();
      setState(() { _itinerarioData = data; _currentIndex = 6; });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _currentIndex = 6);
    }
  }

  // ─────────────────────────────────────
  //  MODAL VER TODO
  // ─────────────────────────────────────
  void _showVerTodoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerTodoModal(
        allPuntos: _allPuntos,
        allRutas: _allRutas,
        onSelectPunto: (p) {
          Navigator.pop(context);
          _navegarAPuntoDetalle(p);
        },
        onSelectRuta: (r) {
          Navigator.pop(context);
          _navegarARutaDetalle(r);
        },
      ),
    );
  }

  // ─────────────────────────────────────
  //  FILTRADO
  // ─────────────────────────────────────
  List<_CardItem> get _filteredCards {
    final cat = _categories[_selectedCategory];
    final q   = _searchQuery.toLowerCase();
    final cards = <_CardItem>[];
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
    return _allPuntos.where((p) =>
        p.nombre.toLowerCase().contains(q) || p.descripcion.toLowerCase().contains(q)).toList();
  }

  void _onCategoryTap(int index) {
    if (_selectedCategory == index) return;
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _selectedCategory = index);
      try { _cardController.jumpToPage(0); } catch (_) {}
      _fadeController.forward();
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
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.4,
        decoration: const BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(width: 50, height: 50,
              decoration: BoxDecoration(color: brandTeal.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.keyboard_arrow_down_rounded, color: brandTeal, size: 40)),
          )),
          const SizedBox(height: 20),
          Expanded(child: GridView.count(
            crossAxisCount: 3,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildModuleItem(Icons.route_rounded, 'Itinerarios', brandTeal, () {
                Navigator.pop(ctx);
                _gestionarItinerario();
              }),
              _buildModuleItem(Icons.payments_outlined, 'Tarifas', brandOrangeOld, () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 4);
              }),
              _buildModuleItem(Icons.camera_alt_rounded, 'Leer menus', const Color(0xFFE64A19), () {
                Navigator.pop(ctx);
                setState(() => _currentIndex = 5);
              }),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildModuleItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(radius: 28,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 28)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  TAB MAPAS
  // ─────────────────────────────────────
  Widget _buildMapasTab() {
    final navH = 60.0 + MediaQuery.of(context).padding.bottom;
    final req  = _pendingMapRequest;

    if (req == null) {
      return RoutesView(showOwnScaffold: false, bottomNavHeight: navH);
    }

    if (req.isRuta) {
      return RoutesViewRutaWrapper(
        key:             ValueKey('ruta_${req.rutaId}'),
        rutaId:          req.rutaId!,
        rutaNombre:      req.rutaNombre!,
        rutaDescripcion: req.rutaDescripcion!,
        rutaIaGenerado:  req.rutaIaGenerado!,
        puntos:          req.rutaPuntos!,
        embebido:        true,
        bottomNavHeight: navH,
      );
    }

    return RoutesViewWrapper(
      key:                  ValueKey('poi_${req.poiId}'),
      targetId:             req.poiId!,
      targetNombre:         req.poiNombre!,
      targetDescripcion:    req.poiDescripcion!,
      targetCategoria:      'Sitio Turístico',
      targetIdCategoria:    req.poiIdCategoria!,
      targetLat:            req.poiLat,
      targetLng:            req.poiLng,
      targetPrecioNacional: req.poiPrecio,
      targetImagenUrl:      req.poiImagenUrl,
      embebido:             true,
      bottomNavHeight:      navH,
    );
  }

  // ─────────────────────────────────────
  //  BUILD PRINCIPAL
  // ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();

    return Scaffold(
      backgroundColor: bgLight,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildMapasTab(),
          const ChatView(),
          const ProfileView(),
          const RatesView(),
          const OcrView(),
          _itinerarioData != null
              ? DiaryScreen(itinerarioData: _itinerarioData!)
              : const ItineraryView(),
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
        child: SizedBox(height: 60, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_filled,        'Inicio',  0),
            _buildNavItem(Icons.map_outlined,       'Mapas',   1),
            const SizedBox(width: 40),
            _buildNavItem(Icons.smart_toy_outlined, 'Wali IA', 2),
            _buildNavItem(Icons.person_outline,     'Perfil',  3),
          ],
        )),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logoWALI.jpeg',
                width: 90, height: 90, fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            const Text('WALI',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                  color: brandTeal, letterSpacing: 6)),
            const SizedBox(height: 6),
            Text('Cargando tu experiencia...',
              style: TextStyle(fontSize: 13,
                  color: brandDark.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            const SizedBox(width: 36, height: 36,
              child: CircularProgressIndicator(color: brandTeal, strokeWidth: 3)),
          ],
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
          SliverToBoxAdapter(child: _buildAppHeader()),
          SliverToBoxAdapter(child: _buildGreeting()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategoryFilters()),
          SliverToBoxAdapter(child: _buildCarousel()),
          // ← onTap ahora llama al modal
          SliverToBoxAdapter(child: _buildSectionHeader(
            'Destacados en La Paz',
            onTap: _showVerTodoModal,
          )),
          SliverToBoxAdapter(child: _buildDestacadosGrid()),
          if (_zonas.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionHeader(
              'Zonas de Precaución',
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFE53935),
            )),
            SliverToBoxAdapter(child: _buildMapaRiesgosButton()),
            SliverToBoxAdapter(child: _buildZonasCarrusel()),
          ],
          SliverToBoxAdapter(child: _buildIaBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      color: bgLight,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/logoWALI.jpeg',
                  width: 36, height: 36, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            const Text('WALI', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: brandTeal, letterSpacing: 1.5)),
          ]),
          CircleAvatar(
            radius: 22,
            backgroundColor: brandTeal.withValues(alpha: 0.15),
            child: _userName.isNotEmpty
                ? Text(_userName[0].toUpperCase(),
                    style: const TextStyle(color: brandTeal,
                        fontWeight: FontWeight.w800, fontSize: 18))
                : const Icon(Icons.person_rounded, color: brandTeal, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: bgLight,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.06),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          style: const TextStyle(fontSize: 14, color: brandDark),
          decoration: InputDecoration(
            hintText: '¿Qué quieres explorar hoy?',
            hintStyle: TextStyle(color: brandDark.withValues(alpha: 0.38), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: brandDark.withValues(alpha: 0.38), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close_rounded,
                        color: brandDark.withValues(alpha: 0.38), size: 18))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final displayName = _userName.isNotEmpty ? _userName : 'Explorer';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: brandDark, letterSpacing: -0.3),
            children: [
              const TextSpan(text: '¡Hola, '),
              TextSpan(text: displayName,
                  style: const TextStyle(color: brandTeal)),
              const TextSpan(text: '!'),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('¿A dónde exploramos hoy?',
          style: TextStyle(fontSize: 13, color: brandDark.withValues(alpha: 0.48))),
      ]),
    );
  }

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
                border: Border.all(
                    color: isActive ? brandEmerald : brandDark.withValues(alpha: 0.10)),
                boxShadow: isActive
                    ? [BoxShadow(color: brandEmerald.withValues(alpha: 0.28),
                        blurRadius: 10, offset: const Offset(0, 4))]
                    : [BoxShadow(color: brandDark.withValues(alpha: 0.04),
                        blurRadius: 5)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(cat.icon, size: 15,
                    color: isActive ? Colors.white : brandDark.withValues(alpha: 0.55)),
                const SizedBox(width: 6),
                Text(cat.label, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : brandDark.withValues(alpha: 0.65))),
              ]),
            ),
          );
        },
      ),
    );
  }

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
                        : Column(children: [
                            Expanded(child: PageView.builder(
                              controller: _cardController,
                              itemCount: _filteredCards.length,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (_) {
                                _autoScrollController.reset();
                                if (_filteredCards.length > 1) {
                                  _autoScrollController.forward();
                                }
                              },
                              itemBuilder: (ctx, i) =>
                                  _buildMainCard(_filteredCards[i], i),
                            )),
                            if (_filteredCards.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildPageIndicator(),
                              ),
                          ]),
                  ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, _) {
        final currentPage =
            _cardController.hasClients ? (_cardController.page?.round() ?? 0) : 0;
        final count = _filteredCards.length;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count > 5 ? 5 : count, (i) {
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

  Widget _buildCollage(List<String> imgs, List<Color> grad) {
    if (imgs.isEmpty) return _gradBox(grad);
    if (imgs.length == 1) {
      return Image.network(imgs[0], fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradBox(grad));
    }
    final top    = imgs.take(2).toList();
    final bottom = imgs.length > 2 ? imgs.skip(2).take(2).toList() : <String>[];
    return Column(children: [
      Expanded(child: Row(children: [
        for (int i = 0; i < top.length; i++) ...[
          Expanded(child: Image.network(top[i], fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: grad[0]))),
          if (i < top.length - 1) const SizedBox(width: 2),
        ],
      ])),
      if (bottom.isNotEmpty) ...[
        const SizedBox(height: 2),
        Expanded(child: Row(children: [
          for (int i = 0; i < bottom.length; i++) ...[
            Expanded(child: Image.network(bottom[i], fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: grad[1 % grad.length]))),
            if (i < bottom.length - 1) const SizedBox(width: 2),
          ],
        ])),
      ],
    ]);
  }

  Widget _buildMainCard(_CardItem card, int index) {
    final List<List<Color>> grads = [
      [brandTeal, brandEmerald], [brandAmber, brandTerracota],
      [brandEmerald, brandDark], [brandOrange, brandTerracota],
      [brandDark, brandTeal],
    ];
    final grad = grads[index % grads.length];

    return GestureDetector(
      onTap: () => _navegarADetalle(card),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.14),
                blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(fit: StackFit.expand, children: [
              if (card.isRuta && card.imagenesPuntos.isNotEmpty)
                _buildCollage(card.imagenesPuntos, grad)
              else if (card.imagenUrl != null && card.imagenUrl!.isNotEmpty)
                Image.network(card.imagenUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _gradBox(grad))
              else
                _gradBox(grad),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.70)],
                stops: const [0.28, 1.0],
              ))),
              Positioned(top: 14, left: 14, child: _badge(
                icon: card.isRuta ? Icons.route_rounded : Icons.place_rounded,
                label: card.isRuta ? 'RUTA' : 'POPULAR',
                color: card.isRuta ? brandAmber : brandTeal,
              )),
              if (card.iaGenerado)
                Positioned(top: 14, right: 14, child: _badge(
                  icon: Icons.auto_awesome, label: 'IA',
                  color: Colors.white.withValues(alpha: 0.20), border: true,
                )),
              Positioned(left: 16, right: 16, bottom: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                  Text(card.nombre,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text(card.descripcion,
                    style: TextStyle(fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.80), height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(children: [
                    if (!card.isRuta && card.precio != null) ...[
                      _infoChip(Icons.sell_rounded,
                          'Bs. ${card.precio!.toStringAsFixed(0)}'),
                      const SizedBox(width: 6),
                    ],
                    _infoChip(Icons.star_rounded, '4.7'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _navegarADetalle(card),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Text('Explorar →',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _gradBox(List<Color> colors) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    )));

  Widget _badge({required IconData icon, required String label,
      required Color color, bool border = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(20),
        border: border
            ? Border.all(color: Colors.white.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black26, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  Widget _buildSectionHeader(String title,
      {VoidCallback? onTap, IconData? icon, Color? iconColor}) {
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
        Text(title, style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800,
            color: brandDark, letterSpacing: -0.2)),
        const Spacer(),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text('Ver todo', style: TextStyle(
                fontSize: 13, color: brandTeal, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

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
    final List<Color> colors = [
      brandTeal, brandEmerald, brandAmber,
      brandTerracota, brandOrange, brandDark,
    ];
    final color = colors[index % colors.length];
    return GestureDetector(
      onTap: () => _navegarAPuntoDetalle(p),
      child: Container(
        width: 138,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.09),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            if (p.imagenUrl != null && p.imagenUrl!.isNotEmpty)
              Image.network(p.imagenUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: color.withValues(alpha: 0.8)))
            else
              Container(color: color.withValues(alpha: 0.8)),
            Container(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)]))),
            Positioned(bottom: 10, left: 10, right: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(p.nombre,
                  style: const TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                const Row(children: [
                  Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFC107)),
                  SizedBox(width: 2),
                  Text('4.7', style: TextStyle(color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ])),
          ]),
        ),
      ),
    );
  }

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

  Widget _buildMapaRiesgosButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MapaRiesgosScreen())),
        icon: const Icon(Icons.map_rounded, size: 18),
        label: const Text('Mapa de riesgos'),
        style: ElevatedButton.styleFrom(
          backgroundColor: brandOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildZonaCard(ZonaRiesgo zona) {
    final colorMap     = {
      801: const Color(0xFFFFF3E0),
      802: const Color(0xFFFFEBEE),
      803: const Color(0xFFFCE4EC),
    };
    final iconColorMap = {
      801: const Color(0xFFF57C00),
      802: const Color(0xFFE53935),
      803: const Color(0xFFAD1457),
    };
    final bgColor   = colorMap[zona.idNivelRiesgo]    ?? const Color(0xFFFFF3E0);
    final iconColor = iconColorMap[zona.idNivelRiesgo] ?? const Color(0xFFF57C00);
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.07),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.location_on_rounded, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text(zona.nombre,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: iconColor),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(zona.descripcion,
            style: TextStyle(fontSize: 11,
                color: brandDark.withValues(alpha: 0.58), height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

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
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.36),
                blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white70),
                const SizedBox(width: 5),
                Text('WALI IA', style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 6),
              const Text('Crea tu itinerario\nideal con IA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.25)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: const Text('Planificar viaje →',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: brandEmerald)),
              ),
            ])),
            const SizedBox(width: 10),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 38, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(double height, double itemWidth) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (_, i) => _SkeletonBox(
          width: itemWidth, height: height - 8,
          margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4)),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
      const Icon(Icons.wifi_off_rounded, size: 30, color: brandTerracota),
      const SizedBox(height: 8),
      Text('Sin conexión', style: TextStyle(
          color: brandDark.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _fetchData,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: brandTeal,
              borderRadius: BorderRadius.circular(12)),
          child: const Text('Reintentar', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    ]));
  }

  Widget _buildEmptyWidget({double height = 238}) {
    return SizedBox(
      height: height,
      child: Center(child: Text('Sin resultados para esta categoría',
        style: TextStyle(color: brandDark.withValues(alpha: 0.42), fontSize: 14))),
    );
  }
}

// =============================================================================
//  MODELOS INTERNOS Y SKELETON
// =============================================================================

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
  final List<String> imagenesPuntos;

  const _CardItem({
    required this.id, required this.nombre, required this.descripcion,
    this.imagenUrl, required this.isRuta, this.iaGenerado = false,
    this.precio, this.imagenesPuntos = const [],
  });

  factory _CardItem.fromPunto(PuntoTuristico p) => _CardItem(
    id: p.id, nombre: p.nombre, descripcion: p.descripcion,
    imagenUrl: p.imagenUrl, isRuta: false, precio: p.precioNacional);

  factory _CardItem.fromRuta(Ruta r) => _CardItem(
    id: r.id, nombre: r.nombre, descripcion: r.descripcion,
    isRuta: true, iaGenerado: r.iaGenerado,
    imagenesPuntos: r.imagenesPuntos);
}

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

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height, margin: widget.margin,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFDCF0FA),
              const Color(0xFFBCD8EC), _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// =============================================================================
//  MODAL VER TODO
// =============================================================================

class _VerTodoModal extends StatefulWidget {
  final List<PuntoTuristico> allPuntos;
  final List<Ruta> allRutas;
  final void Function(PuntoTuristico) onSelectPunto;
  final void Function(Ruta) onSelectRuta;

  const _VerTodoModal({
    required this.allPuntos,
    required this.allRutas,
    required this.onSelectPunto,
    required this.onSelectRuta,
  });

  @override
  State<_VerTodoModal> createState() => _VerTodoModalState();
}

class _VerTodoModalState extends State<_VerTodoModal> {
  static const Color brandTeal    = Color(0xFF0F988A);
  static const Color brandEmerald = Color(0xFF197D61);
  static const Color brandAmber   = Color(0xFFD27817);
  static const Color brandDark    = Color(0xFF23373E);

  // 0 = Todos, 1 = Lugares, 2 = Rutas
  int _filter = 0;
  String _query = '';
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  List<_VerTodoItem> get _items {
    final q = _query.toLowerCase();
    final items = <_VerTodoItem>[];

    if (_filter != 2) {
      for (final p in widget.allPuntos) {
        if (q.isNotEmpty &&
            !p.nombre.toLowerCase().contains(q) &&
            !p.descripcion.toLowerCase().contains(q)) continue;
        items.add(_VerTodoItem.fromPunto(p));
      }
    }
    if (_filter != 1) {
      for (final r in widget.allRutas) {
        if (q.isNotEmpty &&
            !r.nombre.toLowerCase().contains(q) &&
            !r.descripcion.toLowerCase().contains(q)) continue;
        items.add(_VerTodoItem.fromRuta(r));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2FBFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // ── Handle ──
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: brandDark.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
            child: Row(children: [
              const Text('Todos los lugares',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: brandDark, letterSpacing: -0.3)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: brandDark.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18,
                      color: brandDark.withValues(alpha: 0.65)),
                ),
              ),
            ]),
          ),

          // ── Buscador ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _ctrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(fontSize: 14, color: brandDark),
                decoration: InputDecoration(
                  hintText: 'Buscar lugar o ruta...',
                  hintStyle: TextStyle(color: brandDark.withValues(alpha: 0.38),
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: brandDark.withValues(alpha: 0.38), size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(Icons.close_rounded,
                              color: brandDark.withValues(alpha: 0.38), size: 18))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // ── Chips ──
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('Todos',   0),
                _chip('Lugares', 1),
                _chip('Rutas',   2),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ── Contador ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${items.length} resultados',
                style: TextStyle(fontSize: 12,
                    color: brandDark.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500)),
            ),
          ),

          // ── Lista ──
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('Sin resultados',
                    style: TextStyle(
                        color: brandDark.withValues(alpha: 0.4), fontSize: 14)))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _buildItem(items[i]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, int index) {
    final isActive = _filter == index;
    return GestureDetector(
      onTap: () => setState(() => _filter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? brandTeal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? brandTeal : brandDark.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : brandDark.withValues(alpha: 0.65),
          )),
        ),
      ),
    );
  }

  Widget _buildItem(_VerTodoItem item) {
    return GestureDetector(
      onTap: () {
        if (item.isRuta) {
          widget.onSelectRuta(item.ruta!);
        } else {
          widget.onSelectPunto(item.punto!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // ── Thumbnail ──
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 80, height: 80,
              child: item.imagenUrl != null && item.imagenUrl!.isNotEmpty
                  ? Image.network(item.imagenUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(item))
                  : _thumbFallback(item),
            ),
          ),
          // ── Info ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.nombre,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: brandDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(item.descripcion,
                    style: TextStyle(fontSize: 12,
                        color: brandDark.withValues(alpha: 0.55), height: 1.35),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    _itemBadge(item),
                    if (!item.isRuta && item.precio != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: brandDark.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Bs. ${item.precio!.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w600, color: brandDark)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.chevron_right_rounded,
                color: brandDark.withValues(alpha: 0.25), size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _thumbFallback(_VerTodoItem item) {
    return Container(
      color: item.isRuta
          ? brandAmber.withValues(alpha: 0.25)
          : brandTeal.withValues(alpha: 0.20),
      child: Center(child: Icon(
        item.isRuta ? Icons.route_rounded : Icons.place_rounded,
        color: item.isRuta ? brandAmber : brandTeal,
        size: 28,
      )),
    );
  }

  Widget _itemBadge(_VerTodoItem item) {
    final isRuta = item.isRuta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isRuta
            ? brandAmber.withValues(alpha: 0.15)
            : brandEmerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isRuta ? Icons.route_rounded : Icons.place_rounded,
          size: 10,
          color: isRuta ? brandAmber : brandEmerald,
        ),
        const SizedBox(width: 3),
        Text(
          isRuta ? (item.iaGenerado ? 'Ruta · IA' : 'Ruta') : 'Lugar',
          style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: isRuta ? brandAmber : brandEmerald,
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
//  MODELO INTERNO MODAL
// =============================================================================

class _VerTodoItem {
  final int id;
  final String nombre;
  final String descripcion;
  final String? imagenUrl;
  final bool isRuta;
  final bool iaGenerado;
  final double? precio;
  final PuntoTuristico? punto;
  final Ruta? ruta;

  const _VerTodoItem({
    required this.id, required this.nombre, required this.descripcion,
    this.imagenUrl, required this.isRuta, this.iaGenerado = false,
    this.precio, this.punto, this.ruta,
  });

  factory _VerTodoItem.fromPunto(PuntoTuristico p) => _VerTodoItem(
    id: p.id, nombre: p.nombre, descripcion: p.descripcion,
    imagenUrl: p.imagenUrl, isRuta: false,
    precio: p.precioNacional, punto: p,
  );

  factory _VerTodoItem.fromRuta(Ruta r) => _VerTodoItem(
    id: r.id, nombre: r.nombre, descripcion: r.descripcion,
    imagenUrl: r.imagenesPuntos.isNotEmpty ? r.imagenesPuntos.first : null,
    isRuta: true, iaGenerado: r.iaGenerado, ruta: r,
  );
}

// =============================================================================
//  EXTENSION
// =============================================================================

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}