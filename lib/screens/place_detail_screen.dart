import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home_screen.dart';
import 'routes_view.dart';

// ─────────────────────────────────────────
//  MODELOS
// ─────────────────────────────────────────

class AudioguiaData {
  final int id;
  final String titulo;
  final String descripcionCorta;
  final String? audioUrl;
  final int duracionSegundos;
  final int idIdioma;

  const AudioguiaData({
    required this.id,
    required this.titulo,
    required this.descripcionCorta,
    this.audioUrl,
    required this.duracionSegundos,
    required this.idIdioma,
  });

  factory AudioguiaData.fromMap(Map<String, dynamic> map) {
    return AudioguiaData(
      id: map['id'] as int,
      titulo: map['titulo'] as String? ?? '',
      descripcionCorta: map['descripcion_corta'] as String? ?? '',
      audioUrl: map['audio_url'] as String?,
      duracionSegundos: map['duracion_segundos'] as int? ?? 0,
      idIdioma: map['id_idioma'] as int? ?? 201,
    );
  }
}

class RutaRelacionada {
  final int id;
  final String nombre;
  final String descripcion;
  final int idTipoRuta;

  const RutaRelacionada({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.idTipoRuta,
  });

  factory RutaRelacionada.fromMap(Map<String, dynamic> map) {
    final ruta = map['rutas'] as Map<String, dynamic>? ?? {};
    return RutaRelacionada(
      id: ruta['id'] as int? ?? 0,
      nombre: ruta['nombre'] as String? ?? '',
      descripcion: ruta['descripcion'] as String? ?? '',
      idTipoRuta: ruta['id_tipo_ruta'] as int? ?? 701,
    );
  }
}

// ─────────────────────────────────────────
//  PLACE DETAIL SCREEN
// ─────────────────────────────────────────

class PlaceDetailScreen extends StatefulWidget {
  final PuntoTuristico punto;
  // Usa HomeNavigator (interfaz pública) en lugar de _HomeScreenState (privada)
  final HomeNavigator homeState;

  const PlaceDetailScreen({
    super.key,
    required this.punto,
    required this.homeState,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen>
    with TickerProviderStateMixin {

  // ── COLORES MARCA WALI ──
  static const Color bgLight        = Color(0xFFF2FBFF);
  static const Color brandTeal      = Color(0xFF0F988A);
  static const Color brandEmerald   = Color(0xFF197D61);
  static const Color brandAmber     = Color(0xFFD27817);
  static const Color brandDark      = Color(0xFF23373E);
  static const Color brandTerracota = Color(0xFF7A3928);

  // ── ESTADO ──
  bool _isLoading = true;
  List<AudioguiaData> _audioguias = [];
  List<RutaRelacionada> _rutasRelacionadas = [];
  bool _isFavorite = false;
  AudioguiaData? _audioguiaActiva;
  bool _audioReproduciendo = false;

  // ── MAPA MINI ──
  mbx.MapboxMap? _miniMap;
  bool _miniMapReady = false;

  // ── TABS ──
  late final TabController _tabController;

  // ── ANIMACIONES ──
  late final AnimationController _fadeCtrl;
  late final AnimationController _audioCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _audioCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeCtrl.dispose();
    _audioCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────
  //  SUPABASE
  // ─────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final agRes = await Supabase.instance.client
          .from('audioguias')
          .select('id, titulo, descripcion_corta, audio_url, duracion_segundos, id_idioma')
          .eq('id_punto_turistico', widget.punto.id)
          .eq('estado', true)
          .order('id_idioma');

      final rpRes = await Supabase.instance.client
          .from('ruta_puntos')
          .select('id, rutas (id, nombre, descripcion, id_tipo_ruta)')
          .eq('id_punto_turistico', widget.punto.id)
          .limit(5);

      if (!mounted) return;
      setState(() {
        _audioguias = (agRes as List).map((e) => AudioguiaData.fromMap(e)).toList();
        _rutasRelacionadas = (rpRes as List)
            .where((e) => e['rutas'] != null)
            .map((e) => RutaRelacionada.fromMap(e))
            .toList();
        _isLoading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────
  //  NAVEGACIÓN — usa HomeNavigator
  //  Llama a homeState.abrirMapaConPoi que:
  //    1. Cierra esta pantalla (pop)
  //    2. Cambia el IndexedStack al tab Mapas (índice 1)
  //    3. Pasa los datos del POI al mapa
  //  La barra de navegación del HomeScreen SIEMPRE permanece visible.
  // ─────────────────────────────────────

  void _abrirMapaConEstePunto() {
    widget.homeState.abrirMapaConPoi(
      id:          widget.punto.id,
      nombre:      widget.punto.nombre,
      descripcion: widget.punto.descripcion,
      idCategoria: widget.punto.idCategoria,
      lat:         widget.punto.latitud,
      lng:         widget.punto.longitud,
      precio:      widget.punto.precioNacional,
      imagenUrl:   widget.punto.imagenUrl,
    );
  }

  void _mostrarSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: brandTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────
  //  MINI MAPA
  // ─────────────────────────────────────
  void _onMiniMapCreated(mbx.MapboxMap map) {
    _miniMap = map;
    _miniMapReady = true;

    map.compass.updateSettings(mbx.CompassSettings(enabled: false));
    map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false));
    map.logo.updateSettings(mbx.LogoSettings(
      position: mbx.OrnamentPosition.BOTTOM_LEFT,
      marginBottom: 4,
      marginLeft: 4,
    ));
    map.attribution.updateSettings(mbx.AttributionSettings(enabled: false));
    map.gestures.updateSettings(mbx.GesturesSettings(
      scrollEnabled: false,
      rotateEnabled: false,
      pinchToZoomEnabled: false,
      doubleTapToZoomInEnabled: false,
      pitchEnabled: false,
    ));

    if (widget.punto.latitud != null && widget.punto.longitud != null) {
      _addMiniMapMarker();
    }
  }

  Future<void> _addMiniMapMarker() async {
    if (_miniMap == null) return;
    try {
      final manager = await _miniMap!.annotations.createPointAnnotationManager();
      await manager.create(mbx.PointAnnotationOptions(
        geometry: mbx.Point(coordinates: mbx.Position(
          widget.punto.longitud!,
          widget.punto.latitud!,
        )),
        iconSize: 1.2,
        iconColor: brandTeal.value,
        textField: '📍',
        textSize: 24,
        textAnchor: mbx.TextAnchor.BOTTOM,
      ));
    } catch (_) {}
  }

  // ─────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────
  String get _categoriaLabel {
    switch (widget.punto.idCategoria) {
      case 401: return 'Museo y Cultura';
      case 402: return 'Mirador';
      case 403: return 'Plaza o Parque';
      case 404: return 'Mi Teleférico';
      case 405: return 'Arquitectura Religiosa';
      case 406: return 'Mercado Tradicional';
      case 407: return 'Centro Comercial';
      default:  return 'Sitio Turístico';
    }
  }

  IconData get _categoriaIcon {
    switch (widget.punto.idCategoria) {
      case 401: return Icons.museum_rounded;
      case 402: return Icons.landscape_rounded;
      case 403: return Icons.park_rounded;
      case 404: return Icons.cable_rounded;
      case 405: return Icons.church_rounded;
      case 406: return Icons.storefront_rounded;
      case 407: return Icons.shopping_bag_rounded;
      default:  return Icons.place_rounded;
    }
  }

  String _idiomaLabel(int idIdioma) {
    switch (idIdioma) {
      case 201: return 'Español';
      case 202: return 'Inglés';
      case 203: return 'Portugués';
      case 204: return 'Aymara';
      default:  return 'Español';
    }
  }

  String _duracionLabel(int segundos) {
    final min = (segundos / 60).ceil();
    return '$min min';
  }

  // ─────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (ctx, _) => [_buildSliverHeader()],
            body: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabSobreLugar(),
                      _buildTabTarifasHorarios(),
                      _buildTabAudioguias(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_audioguiaActiva != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildAudioPlayer(),
            ),
          if (_audioguiaActiva == null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomCta(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  SLIVER HEADER
  // ─────────────────────────────────────
  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: brandTeal,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => setState(() => _isFavorite = !_isFavorite),
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFFF5D7A) : Colors.white,
              size: 20,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            widget.punto.imagenUrl != null && widget.punto.imagenUrl!.isNotEmpty
                ? Image.network(
                    widget.punto.imagenUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildGradientBg(),
                  )
                : _buildGradientBg(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    _buildBadge(_categoriaLabel, brandTeal),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC107).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text('4.7',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    widget.punto.nombre,
                    style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.15, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (widget.punto.latitud != null)
                    const Row(children: [
                      Icon(Icons.location_on_rounded, size: 13, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        'La Paz, Bolivia',
                        style: TextStyle(
                          fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [brandTeal, brandEmerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {bool border = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: border ? Border.all(color: Colors.white.withValues(alpha: 0.4)) : null,
      ),
      child: Text(label, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.6,
      )),
    );
  }

  // ─────────────────────────────────────
  //  TAB BAR
  // ─────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: brandTeal,
        unselectedLabelColor: brandDark.withValues(alpha: 0.40),
        indicatorColor: brandTeal,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Sobre el lugar'),
          Tab(text: 'Tarifas y Horarios'),
          Tab(text: 'Audioguías'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  TAB 1: SOBRE EL LUGAR
  // ─────────────────────────────────────
  Widget _buildTabSobreLugar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: brandDark.withValues(alpha: 0.05),
                  blurRadius: 10, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoriaIcon, size: 16, color: brandTeal),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: brandDark),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                  widget.punto.descripcion,
                  style: TextStyle(
                    fontSize: 14, color: brandDark.withValues(alpha: 0.65), height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMiniMap(),
          const SizedBox(height: 16),
          if (_rutasRelacionadas.isNotEmpty) ...[
            const Text(
              'Aparece en estas rutas',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: brandDark),
            ),
            const SizedBox(height: 12),
            ..._rutasRelacionadas.map((r) => _buildRutaRelacionadaCard(r)),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  //  MINI MAPA — "Ver en el mapa" → cambia al tab Mapas
  // ─────────────────────────────────────
  Widget _buildMiniMap() {
    final hasCoords = widget.punto.latitud != null && widget.punto.longitud != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: brandTeal.withValues(alpha: 0.18)),
        ),
        child: Stack(
          children: [
            if (hasCoords)
              _buildMapboxWidget()
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      brandTeal.withValues(alpha: 0.12),
                      brandEmerald.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: CustomPaint(painter: _LocationMapPainter()),
              ),
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _abrirMapaConEstePunto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: brandTeal,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: brandTeal.withValues(alpha: 0.45),
                          blurRadius: 14, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.near_me_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 7),
                      Text('Ver en el mapa',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapboxWidget() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    mbx.MapboxOptions.setAccessToken(token);

    return mbx.MapWidget(
      styleUri: mbx.MapboxStyles.STANDARD,
      cameraOptions: mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(
          widget.punto.longitud!,
          widget.punto.latitud!,
        )),
        zoom: 15.0,
        pitch: 30,
        bearing: 0,
      ),
      onMapCreated: _onMiniMapCreated,
    );
  }

  Widget _buildRutaRelacionadaCard(RutaRelacionada r) {
    final tipoColors = {
      701: brandAmber,
      702: brandTerracota,
      703: brandEmerald,
      704: brandTeal,
    };
    final tipoLabels = {
      701: 'HISTÓRICA',
      702: 'GASTRONÓMICA',
      703: 'PANORÁMICA',
      704: 'MIXTA',
    };
    final color = tipoColors[r.idTipoRuta] ?? brandTeal;
    final label = tipoLabels[r.idTipoRuta] ?? 'RUTA';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: brandDark.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.route_rounded, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.nombre, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: brandDark)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: color, letterSpacing: 0.6,
              )),
            ),
          ]),
        ),
        Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: brandDark.withValues(alpha: 0.25)),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  TAB 2: TARIFAS Y HORARIOS
  // ─────────────────────────────────────
  Widget _buildTabTarifasHorarios() {
    final tienePrecios = widget.punto.precioNacional != null ||
        widget.punto.precioExtranjero != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            icon: Icons.access_time_rounded,
            iconColor: brandTeal,
            title: 'Horario de Atención',
            child: Column(children: [
              _buildHorarioRow('Lunes – Viernes', '09:00 – 17:00', true),
              _buildHorarioRow('Sábado',          '09:00 – 15:00', true),
              _buildHorarioRow('Domingo',         'Cerrado',        false),
            ]),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            icon: Icons.sell_rounded,
            iconColor: brandAmber,
            title: 'Precios de Acceso',
            child: Column(children: [
              _buildTarifaRow(
                icon: Icons.flight_land_rounded,
                label: 'Extranjeros',
                precio: widget.punto.precioExtranjero,
                moneda: 'Bs.',
                color: brandTerracota,
              ),
              if (tienePrecios) const SizedBox(height: 8),
              _buildTarifaRow(
                icon: Icons.person_rounded,
                label: 'Nacionales',
                precio: widget.punto.precioNacional,
                moneda: 'Bs.',
                color: brandTeal,
              ),
              if (!tienePrecios)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: brandEmerald),
                    const SizedBox(width: 6),
                    Text('Entrada libre',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: brandEmerald)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            icon: Icons.directions_rounded,
            iconColor: brandEmerald,
            title: 'Cómo llegar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTransporteRow(Icons.cable_rounded, 'Mi Teleférico', 'Línea Verde – Estación central'),
                const SizedBox(height: 8),
                _buildTransporteRow(Icons.directions_bus_rounded, 'Bus PumaKatari', 'Ruta al centro histórico'),
                const SizedBox(height: 8),
                _buildTransporteRow(Icons.local_taxi_rounded, 'Radio Taxi', 'Tarifa estimada Bs. 15–25'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: brandDark.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: brandDark)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildHorarioRow(String dia, String horario, bool abierto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: abierto ? brandEmerald : brandDark.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(dia, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: brandDark.withValues(alpha: 0.65))),
        const Spacer(),
        Text(horario, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: abierto ? brandDark : brandDark.withValues(alpha: 0.35))),
      ]),
    );
  }

  Widget _buildTarifaRow({
    required IconData icon,
    required String label,
    required double? precio,
    required String moneda,
    required Color color,
  }) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: brandDark)),
      const Spacer(),
      if (precio != null)
        Text(
          '$moneda ${precio.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w900, color: color),
        )
      else
        Text('Gratis', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: brandEmerald)),
    ]);
  }

  Widget _buildTransporteRow(IconData icon, String nombre, String detalle) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: brandEmerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: brandEmerald),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: brandDark)),
          const SizedBox(height: 2),
          Text(detalle, style: TextStyle(
            fontSize: 11, color: brandDark.withValues(alpha: 0.45))),
        ]),
      ),
    ]);
  }

  // ─────────────────────────────────────
  //  TAB 3: AUDIOGUÍAS
  // ─────────────────────────────────────
  Widget _buildTabAudioguias() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: brandTeal));
    }

    if (_audioguias.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: brandTeal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.headphones_rounded,
                size: 36, color: brandTeal.withValues(alpha: 0.50)),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin audioguías disponibles',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: brandDark.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 6),
            Text(
              'Próximamente en más idiomas',
              style: TextStyle(
                fontSize: 12, color: brandDark.withValues(alpha: 0.30)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: _audioguias.length,
      itemBuilder: (ctx, i) => _buildAudioguiaCard(_audioguias[i]),
    );
  }

  Widget _buildAudioguiaCard(AudioguiaData ag) {
    final isActiva = _audioguiaActiva?.id == ag.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isActiva) {
            _audioguiaActiva = null;
            _audioReproduciendo = false;
          } else {
            _audioguiaActiva = ag;
            _audioReproduciendo = true;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActiva ? brandTeal : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: brandDark.withValues(alpha: isActiva ? 0.10 : 0.05),
              blurRadius: isActiva ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: isActiva
                  ? const LinearGradient(
                      colors: [brandEmerald, brandTeal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isActiva ? null : brandTeal.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              boxShadow: isActiva
                  ? [BoxShadow(
                      color: brandTeal.withValues(alpha: 0.40),
                      blurRadius: 12, offset: const Offset(0, 3),
                    )]
                  : null,
            ),
            child: Icon(
              isActiva && _audioReproduciendo
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: isActiva ? Colors.white : brandTeal,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ag.titulo, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: brandDark)),
                const SizedBox(height: 3),
                Text(ag.descripcionCorta, style: TextStyle(
                  fontSize: 11, color: brandDark.withValues(alpha: 0.50), height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  _miniChip(Icons.language_rounded, _idiomaLabel(ag.idIdioma)),
                  const SizedBox(width: 6),
                  _miniChip(Icons.timer_rounded, _duracionLabel(ag.duracionSegundos)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: brandDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: brandDark.withValues(alpha: 0.40)),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: brandDark.withValues(alpha: 0.55))),
      ]),
    );
  }

  // ─────────────────────────────────────
  //  REPRODUCTOR FLOTANTE
  // ─────────────────────────────────────
  Widget _buildAudioPlayer() {
    if (_audioguiaActiva == null) return const SizedBox.shrink();
    final ag = _audioguiaActiva!;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandEmerald, brandTeal],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: brandTeal.withValues(alpha: 0.40),
            blurRadius: 24, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 0.35,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ag.titulo,
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _idiomaLabel(ag.idIdioma),
                    style: TextStyle(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.70)),
                  ),
                ],
              ),
            ),
            Row(children: [
              _audioBtn(Icons.replay_10_rounded, () {}),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _audioReproduciendo = !_audioReproduciendo),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 8, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _audioReproduciendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: brandEmerald, size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _audioBtn(Icons.forward_10_rounded, () {}),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() {
                  _audioguiaActiva = null;
                  _audioReproduciendo = false;
                }),
                child: Icon(Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.70), size: 20),
              ),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _audioBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ─────────────────────────────────────
  //  BOTTOM CTA — "Comenzar experiencia"
  //  → llama a homeState.abrirMapaConPoi (vía HomeNavigator)
  //  → cierra esta pantalla y cambia al tab Mapas
  //  → la barra de navegación del HomeScreen SIEMPRE visible
  // ─────────────────────────────────────
  Widget _buildBottomCta() {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: brandDark.withValues(alpha: 0.10),
            blurRadius: 20, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ENTRADA', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: brandDark.withValues(alpha: 0.40), letterSpacing: 0.8,
          )),
          const SizedBox(height: 2),
          Text(
            widget.punto.precioNacional != null
                ? 'Bs. ${widget.punto.precioNacional!.toStringAsFixed(0)}'
                : 'Gratis',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, color: brandDark),
          ),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _abrirMapaConEstePunto,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [brandEmerald, brandTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: brandTeal.withValues(alpha: 0.42),
                  blurRadius: 16, offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Comenzar experiencia',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
//  CUSTOM PAINTER
// ─────────────────────────────────────────

class _LocationMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF0F988A).withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double y = 20; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = 20; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(
      Offset(cx, cy), 30,
      Paint()..color = const Color(0xFF0F988A).withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      Offset(cx, cy), 30,
      Paint()
        ..color = const Color(0xFF0F988A).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()..color = const Color(0xFF0F988A),
    );
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}