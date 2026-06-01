import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'routes_view.dart';

// ─────────────────────────────────────────
//  MODELO RutaPunto
// ─────────────────────────────────────────

class RutaPunto {
  final int id;
  final int orden;
  final int idPuntoTuristico;
  final String nombrePunto;
  final String descripcionPunto;
  final String? imagenUrl;
  final bool tieneAudioguia;
  final int? duracionAudioguiaSegundos;
  final double? latitud;
  final double? longitud;
  final int idCategoria;

  const RutaPunto({
    required this.id,
    required this.orden,
    required this.idPuntoTuristico,
    required this.nombrePunto,
    required this.descripcionPunto,
    this.imagenUrl,
    this.tieneAudioguia = false,
    this.duracionAudioguiaSegundos,
    this.latitud,
    this.longitud,
    this.idCategoria = 401,
  });

  factory RutaPunto.fromMap(Map<String, dynamic> map) {
    final punto      = map['punto_turistico'] as Map<String, dynamic>? ?? {};
    final audioguias = punto['audioguias'] as List?;
    return RutaPunto(
      id:                        map['id'] as int,
      orden:                     map['orden'] as int? ?? 0,
      idPuntoTuristico:          map['id_punto_turistico'] as int,
      nombrePunto:               punto['nombre'] as String? ?? '',
      descripcionPunto:          punto['descripcion'] as String? ?? '',
      imagenUrl:                 punto['imagen_url'] as String?,
      tieneAudioguia:            audioguias != null && audioguias.isNotEmpty,
      duracionAudioguiaSegundos: audioguias != null && audioguias.isNotEmpty
          ? audioguias.first['duracion_segundos'] as int?
          : null,
      latitud:     (punto['latitud'] as num?)?.toDouble(),
      longitud:    (punto['longitud'] as num?)?.toDouble(),
      idCategoria: punto['id_categoria'] as int? ?? 401,
    );
  }

  RutaPuntoSimple toSimple() => RutaPuntoSimple(
    id:          idPuntoTuristico,
    nombre:      nombrePunto,
    descripcion: descripcionPunto,
    latitud:     latitud,
    longitud:    longitud,
    imagenUrl:   imagenUrl,
    idCategoria: idCategoria,
  );
}

// ─────────────────────────────────────────
//  ROUTE DETAIL SCREEN
// ─────────────────────────────────────────

class RouteDetailScreen extends StatefulWidget {
  final Ruta ruta;
  // Usa HomeNavigator (interfaz pública) en lugar de _HomeScreenState (privada)
  final HomeNavigator homeState;

  const RouteDetailScreen({
    super.key,
    required this.ruta,
    required this.homeState,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen>
    with TickerProviderStateMixin {

  static const Color bgLight        = Color(0xFFF2FBFF);
  static const Color brandTeal      = Color(0xFF0F988A);
  static const Color brandEmerald   = Color(0xFF197D61);
  static const Color brandAmber     = Color(0xFFD27817);
  static const Color brandDark      = Color(0xFF23373E);
  static const Color brandTerracota = Color(0xFF7A3928);

  bool _isLoading = true;
  List<RutaPunto> _puntos = [];
  String? _error;
  bool _isFavorite = false;
  int? _expandedIndex;

  mbx.MapboxMap? _miniMap;
  bool _miniMapReady = false;

  late final TabController _tabController;
  late final AnimationController _heroCtrl;
  late final AnimationController _listCtrl;
  late final AnimationController _fabCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _listCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fabCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _heroCtrl.dispose();
    _listCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────
  //  SUPABASE
  // ─────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final res = await Supabase.instance.client
          .from('ruta_puntos')
          .select('''
            id, orden, id_punto_turistico,
            punto_turistico (
              id, nombre, descripcion, imagen_url,
              latitud, longitud, id_categoria,
              audioguias (id, duracion_segundos)
            )
          ''')
          .eq('id_ruta', widget.ruta.id)
          .order('orden');

      if (!mounted) return;
      setState(() {
        _puntos = (res as List).map((e) => RutaPunto.fromMap(e)).toList();
        _isLoading = false;
      });

      await Future.delayed(const Duration(milliseconds: 100));
      _heroCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _listCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _fabCtrl.forward();

      if (_miniMapReady && _miniMap != null) {
        await _drawRouteOnMiniMap();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
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
      marginBottom: 4, marginLeft: 4,
    ));
    map.attribution.updateSettings(mbx.AttributionSettings(enabled: false));
    map.gestures.updateSettings(mbx.GesturesSettings(
      scrollEnabled: true,
      rotateEnabled: false,
      pinchToZoomEnabled: true,
      doubleTapToZoomInEnabled: true,
      pitchEnabled: false,
    ));

    if (!_isLoading && _puntos.isNotEmpty) {
      _drawRouteOnMiniMap();
    }
  }

  Future<void> _drawRouteOnMiniMap() async {
    if (_miniMap == null) return;

    final puntosConCoords = _puntos
        .where((p) => p.latitud != null && p.longitud != null)
        .toList();

    if (puntosConCoords.isEmpty) return;

    try {
      final manager = await _miniMap!.annotations.createPointAnnotationManager();
      for (int i = 0; i < puntosConCoords.length; i++) {
        final p = puntosConCoords[i];
        await manager.create(mbx.PointAnnotationOptions(
          geometry: mbx.Point(coordinates: mbx.Position(p.longitud!, p.latitud!)),
          textField: '${i + 1}',
          textSize: 14,
          textColor: Colors.white.value,
          iconColor: brandTeal.value,
          iconSize: 1.0,
        ));
      }

      if (puntosConCoords.length >= 2) {
        final polyManager = await _miniMap!.annotations.createPolylineAnnotationManager();
        await polyManager.create(mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(
            coordinates: puntosConCoords
                .map((p) => mbx.Position(p.longitud!, p.latitud!))
                .toList(),
          ),
          lineWidth: 3.0,
          lineColor: brandTeal.value,
        ));
      }

      if (puntosConCoords.length == 1) {
        await _miniMap!.flyTo(
          mbx.CameraOptions(
            center: mbx.Point(coordinates: mbx.Position(
              puntosConCoords.first.longitud!,
              puntosConCoords.first.latitud!,
            )),
            zoom: 14.5,
          ),
          mbx.MapAnimationOptions(duration: 500),
        );
      } else {
        double minLat = puntosConCoords.first.latitud!;
        double maxLat = puntosConCoords.first.latitud!;
        double minLng = puntosConCoords.first.longitud!;
        double maxLng = puntosConCoords.first.longitud!;

        for (final p in puntosConCoords) {
          minLat = math.min(minLat, p.latitud!);
          maxLat = math.max(maxLat, p.latitud!);
          minLng = math.min(minLng, p.longitud!);
          maxLng = math.max(maxLng, p.longitud!);
        }

        await _miniMap!.flyTo(
          mbx.CameraOptions(
            center: mbx.Point(coordinates: mbx.Position(
              (minLng + maxLng) / 2,
              (minLat + maxLat) / 2,
            )),
            zoom: 13.5,
          ),
          mbx.MapAnimationOptions(duration: 500),
        );
      }
    } catch (e) {}
  }

  // ─────────────────────────────────────
  //  NAVEGACIÓN → MAPA CON BARRA NAV VISIBLE
  //
  //  Usa homeState.abrirMapaConRuta (vía HomeNavigator) para:
  //    1. Hacer pop de esta pantalla
  //    2. Cambiar al tab Mapas del IndexedStack del HomeScreen
  //    3. La barra de nav (Inicio/Mapas/Wali IA/Perfil) siempre visible
  // ─────────────────────────────────────
  void _abrirMapaCompleto() {
    if (!mounted) return;

    final puntosSimples = _puntos
        .where((p) => p.latitud != null && p.longitud != null)
        .map((p) => p.toSimple())
        .toList();

    if (puntosSimples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Esta ruta no tiene coordenadas disponibles todavía'),
        backgroundColor: Color(0xFF0F988A),
      ));
      return;
    }

    widget.homeState.abrirMapaConRuta(
      id:          widget.ruta.id,
      nombre:      widget.ruta.nombre,
      descripcion: widget.ruta.descripcion,
      iaGenerado:  widget.ruta.iaGenerado,
      puntos:      puntosSimples,
    );
  }

  // ─────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────
  String get _tipoRutaLabel {
    switch (widget.ruta.idTipoRuta) {
      case 701: return 'HISTÓRICA';
      case 702: return 'GASTRONÓMICA';
      case 703: return 'PANORÁMICA';
      case 704: return 'MIXTA';
      default:  return 'RUTA';
    }
  }

  Color get _tipoRutaColor {
    switch (widget.ruta.idTipoRuta) {
      case 701: return const Color(0xFF5C3D11);
      case 702: return const Color(0xFF7A3928);
      case 703: return brandEmerald;
      case 704: return brandTeal;
      default:  return brandTeal;
    }
  }

  String get _dificultadLabel {
    if (_puntos.length <= 2) return 'Fácil';
    if (_puntos.length <= 4) return 'Moderada';
    return 'Intensa';
  }

  String get _duracionEstimada {
    final total = _puntos.fold<int>(0, (sum, p) => sum + (p.duracionAudioguiaSegundos ?? 1800));
    final minutos = (total / 60).ceil();
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  String get _distanciaEstimada {
    final metros = _puntos.length * 600;
    return metros >= 1000
        ? '${(metros / 1000).toStringAsFixed(1)} km'
        : '$metros m';
  }

  String get _costoEstimado => 'Gratis – Bs. 30';

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
                      _buildTabRecorrido(),
                      _buildTabTarifasHorarios(),
                      _buildTabInfoGeneral(),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: brandEmerald,
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_tipoRutaColor, brandTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8, childAspectRatio: 1,
                  ),
                  itemCount: 120,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  stops: const [0.3, 1.0],
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
                    _buildBadge(_tipoRutaLabel, _tipoRutaColor.withValues(alpha: 0.85)),
                    if (widget.ruta.iaGenerado) ...[
                      const SizedBox(width: 8),
                      _buildBadge('IA GENERADO', Colors.white.withValues(alpha: 0.20), border: true),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    widget.ruta.nombre,
                    style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.15, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(_isLoading ? '...' : _duracionEstimada,
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    const Icon(Icons.straighten_rounded, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(_isLoading ? '...' : _distanciaEstimada,
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ],
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
        fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8)),
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
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Recorrido'), Tab(text: 'Tarifas'), Tab(text: 'Info General')],
      ),
    );
  }

  // ─────────────────────────────────────
  //  TAB 1: RECORRIDO
  // ─────────────────────────────────────
  Widget _buildTabRecorrido() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMiniMapRuta(),
          _buildInfoChips(),
          _buildCronogramaHeader(),
          if (_isLoading)
            _buildSkeletonCronograma()
          else if (_error != null)
            _buildError()
          else
            ..._puntos.asMap().entries.map((e) => _buildCronogramaItem(e.value, e.key)),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildMiniMapRuta() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    mbx.MapboxOptions.setAccessToken(token);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mapa de la ruta',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
              color: brandDark, letterSpacing: -0.2)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: brandTeal.withValues(alpha: 0.20)),
              ),
              child: Stack(
                children: [
                  mbx.MapWidget(
                    styleUri: mbx.MapboxStyles.STANDARD,
                    cameraOptions: mbx.CameraOptions(
                      center: mbx.Point(coordinates: mbx.Position(-68.1336, -16.4930)),
                      zoom: 13.5,
                      pitch: 20,
                      bearing: 0,
                    ),
                    onMapCreated: _onMiniMapCreated,
                  ),
                  if (!_isLoading && _puntos.isNotEmpty)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: brandDark.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.place_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${_puntos.length} paradas',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                  // Botón "Ver Mapa Detallado" → usa homeState para mantener barra de nav visible
                  Positioned(
                    bottom: 14, left: 0, right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _abrirMapaCompleto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: brandTeal,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: brandTeal.withValues(alpha: 0.45),
                                blurRadius: 16, offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.map_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Ver Mapa Detallado',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChips() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.ruta.descripcion,
            style: TextStyle(fontSize: 14, color: brandDark.withValues(alpha: 0.65), height: 1.5)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _statCard(icon: Icons.directions_walk_rounded, label: 'Dificultad',
              value: _isLoading ? '...' : _dificultadLabel, color: brandTeal)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(icon: Icons.place_rounded, label: 'Paradas',
              value: _isLoading ? '...' : '${_puntos.length} lugares', color: brandAmber)),
            const SizedBox(width: 10),
            Expanded(child: _statCard(icon: Icons.terrain_rounded, label: 'Altitud',
              value: '3,650 m', color: brandEmerald)),
          ]),
        ],
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label,
      required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: brandDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500,
            color: brandDark.withValues(alpha: 0.45))),
        ],
      ),
    );
  }

  Widget _buildCronogramaHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(children: [
        const Text('Cronograma del Recorrido',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
            color: brandDark, letterSpacing: -0.2)),
        const Spacer(),
        if (!_isLoading && _puntos.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: brandTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${_puntos.length} paradas',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: brandTeal)),
          ),
      ]),
    );
  }

  Widget _buildCronogramaItem(RutaPunto punto, int index) {
    final isLast     = index == _puntos.length - 1;
    final isExpanded = _expandedIndex == index;
    final iconData   = _iconForIndex(index);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: index == 0 ? brandTeal : brandDark.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index == 0 ? brandTeal : brandDark.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: index == 0
                          ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18)
                          : Text('${index + 1}',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800,
                                color: brandDark.withValues(alpha: 0.55))),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: brandDark.withValues(alpha: 0.10),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isExpanded ? brandTeal.withValues(alpha: 0.35) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: brandDark.withValues(alpha: isExpanded ? 0.10 : 0.05),
                        blurRadius: isExpanded ? 16 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: brandTeal.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(child: Icon(iconData, color: brandTeal, size: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(punto.nombrePunto,
                                    style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w800, color: brandDark)),
                                  const SizedBox(height: 3),
                                  Text(punto.descripcionPunto,
                                    style: TextStyle(
                                      fontSize: 11, color: brandDark.withValues(alpha: 0.50), height: 1.3),
                                    maxLines: isExpanded ? 5 : 1,
                                    overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: brandDark.withValues(alpha: 0.30), size: 20,
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded) ...[
                        Container(
                          height: 1,
                          color: brandDark.withValues(alpha: 0.06),
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                          child: Column(
                            children: [
                              Row(children: [
                                Icon(Icons.access_time_rounded,
                                  size: 13, color: brandDark.withValues(alpha: 0.40)),
                                const SizedBox(width: 6),
                                Text(_tiempoEnLugar(punto),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: brandDark.withValues(alpha: 0.50))),
                                const Spacer(),
                                if (punto.tieneAudioguia) _audioguiaChip(punto),
                              ]),
                              const SizedBox(height: 10),
                              // "Ver en el mapa" → punto individual (push normal,
                              // ya que el RouteDetailScreen no viene del tab Mapas)
                              GestureDetector(
                                onTap: () {
                                  if (punto.latitud != null) {
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => RoutesViewWrapper(
                                        targetId:          punto.idPuntoTuristico,
                                        targetNombre:      punto.nombrePunto,
                                        targetDescripcion: punto.descripcionPunto,
                                        targetCategoria:   'Sitio Turístico',
                                        targetIdCategoria: punto.idCategoria,
                                        targetLat:         punto.latitud,
                                        targetLng:         punto.longitud,
                                        targetPrecioNacional: null,
                                        targetImagenUrl:   punto.imagenUrl,
                                      ),
                                    ));
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: brandTeal.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: brandTeal.withValues(alpha: 0.20)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.map_rounded, size: 14, color: brandTeal),
                                      SizedBox(width: 6),
                                      Text('Ver en el mapa',
                                        style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: brandTeal)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioguiaChip(RutaPunto punto) {
    final segundos = punto.duracionAudioguiaSegundos ?? 0;
    final minutos = (segundos / 60).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [brandEmerald, brandTeal]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.headphones_rounded, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text('Audioguía${minutos > 0 ? " · ${minutos}m" : ""}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  String _tiempoEnLugar(RutaPunto punto) {
    final seg = punto.duracionAudioguiaSegundos ?? 1800;
    final min = (seg / 60).ceil();
    return '≈ $min min en este lugar';
  }

  IconData _iconForIndex(int index) {
    const icons = [
      Icons.account_balance_rounded,
      Icons.home_work_rounded,
      Icons.landscape_rounded,
      Icons.restaurant_rounded,
      Icons.shopping_bag_rounded,
      Icons.museum_rounded,
    ];
    return icons[index % icons.length];
  }

  // ─────────────────────────────────────
  //  TAB 2: TARIFAS Y HORARIOS
  // ─────────────────────────────────────
  Widget _buildTabTarifasHorarios() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            icon: Icons.sell_rounded, iconColor: brandAmber,
            title: 'Costo Estimado de la Ruta',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    brandTeal.withValues(alpha: 0.08),
                    brandEmerald.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brandTeal.withValues(alpha: 0.15)),
                ),
                child: Column(children: [
                  Text(_costoEstimado,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: brandTeal)),
                  const SizedBox(height: 4),
                  Text('precio estimado por persona',
                    style: TextStyle(fontSize: 11, color: brandDark.withValues(alpha: 0.45))),
                ]),
              ),
              const SizedBox(height: 16),
              if (!_isLoading && _puntos.isNotEmpty) ...[
                Text('Desglose por lugar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: brandDark.withValues(alpha: 0.70))),
                const SizedBox(height: 10),
                ..._puntos.map((p) => _buildPuntoCostRow(p)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            icon: Icons.access_time_rounded, iconColor: brandTeal,
            title: 'Horarios Sugeridos',
            child: Column(children: [
              _buildHorarioRuta('Inicio de recorrido', '09:00 AM', true),
              _buildHorarioRuta('Mejor época del día', 'Mañana (9–12h)', true),
              _buildHorarioRuta('Duración estimada', _isLoading ? '...' : _duracionEstimada, true),
              _buildHorarioRuta('Distancia total', _isLoading ? '...' : _distanciaEstimada, true),
              _buildHorarioRuta('Domingo', 'Algunos lugares cerrados', false),
            ]),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            icon: Icons.directions_rounded, iconColor: brandEmerald,
            title: 'Transporte Recomendado',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildTransporteRow(Icons.cable_rounded, 'Mi Teleférico', 'Bs. 3 por tramo – Ideal para miradores'),
              const SizedBox(height: 8),
              _buildTransporteRow(Icons.directions_bus_rounded, 'Bus PumaKatari', 'Bs. 3 – Centro histórico'),
              const SizedBox(height: 8),
              _buildTransporteRow(Icons.local_taxi_rounded, 'Radio Taxi', 'Bs. 15–40 según zona'),
              const SizedBox(height: 8),
              _buildTransporteRow(Icons.directions_walk_rounded, 'A pie', 'Recomendado entre puntos del centro'),
            ]),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            icon: Icons.account_balance_wallet_rounded, iconColor: brandTerracota,
            title: 'Presupuesto Total Estimado',
            child: Column(children: [
              _buildPresupuestoRow('Entradas a lugares', 'Gratis – Bs. 20'),
              _buildPresupuestoRow('Transporte (ida y vuelta)', 'Bs. 6 – Bs. 80'),
              _buildPresupuestoRow('Audioguías', 'Incluidas en la app'),
              const SizedBox(height: 8),
              Container(height: 1, color: brandDark.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total estimado',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: brandDark)),
                const Text('Bs. 6 – Bs. 100',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: brandTeal)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPuntoCostRow(RutaPunto p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 6, height: 6,
          decoration: const BoxDecoration(color: brandTeal, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(p.nombrePunto,
          style: TextStyle(fontSize: 12, color: brandDark.withValues(alpha: 0.65)))),
        const Text('Gratis',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: brandEmerald)),
      ]),
    );
  }

  Widget _buildHorarioRuta(String label, String valor, bool activo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(
            color: activo ? brandEmerald : brandDark.withValues(alpha: 0.25),
            shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: brandDark.withValues(alpha: 0.65))),
        const Spacer(),
        Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: activo ? brandDark : brandDark.withValues(alpha: 0.35))),
      ]),
    );
  }

  Widget _buildPresupuestoRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: brandDark.withValues(alpha: 0.65))),
        Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: brandDark.withValues(alpha: 0.75))),
      ]),
    );
  }

  Widget _buildTransporteRow(IconData icon, String nombre, String detalle) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: brandEmerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: brandEmerald)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brandDark)),
        const SizedBox(height: 2),
        Text(detalle, style: TextStyle(fontSize: 11, color: brandDark.withValues(alpha: 0.45))),
      ])),
    ]);
  }

  Widget _buildSectionCard({required IconData icon, required Color iconColor,
      required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: brandDark.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: iconColor)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: brandDark)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  // ─────────────────────────────────────
  //  TAB 3: INFO GENERAL
  // ─────────────────────────────────────
  Widget _buildTabInfoGeneral() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionCard(
          icon: Icons.info_outline_rounded, iconColor: brandTeal,
          title: 'Sobre esta ruta',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.ruta.descripcion,
              style: TextStyle(fontSize: 14, color: brandDark.withValues(alpha: 0.65), height: 1.6)),
            if (widget.ruta.iaGenerado) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandTeal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brandTeal.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: brandTeal),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Esta ruta fue generada por Wali IA basándose en tus preferencias turísticas.',
                    style: TextStyle(fontSize: 12, color: brandTeal, height: 1.4))),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          icon: Icons.bar_chart_rounded, iconColor: brandAmber,
          title: 'Estadísticas del Recorrido',
          child: Column(children: [
            _buildStatRow(Icons.flag_rounded, 'Paradas totales',
              _isLoading ? '...' : '${_puntos.length} lugares', brandTeal),
            const SizedBox(height: 10),
            _buildStatRow(Icons.access_time_rounded, 'Duración estimada',
              _isLoading ? '...' : _duracionEstimada, brandAmber),
            const SizedBox(height: 10),
            _buildStatRow(Icons.straighten_rounded, 'Distancia total',
              _isLoading ? '...' : _distanciaEstimada, brandEmerald),
            const SizedBox(height: 10),
            _buildStatRow(Icons.trending_up_rounded, 'Dificultad',
              _isLoading ? '...' : _dificultadLabel, brandTerracota),
            const SizedBox(height: 10),
            _buildStatRow(Icons.terrain_rounded, 'Altitud promedio', '3,650 m s.n.m.', brandDark),
            if (_puntos.any((p) => p.tieneAudioguia)) ...[
              const SizedBox(height: 10),
              _buildStatRow(Icons.headphones_rounded, 'Audioguías disponibles',
                '${_puntos.where((p) => p.tieneAudioguia).length} lugares', brandTeal),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          icon: Icons.route_rounded, iconColor: _tipoRutaColor,
          title: 'Tipo de Recorrido',
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _tipoRutaColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10)),
              child: Text(_tipoRutaLabel,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _tipoRutaColor))),
            const SizedBox(width: 12),
            Expanded(child: Text(_descripcionTipoRuta,
              style: TextStyle(fontSize: 12, color: brandDark.withValues(alpha: 0.55), height: 1.4))),
          ]),
        ),
      ]),
    );
  }

  String get _descripcionTipoRuta {
    switch (widget.ruta.idTipoRuta) {
      case 701: return 'Recorre los principales hitos históricos y patrimoniales de La Paz.';
      case 702: return 'Explora la gastronomía típica paceña en sus mejores mercados y restaurantes.';
      case 703: return 'Disfruta de las mejores vistas panorámicas de la ciudad y el Illimani.';
      case 704: return 'Combina lo mejor de la cultura, gastronomía y paisajes de La Paz.';
      default:  return 'Recorrido turístico por los puntos más destacados de la ciudad.';
    }
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 13, color: brandDark.withValues(alpha: 0.65))),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: brandDark)),
    ]);
  }

  // ─────────────────────────────────────
  //  SKELETONS Y ERROR
  // ─────────────────────────────────────
  Widget _buildSkeletonCronograma() {
    return Column(children: List.generate(3, (_) => _SkeletonCronogramaItem()));
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Column(children: [
        const Icon(Icons.wifi_off_rounded, size: 30, color: brandTerracota),
        const SizedBox(height: 8),
        Text('No se pudo cargar la ruta',
          style: TextStyle(color: brandDark.withValues(alpha: 0.55))),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _loadData,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: brandTeal, borderRadius: BorderRadius.circular(12)),
            child: const Text('Reintentar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ])),
    );
  }

  // ─────────────────────────────────────
  //  BOTTOM CTA — "Comenzar experiencia"
  //  → usa homeState.abrirMapaConRuta (vía HomeNavigator)
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
          BoxShadow(color: brandDark.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DIFICULTAD', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: brandDark.withValues(alpha: 0.40), letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(_isLoading ? '...' : _dificultadLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: brandDark)),
        ]),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ALTITUD', style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: brandDark.withValues(alpha: 0.40), letterSpacing: 0.8)),
          const SizedBox(height: 2),
          const Text('3,650m',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: brandDark)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _abrirMapaCompleto,
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
                BoxShadow(color: brandTeal.withValues(alpha: 0.42),
                  blurRadius: 16, offset: const Offset(0, 5)),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Comenzar experiencia',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
//  SKELETON
// ─────────────────────────────────────────

class _SkeletonCronogramaItem extends StatefulWidget {
  @override
  State<_SkeletonCronogramaItem> createState() => _SkeletonCronogramaItemState();
}

class _SkeletonCronogramaItemState extends State<_SkeletonCronogramaItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(
            const Color(0xFFDCF0FA), const Color(0xFFBCD8EC), _anim.value)!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 14),
            Expanded(child: Container(height: 72,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)))),
          ]),
        );
      },
    );
  }
}