import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// =============================================================================
//  WRAPPER PÚBLICO — un solo POI
// =============================================================================

class RoutesViewWrapper extends StatelessWidget {
  final double? targetLat;
  final double? targetLng;
  final String targetNombre;
  final String targetCategoria;
  final String targetDescripcion;
  final double? targetPrecioNacional;
  final String? targetImagenUrl;
  final int targetIdCategoria;
  final int targetId;

  const RoutesViewWrapper({
    super.key,
    required this.targetLat,
    required this.targetLng,
    required this.targetNombre,
    required this.targetCategoria,
    required this.targetDescripcion,
    required this.targetPrecioNacional,
    required this.targetImagenUrl,
    required this.targetIdCategoria,
    required this.targetId,
  });

  @override
  Widget build(BuildContext context) => RoutesView(
    initialPoi: _PoiData(
      id: targetId,
      nombre: targetNombre,
      descripcion: targetDescripcion,
      idCategoria: targetIdCategoria,
      latitud: targetLat,
      longitud: targetLng,
      precioNacional: targetPrecioNacional,
      imagenUrl: targetImagenUrl,
    ),
  );
}

// =============================================================================
//  WRAPPER PÚBLICO — ruta completa con múltiples puntos
//
//  Uso desde RouteDetailScreen:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => RoutesViewRutaWrapper(
//        rutaId: ruta.id,
//        rutaNombre: ruta.nombre,
//        rutaDescripcion: ruta.descripcion,
//        rutaIaGenerado: ruta.iaGenerado,
//        puntos: _puntos.map((p) => p.toSimple()).toList(),
//      ),
//    ));
// =============================================================================

class RutaPuntoSimple {
  final int id;
  final String nombre;
  final String descripcion;
  final double? latitud;
  final double? longitud;
  final String? imagenUrl;
  final int idCategoria;

  const RutaPuntoSimple({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.latitud,
    this.longitud,
    this.imagenUrl,
    this.idCategoria = 401,
  });
}

class RoutesViewRutaWrapper extends StatelessWidget {
  final int rutaId;
  final String rutaNombre;
  final String rutaDescripcion;
  final bool rutaIaGenerado;
  final List<RutaPuntoSimple> puntos;

  const RoutesViewRutaWrapper({
    super.key,
    required this.rutaId,
    required this.rutaNombre,
    required this.rutaDescripcion,
    required this.rutaIaGenerado,
    required this.puntos,
  });

  @override
  Widget build(BuildContext context) => RoutesView(
    initialRuta: _RutaData(
      id: rutaId,
      nombre: rutaNombre,
      descripcion: rutaDescripcion,
      iaGenerado: rutaIaGenerado,
      puntos: puntos.map((p) => _PoiData(
        id: p.id,
        nombre: p.nombre,
        descripcion: p.descripcion,
        idCategoria: p.idCategoria,
        latitud: p.latitud,
        longitud: p.longitud,
        imagenUrl: p.imagenUrl,
      )).toList(),
    ),
  );
}

// =============================================================================
//  MODELOS INTERNOS
// =============================================================================

class _PoiData {
  final int id;
  final String nombre;
  final String descripcion;
  final int idCategoria;
  final double? latitud;
  final double? longitud;
  final double? precioNacional;
  final double? precioExtranjero;
  final String? imagenUrl;
  final bool tieneAudioguia;

  const _PoiData({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.idCategoria,
    this.latitud,
    this.longitud,
    this.precioNacional,
    this.precioExtranjero,
    this.imagenUrl,
    this.tieneAudioguia = false,
  });

  factory _PoiData.fromMap(Map<String, dynamic> map) {
    final audioguias = map['audioguias'] as List?;
    return _PoiData(
      id: map['id'] as int,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      idCategoria: map['id_categoria'] as int? ?? 401,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      precioNacional: (map['precio_nacional'] as num?)?.toDouble(),
      precioExtranjero: (map['precio_extranjero'] as num?)?.toDouble(),
      imagenUrl: map['imagen_url'] as String?,
      tieneAudioguia: audioguias != null && audioguias.isNotEmpty,
    );
  }

  String get categoriaLabel {
    switch (idCategoria) {
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

  String get icono {
    switch (idCategoria) {
      case 401: return '🏛️';
      case 402: return '🏔️';
      case 403: return '🌿';
      case 404: return '🚡';
      case 405: return '⛪';
      case 406: return '🏪';
      case 407: return '🛍️';
      default:  return '📍';
    }
  }

  String get precioLabel {
    if (precioNacional != null && precioNacional! > 0) {
      return 'Bs. ${precioNacional!.toStringAsFixed(0)}';
    }
    return 'Gratis';
  }
}

class _RutaData {
  final int id;
  final String nombre;
  final String descripcion;
  final bool iaGenerado;
  final List<_PoiData> puntos;

  const _RutaData({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.iaGenerado,
    required this.puntos,
  });
}

/// Un paso de navegación con coordenada exacta del waypoint
class _StepInstruction {
  final String instruccion;
  final double distanciaMetros;
  final String maneuver;
  final double? waypointLng; // coordenada del punto donde ocurre esta maniobra
  final double? waypointLat;

  const _StepInstruction({
    required this.instruccion,
    required this.distanciaMetros,
    required this.maneuver,
    this.waypointLng,
    this.waypointLat,
  });

  IconData get icon {
    if (maneuver.contains('left'))        return Icons.turn_left_rounded;
    if (maneuver.contains('right'))       return Icons.turn_right_rounded;
    if (maneuver.contains('sharp left'))  return Icons.turn_sharp_left_rounded;
    if (maneuver.contains('sharp right')) return Icons.turn_sharp_right_rounded;
    if (maneuver.contains('uturn'))       return Icons.u_turn_left_rounded;
    if (maneuver.contains('arrive'))      return Icons.location_on_rounded;
    if (maneuver.contains('depart'))      return Icons.my_location_rounded;
    return Icons.straight_rounded;
  }
}

// =============================================================================
//  ROUTES VIEW — MAPA PRINCIPAL
// =============================================================================

class RoutesView extends StatefulWidget {
  final _PoiData?  initialPoi;
  final _RutaData? initialRuta;

  const RoutesView({super.key, this.initialPoi, this.initialRuta});

  @override
  State<RoutesView> createState() => _RoutesViewState();
}

class _RoutesViewState extends State<RoutesView> with TickerProviderStateMixin {

  // ── COLORES ──
  static const Color brandTeal    = Color(0xFF0F988A);
  static const Color brandEmerald = Color(0xFF197D61);
  static const Color brandAmber   = Color(0xFFD27817);
  static const Color brandDark    = Color(0xFF23373E);
  static const Color glassWhite   = Color(0xF8FFFFFF);

  // ── DATOS ──
  List<_PoiData>  _allPois  = [];
  List<_RutaData> _allRutas = [];
  bool _poisLoaded = false;

  // ── MAPA ──
  mbx.MapboxMap? _mapboxMap;
  bool _mapReady = false;
  mbx.PointAnnotationManager?    _annotationManager;
  mbx.PolylineAnnotationManager? _polylineManager;
  // Manager separado para marcadores numerados de la ruta inicial
  mbx.PointAnnotationManager?    _routeMarkerManager;

  // ── UBICACIÓN ──
  StreamSubscription<geo.Position>? _positionStream;
  geo.Position? _userPosition;
  double _userBearing = 0.0; // orientación del usuario en grados

  // ── BÚSQUEDA ──
  final TextEditingController _searchCtrl = TextEditingController();
  List<_PoiData> _searchResults  = [];
  bool _showSearchResults = false;
  final FocusNode _searchFocus = FocusNode();

  // ── SELECCIÓN ──
  _PoiData?  _selectedPoi;
  _RutaData? _selectedRuta;

  // ── NAVEGACIÓN ──
  bool     _navActiva            = false;
  bool     _showNavBanner        = false;
  String   _navDistancia         = '';
  String   _navTiempo            = '';
  String   _navInstruccionActual = '';
  String   _navProximaInstruccion = '';
  IconData _navIconoActual       = Icons.straight_rounded;
  IconData _navIconoProximo      = Icons.straight_rounded;
  String   _navDistanciaAlPaso   = ''; // distancia al siguiente giro
  List<_StepInstruction> _navSteps = [];
  int _currentStepIndex = 0;
  bool _modoNavegacion  = false;
  bool _camaraLibre     = false; // true cuando el usuario mueve el mapa manualmente

  // ── ANIMACIONES ──
  late final AnimationController _sheetCtrl;
  late final Animation<double>   _sheetAnim;
  late final AnimationController _fabCtrl;
  late final Animation<double>   _fabAnim;
  late final AnimationController _bannerCtrl;
  late final Animation<double>   _bannerAnim;
  late final AnimationController _navPanelCtrl;
  late final Animation<double>   _navPanelAnim;

  // ===========================================================================
  //  LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _sheetCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _sheetAnim   = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic);
    _fabCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fabAnim     = CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOutBack);
    _bannerCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _bannerAnim  = CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutCubic);
    _navPanelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _navPanelAnim = CurvedAnimation(parent: _navPanelCtrl, curve: Curves.easeOutCubic);

    _searchCtrl.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) setState(() => _showSearchResults = false);
    });

    _requestLocation();
    _loadData();

    if (widget.initialPoi != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handlePoiTap(widget.initialPoi!);
      });
    }
    if (widget.initialRuta != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRutaTap(widget.initialRuta!);
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _sheetCtrl.dispose();
    _fabCtrl.dispose();
    _bannerCtrl.dispose();
    _navPanelCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ===========================================================================
  //  DATOS SUPABASE
  // ===========================================================================

  Future<void> _loadData() async {
    await Future.wait([_loadPoisFromSupabase(), _loadRutasFromSupabase()]);
  }

  Future<void> _loadPoisFromSupabase() async {
    try {
      final res = await Supabase.instance.client
          .from('punto_turistico')
          .select('id, nombre, descripcion, latitud, longitud, id_categoria, precio_nacional, precio_extranjero, imagen_url, audioguias (id)')
          .eq('estado', true)
          .not('latitud', 'is', null)
          .not('longitud', 'is', null)
          .limit(50);

      if (!mounted) return;
      final pois = (res as List).map((e) => _PoiData.fromMap(e)).toList();
      if (widget.initialPoi != null && !pois.any((p) => p.id == widget.initialPoi!.id)) {
        pois.insert(0, widget.initialPoi!);
      }
      setState(() { _allPois = pois; _poisLoaded = true; });
      if (_mapReady) await _addPoiMarkers();
    } catch (_) {
      if (!mounted) return;
      final fb = _fallbackPois;
      if (widget.initialPoi != null && !fb.any((p) => p.id == widget.initialPoi!.id)) {
        fb.insert(0, widget.initialPoi!);
      }
      setState(() { _allPois = fb; _poisLoaded = true; });
      if (_mapReady) await _addPoiMarkers();
    }
  }

  Future<void> _loadRutasFromSupabase() async {
    try {
      final rutasRes = await Supabase.instance.client
          .from('rutas')
          .select('id, nombre, descripcion, ia_generado')
          .eq('estado', true)
          .limit(20);

      final rutas = <_RutaData>[];
      for (final rm in (rutasRes as List)) {
        final rid = rm['id'] as int;
        final pr = await Supabase.instance.client
            .from('ruta_puntos')
            .select('orden, punto_turistico:id_punto_turistico (id, nombre, descripcion, latitud, longitud, id_categoria, precio_nacional, precio_extranjero, imagen_url)')
            .eq('id_ruta', rid)
            .order('orden', ascending: true);

        final puntos = (pr as List)
            .map((p) {
              final poi = p['punto_turistico'];
              if (poi == null) return null;
              return _PoiData.fromMap(poi as Map<String, dynamic>);
            })
            .whereType<_PoiData>()
            .where((p) => p.latitud != null)
            .toList();

        if (puntos.isNotEmpty) {
          rutas.add(_RutaData(
            id: rid,
            nombre: rm['nombre'] as String? ?? 'Ruta',
            descripcion: rm['descripcion'] as String? ?? '',
            iaGenerado: rm['ia_generado'] as bool? ?? false,
            puntos: puntos,
          ));
        }
      }
      if (mounted) setState(() => _allRutas = rutas);
    } catch (_) {}
  }

  List<_PoiData> get _fallbackPois => [
    _PoiData(id: 1, nombre: 'Plaza Murillo', descripcion: 'Centro político de Bolivia.', idCategoria: 403, latitud: -16.4955, longitud: -68.1336),
    _PoiData(id: 2, nombre: 'Calle Jaén', descripcion: 'Calle colonial del siglo XVIII.', idCategoria: 401, latitud: -16.4910, longitud: -68.1368),
    _PoiData(id: 3, nombre: 'Mirador Killi Killi', descripcion: 'Vista panorámica 360°.', idCategoria: 402, latitud: -16.4870, longitud: -68.1290),
    _PoiData(id: 4, nombre: 'Museo de Etnografía', descripcion: 'Textiles y culturas indígenas.', idCategoria: 401, latitud: -16.4940, longitud: -68.1355),
  ];

  // ===========================================================================
  //  BÚSQUEDA
  // ===========================================================================

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) { setState(() { _searchResults = []; _showSearchResults = false; }); return; }
    final r = _allPois.where((p) =>
      p.nombre.toLowerCase().contains(q) ||
      p.categoriaLabel.toLowerCase().contains(q) ||
      p.descripcion.toLowerCase().contains(q)
    ).toList();
    setState(() { _searchResults = r; _showSearchResults = r.isNotEmpty; });
  }

  void _selectSearchResult(_PoiData poi) {
    _searchFocus.unfocus();
    _searchCtrl.text = poi.nombre;
    setState(() { _searchResults = []; _showSearchResults = false; });
    _handlePoiTap(poi);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() { _searchResults = []; _showSearchResults = false; });
  }

  // ===========================================================================
  //  UBICACIÓN GPS
  // ===========================================================================

  Future<void> _requestLocation() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return;
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    if (perm == geo.LocationPermission.deniedForever) return;

    try {
      final pos = await geo.Geolocator.getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);
      setState(() => _userPosition = pos);
      if (widget.initialPoi == null && widget.initialRuta == null && _mapReady) _centerUser();
    } catch (_) {}

    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // actualizar cada 5 metros
      ),
    ).listen((pos) {
      final anterior = _userPosition;
      _userPosition = pos;

      // Calcular bearing real entre posición anterior y nueva
      if (anterior != null) {
        _userBearing = geo.Geolocator.bearingBetween(
          anterior.latitude, anterior.longitude,
          pos.latitude, pos.longitude,
        );
      }

      _updateLocationPuck();

      if (_navActiva && !_camaraLibre) {
        _seguirUsuarioEnNavegacion();
      }
      if (_navActiva && _navSteps.isNotEmpty) {
        _verificarAvancePaso(pos);
      }
    });
  }

  void _updateLocationPuck() {
    _mapboxMap?.location.updateSettings(mbx.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: !_navActiva,
      pulsingColor: brandTeal.value,
      accuracyRingColor: brandTeal.withValues(alpha: 0.10).value,
      accuracyRingBorderColor: brandTeal.withValues(alpha: 0.20).value,
    ));
  }

  // ── Mueve la cámara siguiendo al usuario durante navegación (tipo Google Maps) ──
  void _seguirUsuarioEnNavegacion() {
    if (_mapboxMap == null || _userPosition == null) return;
    _mapboxMap!.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(
          _userPosition!.longitude,
          _userPosition!.latitude,
        )),
        zoom: 17.5,
        pitch: 60,               // perspectiva inclinada tipo conducción
        bearing: _userBearing,   // rota el mapa según la dirección de marcha
      ),
      mbx.MapAnimationOptions(duration: 800),
    );
  }

  // ── Verifica si el usuario está cerca del waypoint del paso actual ──
  void _verificarAvancePaso(geo.Position pos) {
    if (_currentStepIndex >= _navSteps.length - 1) return;

    final step = _navSteps[_currentStepIndex];
    if (step.waypointLat == null || step.waypointLng == null) return;

    final dist = geo.Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      step.waypointLat!, step.waypointLng!,
    );

    // Avanzar al siguiente paso cuando estamos a menos de 20 metros del waypoint
    if (dist < 20) {
      final nextIndex = _currentStepIndex + 1;
      if (nextIndex < _navSteps.length) {
        setState(() {
          _currentStepIndex     = nextIndex;
          _navInstruccionActual = _navSteps[nextIndex].instruccion;
          _navIconoActual       = _navSteps[nextIndex].icon;

          // Preparar la próxima instrucción (la siguiente al actual)
          if (nextIndex + 1 < _navSteps.length) {
            _navProximaInstruccion = _navSteps[nextIndex + 1].instruccion;
            _navIconoProximo       = _navSteps[nextIndex + 1].icon;
            _navDistanciaAlPaso    = _formatDist(_navSteps[nextIndex + 1].distanciaMetros);
          } else {
            _navProximaInstruccion = '';
            _navDistanciaAlPaso    = '';
          }
        });
      }
    }
  }

  String _formatDist(double metros) {
    if (metros < 1000) return '${metros.toStringAsFixed(0)} m';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  // ===========================================================================
  //  MAPBOX DIRECTIONS API — NAVEGACIÓN REAL
  // ===========================================================================

  Future<void> _iniciarNavegacionPoi(_PoiData poi) async {
    if (_userPosition == null) { _snack('Esperando GPS...'); return; }
    if (poi.latitud == null)   { _snack('Sin coordenadas'); return; }
    await _calcularRutaMapbox([
      '${_userPosition!.longitude},${_userPosition!.latitude}',
      '${poi.longitud},${poi.latitud}',
    ], poi.nombre);
  }

  Future<void> _iniciarNavegacionRuta(_RutaData ruta) async {
    if (_userPosition == null) { _snack('Esperando GPS...'); return; }
    final wps = <String>[
      '${_userPosition!.longitude},${_userPosition!.latitude}',
      ...ruta.puntos
          .where((p) => p.latitud != null)
          .map((p) => '${p.longitud},${p.latitud}'),
    ];
    if (wps.length < 2) { _snack('La ruta no tiene coordenadas'); return; }
    // Mapbox walking acepta máx 25 waypoints
    await _calcularRutaMapbox(wps.length > 25 ? wps.sublist(0, 25) : wps, ruta.nombre);
  }

  Future<void> _calcularRutaMapbox(List<String> waypoints, String destino) async {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/walking/${waypoints.join(';')}'
      '?alternatives=false'
      '&geometries=geojson'
      '&language=es'
      '&overview=full'
      '&steps=true'
      '&access_token=$token',
    );

    try {
      _snack('Calculando ruta...');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) { _snack('Error al calcular la ruta'); return; }

      final data   = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) { _snack('No hay ruta disponible'); return; }

      final route    = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords   = (geometry['coordinates'] as List)
          .map((c) => mbx.Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();

      final distMetros = (route['distance'] as num).toDouble();
      final durSeg     = (route['duration'] as num).toDouble();
      final distStr    = _formatDist(distMetros);
      final minutos    = (durSeg / 60).ceil();
      final tiempoStr  = minutos < 60 ? '$minutos min' : '${(minutos / 60).toStringAsFixed(1)} h';

      // Extraer pasos con coordenadas del waypoint de cada maniobra
      final steps = <_StepInstruction>[];
      for (final leg in route['legs'] as List) {
        for (final step in (leg as Map<String, dynamic>)['steps'] as List) {
          final sm        = step as Map<String, dynamic>;
          final maneuver  = sm['maneuver'] as Map<String, dynamic>;
          final loc       = maneuver['location'] as List?;
          steps.add(_StepInstruction(
            instruccion:     maneuver['instruction'] as String? ?? '',
            distanciaMetros: (sm['distance'] as num).toDouble(),
            maneuver:        '${maneuver['type'] ?? ''}-${maneuver['modifier'] ?? ''}',
            waypointLng:     loc != null ? (loc[0] as num).toDouble() : null,
            waypointLat:     loc != null ? (loc[1] as num).toDouble() : null,
          ));
        }
      }

      // Dibujar polilínea real de la ruta (reemplaza la previa)
      await _dibujarRutaEnMapa(coords);

      // Activar modo navegación ANTES de mover la cámara
      if (mounted) {
        setState(() {
          _navActiva             = true;
          _showNavBanner         = true;
          _navDistancia          = distStr;
          _navTiempo             = tiempoStr;
          _navSteps              = steps;
          _currentStepIndex      = 0;
          _modoNavegacion        = true;
          _camaraLibre           = false;
          if (steps.isNotEmpty) {
            _navInstruccionActual  = steps[0].instruccion;
            _navIconoActual        = steps[0].icon;
          }
          if (steps.length > 1) {
            _navProximaInstruccion = steps[1].instruccion;
            _navIconoProximo       = steps[1].icon;
            _navDistanciaAlPaso    = _formatDist(steps[1].distanciaMetros);
          }
        });
        _bannerCtrl.forward(from: 0);
        _navPanelCtrl.forward(from: 0);

        // Cámara inicial tipo Google Maps: centrada en usuario, orientada, pitch 60°
        if (_userPosition != null) {
          await _mapboxMap?.flyTo(
            mbx.CameraOptions(
              center: mbx.Point(coordinates: mbx.Position(
                _userPosition!.longitude, _userPosition!.latitude)),
              zoom: 17.5,
              pitch: 60,
              bearing: _userBearing,
            ),
            mbx.MapAnimationOptions(duration: 1200),
          );
        }
      }
    } catch (e) {
      _snack('Error de red al calcular la ruta');
    }
  }

  // ── Dibuja polilínea sobre el mapa ──
  Future<void> _dibujarRutaEnMapa(List<mbx.Position> coords) async {
    if (_mapboxMap == null) return;
    try {
      if (_polylineManager != null) {
        await _mapboxMap!.annotations.removeAnnotationManager(_polylineManager!);
      }
    } catch (_) {}

    try {
      _polylineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
      // Sombra
      await _polylineManager!.create(mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(coordinates: coords),
        lineWidth: 9.0,
        lineColor: const Color(0x500F988A).value,
      ));
      // Línea principal
      await _polylineManager!.create(mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(coordinates: coords),
        lineWidth: 5.5,
        lineColor: brandTeal.value,
      ));
    } catch (_) {}
  }

  // ── Dibuja marcadores numerados para la ruta inicial (sin navegación) ──
  Future<void> _dibujarMarcadoresRuta(_RutaData ruta) async {
    if (_mapboxMap == null) return;
    try {
      if (_routeMarkerManager != null) {
        await _mapboxMap!.annotations.removeAnnotationManager(_routeMarkerManager!);
      }
    } catch (_) {}

    try {
      _routeMarkerManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      for (int i = 0; i < ruta.puntos.length; i++) {
        final p = ruta.puntos[i];
        if (p.latitud == null) continue;
        final bytes = await _numberedMarkerImage(i + 1, i == 0);
        await _routeMarkerManager!.create(mbx.PointAnnotationOptions(
          geometry: mbx.Point(coordinates: mbx.Position(p.longitud!, p.latitud!)),
          image: bytes,
          iconSize: 1.0,
          iconAnchor: mbx.IconAnchor.BOTTOM,
        ));
      }

      // Línea entre los puntos de la ruta (línea recta, no Directions)
      if (ruta.puntos.length >= 2) {
        final lineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
        final lineCoords = ruta.puntos
            .where((p) => p.latitud != null)
            .map((p) => mbx.Position(p.longitud!, p.latitud!))
            .toList();
        // Línea punteada/semitransparente para la vista previa
        await lineManager.create(mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(coordinates: lineCoords),
          lineWidth: 3.0,
          lineColor: brandTeal.withValues(alpha: 0.5).value,
        ));
      }
    } catch (_) {}
  }

  /// Genera imagen de marcador numerado para los puntos de la ruta
  Future<Uint8List> _numberedMarkerImage(int number, bool isFirst) async {
    const w = 60.0, h = 70.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    final color = isFirst ? brandEmerald : brandTeal;

    // Sombra
    canvas.drawCircle(const Offset(30, 28), 22, Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 5));

    // Círculo principal
    canvas.drawCircle(const Offset(30, 26), 20, Paint()..color = color);
    canvas.drawCircle(const Offset(30, 26), 20, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    // Punta inferior
    final tip = Path()..moveTo(22, 42)..lineTo(30, 60)..lineTo(38, 42)..close();
    canvas.drawPath(tip, Paint()..color = color);

    // Número
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(30 - tp.width / 2, 26 - tp.height / 2));

    final pic = recorder.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bd  = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  // ── Ajusta cámara para ver toda la ruta ──
  Future<void> _ajustarCamaraRuta(List<mbx.Position> coords) async {
    if (_mapboxMap == null || coords.isEmpty) return;

    double minLng = (coords.first.lng as num).toDouble();
    double maxLng = (coords.first.lng as num).toDouble();
    double minLat = (coords.first.lat as num).toDouble();
    double maxLat = (coords.first.lat as num).toDouble();

    for (final pos in coords) {
      final lng = (pos.lng as num).toDouble();
      final lat = (pos.lat as num).toDouble();
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    final maxDiff = math.max(maxLat - minLat, maxLng - minLng);
    double zoom = maxDiff > 0.05 ? 12.5 : maxDiff > 0.02 ? 13.5 : maxDiff < 0.005 ? 15.5 : 14.5;

    await _mapboxMap!.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(
          (minLng + maxLng) / 2, (minLat + maxLat) / 2 - 0.001)),
        zoom: zoom, pitch: 35, bearing: 0,
      ),
      mbx.MapAnimationOptions(duration: 1200),
    );
  }

  void _detenerNavegacion() {
    _navPanelCtrl.reverse();
    _bannerCtrl.reverse().then((_) {
      if (mounted) setState(() {
        _navActiva = false; _showNavBanner = false;
        _modoNavegacion = false; _navSteps = [];
        _currentStepIndex = 0; _navInstruccionActual = '';
        _navProximaInstruccion = ''; _navDistanciaAlPaso = '';
        _camaraLibre = false;
      });
    });
    try {
      if (_polylineManager != null) {
        _mapboxMap?.annotations.removeAnnotationManager(_polylineManager!);
        _polylineManager = null;
      }
    } catch (_) {}

    // Volver a vista normal
    if (_userPosition != null) {
      _mapboxMap?.flyTo(
        mbx.CameraOptions(
          center: mbx.Point(coordinates: mbx.Position(
            _userPosition!.longitude, _userPosition!.latitude)),
          zoom: 15.0, pitch: 0, bearing: 0,
        ),
        mbx.MapAnimationOptions(duration: 800),
      );
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: brandTeal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ===========================================================================
  //  MAPBOX — INICIALIZACIÓN
  // ===========================================================================

  void _onMapCreated(mbx.MapboxMap map) {
    _mapboxMap = map;

    map.location.updateSettings(mbx.LocationComponentSettings(
      enabled: true, pulsingEnabled: true,
      pulsingColor: brandTeal.value,
      accuracyRingColor: brandTeal.withValues(alpha: 0.10).value,
      accuracyRingBorderColor: brandTeal.withValues(alpha: 0.20).value,
    ));
    map.gestures.updateSettings(mbx.GesturesSettings(
      rotateEnabled: true, pinchToZoomEnabled: true,
      scrollEnabled: true, doubleTapToZoomInEnabled: true, pitchEnabled: true,
    ));
    map.compass.updateSettings(mbx.CompassSettings(
      enabled: true, position: mbx.OrnamentPosition.TOP_RIGHT, marginTop: 80));
    map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false));
    map.logo.updateSettings(mbx.LogoSettings(
      position: mbx.OrnamentPosition.BOTTOM_LEFT, marginBottom: 16));
    map.attribution.updateSettings(mbx.AttributionSettings(
      position: mbx.OrnamentPosition.BOTTOM_LEFT, marginBottom: 16, marginLeft: 92));

    _mapReady = true;

    // Marcadores de POIs generales
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _poisLoaded) _addPoiMarkers();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _fabCtrl.forward();
    });

    // ── Si hay ruta inicial: dibujar marcadores numerados + línea + ajustar cámara ──
    if (widget.initialRuta != null) {
      Future.delayed(const Duration(milliseconds: 1200), () async {
        if (!mounted) return;
        final ruta = widget.initialRuta!;
        await _dibujarMarcadoresRuta(ruta);
        final coords = ruta.puntos
            .where((p) => p.latitud != null)
            .map((p) => mbx.Position(p.longitud!, p.latitud!))
            .toList();
        if (coords.isNotEmpty) await _ajustarCamaraRuta(coords);
      });
    } else if (widget.initialPoi != null && widget.initialPoi!.latitud != null) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _flyToCoords(
          widget.initialPoi!.longitud!, widget.initialPoi!.latitud! - 0.0008, zoom: 15.5);
      });
    }
  }

  // ===========================================================================
  //  MARCADORES POI GENERALES
  // ===========================================================================

  Future<void> _addPoiMarkers() async {
    if (_mapboxMap == null || _allPois.isEmpty) return;
    try {
      _annotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      final opts = <mbx.PointAnnotationOptions>[];
      for (final poi in _allPois) {
        if (poi.latitud == null) continue;
        final bytes = await _poiMarkerImage(poi);
        opts.add(mbx.PointAnnotationOptions(
          geometry: mbx.Point(coordinates: mbx.Position(poi.longitud!, poi.latitud!)),
          image: bytes, iconSize: 1.0, iconAnchor: mbx.IconAnchor.BOTTOM,
        ));
      }
      if (opts.isNotEmpty) {
        await _annotationManager!.createMulti(opts);
        _annotationManager!.addOnPointAnnotationClickListener(
          _MarkerTapListener(pois: _allPois, onTap: _handlePoiTap),
        );
      }
    } catch (_) {}
  }

  Future<Uint8List> _poiMarkerImage(_PoiData poi) async {
    const w = 64.0, h = 76.0;
    final rec = ui.PictureRecorder();
    final can = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    can.drawCircle(const Offset(32, 32), 24, Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 6));
    can.drawCircle(const Offset(32, 28), 22, Paint()..color = brandTeal);
    can.drawCircle(const Offset(32, 28), 22, Paint()
      ..color = Colors.white ..style = PaintingStyle.stroke ..strokeWidth = 3);
    final tip = Path()..moveTo(23, 46)..lineTo(32, 64)..lineTo(41, 46)..close();
    can.drawPath(tip, Paint()..color = brandTeal);
    final tp = TextPainter(
      text: TextSpan(text: poi.icono, style: const TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(can, Offset(32 - tp.width / 2, 28 - tp.height / 2));
    final pic = rec.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bd  = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  // ===========================================================================
  //  INTERACCIÓN
  // ===========================================================================

  void _handlePoiTap(_PoiData poi) {
    setState(() { _selectedPoi = poi; _selectedRuta = null; });
    _sheetCtrl.forward(from: 0);
    if (poi.latitud != null) _flyToCoords(poi.longitud!, poi.latitud! - 0.0008, zoom: 15.5, pitch: 35);
  }

  void _handleRutaTap(_RutaData ruta) {
    setState(() { _selectedRuta = ruta; _selectedPoi = null; });
    _sheetCtrl.forward(from: 0);
    if (ruta.puntos.isNotEmpty) {
      final coords = ruta.puntos
          .where((p) => p.latitud != null)
          .map((p) => mbx.Position(p.longitud!, p.latitud!))
          .toList();
      _ajustarCamaraRuta(coords);
    }
  }

  void _closePoi() {
    _sheetCtrl.reverse().then((_) {
      if (mounted) setState(() { _selectedPoi = null; _selectedRuta = null; });
    });
  }

  void _flyToCoords(double lng, double lat, {double zoom = 15.5, double pitch = 35}) {
    _mapboxMap?.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(lng, lat)),
        zoom: zoom, pitch: pitch, bearing: 0,
      ),
      mbx.MapAnimationOptions(duration: 900),
    );
  }

  void _centerUser() {
    if (_userPosition == null || _mapboxMap == null) return;
    // Si está navegando, volver a seguir al usuario
    if (_navActiva) {
      setState(() => _camaraLibre = false);
      _seguirUsuarioEnNavegacion();
    } else {
      _mapboxMap!.flyTo(
        mbx.CameraOptions(
          center: mbx.Point(coordinates: mbx.Position(
            _userPosition!.longitude, _userPosition!.latitude)),
          zoom: 15.5, pitch: 0, bearing: 0,
        ),
        mbx.MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _findNearby() {
    if (_userPosition == null || _allPois.isEmpty) return;
    _PoiData? closest;
    double minDist = double.infinity;
    for (final poi in _allPois) {
      if (poi.latitud == null) continue;
      final d = geo.Geolocator.distanceBetween(
        _userPosition!.latitude, _userPosition!.longitude, poi.latitud!, poi.longitud!);
      if (d < minDist) { minDist = d; closest = poi; }
    }
    if (closest != null) _handlePoiTap(closest);
  }

  // ===========================================================================
  //  BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final top      = MediaQuery.of(context).padding.top;
    final hasSheet = _selectedPoi != null || _selectedRuta != null;

    return Scaffold(
      body: Stack(
        children: [
          // ── MAPA ──
          RepaintBoundary(child: _buildMap()),
          _gradientTop(),

          // ── BARRA DE BÚSQUEDA ──
          if (!_modoNavegacion)
            Positioned(
              top: top + 10, left: 16, right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchBar(),
                  if (_showSearchResults) _buildSearchDropdown(),
                ],
              ),
            ),

          // ── PANEL SUPERIOR NAVEGACIÓN (tipo Google Maps) ──
          if (_modoNavegacion)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                    .animate(_navPanelAnim),
                child: _buildNavTopPanel(top),
              ),
            ),

          // ── BARRA INFERIOR NAVEGACIÓN (distancia + tiempo) ──
          if (_modoNavegacion)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildNavBottomBar(),
            ),

          // ── BANNER COMPACTO (cuando no está en modo nav total) ──
          if (_showNavBanner && !_modoNavegacion)
            Positioned(
              top: top + 74, left: 16, right: 16,
              child: FadeTransition(
                opacity: _bannerAnim,
                child: _buildNavBannerCompacto(),
              ),
            ),

          // ── CARGANDO ──
          if (!_poisLoaded && !_modoNavegacion)
            Positioned(
              top: top + 74, left: 16, right: 16,
              child: _buildLoadingBanner(),
            ),

          // ── FABs ──
          if (!_modoNavegacion)
            Positioned(
              right: 14,
              bottom: hasSheet ? 310 : 100,
              child: ScaleTransition(scale: _fabAnim, child: _buildFabs()),
            ),

          // ── BOTÓN RE-CENTRAR durante navegación (cuando cámara libre) ──
          if (_modoNavegacion && _camaraLibre)
            Positioned(
              bottom: 90, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _camaraLibre = false);
                    _seguirUsuarioEnNavegacion();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: glassWhite,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.navigation_rounded, color: brandTeal, size: 18),
                      SizedBox(width: 6),
                      Text('Centrar', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: brandTeal)),
                    ]),
                  ),
                ),
              ),
            ),

          // ── FICHA POI / RUTA ──
          if (hasSheet && !_modoNavegacion)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(_sheetAnim),
                child: _selectedPoi != null
                    ? _buildPoiSheet(_selectedPoi!)
                    : _buildRutaSheet(_selectedRuta!),
              ),
            ),

          if (!hasSheet && !_modoNavegacion) _gradientBottom(),
        ],
      ),
    );
  }

  // ===========================================================================
  //  MAPA
  // ===========================================================================

  Widget _buildMap() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    mbx.MapboxOptions.setAccessToken(token);
    return SizedBox.expand(
      child: mbx.MapWidget(
        styleUri: mbx.MapboxStyles.STANDARD,
        cameraOptions: mbx.CameraOptions(
          center: mbx.Point(coordinates: mbx.Position(
            widget.initialPoi?.longitud ?? widget.initialRuta?.puntos.first?.longitud ?? -68.1336,
            widget.initialPoi?.latitud  ?? widget.initialRuta?.puntos.first?.latitud  ?? -16.4930,
          )),
          zoom: widget.initialPoi != null || widget.initialRuta != null ? 14.5 : 14.5,
          pitch: 20, bearing: 0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }

  // ===========================================================================
  //  UI HELPERS
  // ===========================================================================

  Widget _gradientTop() => Positioned(
    top: 0, left: 0, right: 0, height: 200,
    child: IgnorePointer(child: Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.black.withValues(alpha: 0.52), Colors.transparent],
      )),
    )),
  );

  Widget _gradientBottom() => Positioned(
    bottom: 0, left: 0, right: 0, height: 140,
    child: IgnorePointer(child: Container(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.bottomCenter, end: Alignment.topCenter,
        colors: [Colors.black.withValues(alpha: 0.38), Colors.transparent],
      )),
    )),
  );

  Widget _buildLoadingBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: glassWhite, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: brandTeal)),
      const SizedBox(width: 10),
      Text('Cargando lugares...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brandDark.withValues(alpha: 0.65))),
    ]),
  );

  // ===========================================================================
  //  PANEL DE NAVEGACIÓN SUPERIOR — estilo Google Maps
  // ===========================================================================

  Widget _buildNavTopPanel(double top) {
    return GestureDetector(
      // Si el usuario toca el panel, no marcamos cámara libre
      onTap: () {},
      child: Container(
        padding: EdgeInsets.fromLTRB(0, top, 0, 0),
        decoration: BoxDecoration(
          color: brandEmerald,
          boxShadow: [BoxShadow(color: brandEmerald.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Instrucción actual ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Ícono de la maniobra
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_navIconoActual, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _navInstruccionActual.isNotEmpty
                        ? _navInstruccionActual
                        : 'Sigue la ruta hacia el destino',
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  if (_navDistanciaAlPaso.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'En $_navDistanciaAlPaso',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.80), fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              )),
              GestureDetector(
                onTap: _detenerNavegacion,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),

          // ── Próxima instrucción ──
          if (_navProximaInstruccion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(_navIconoProximo, color: Colors.white.withValues(alpha: 0.80), size: 18),
                  const SizedBox(width: 10),
                  Text('Luego: ', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65))),
                  Expanded(child: Text(
                    _navProximaInstruccion,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ),
            ),

          const SizedBox(height: 14),
        ]),
      ),
    );
  }

  // ── Barra inferior de navegación (distancia + tiempo + detener) ──
  Widget _buildNavBottomBar() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        // Detener
        GestureDetector(
          onTap: _detenerNavegacion,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF5D7A).withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.close_rounded, color: Color(0xFFFF5D7A), size: 22),
          ),
        ),
        const SizedBox(width: 16),
        // Tiempo
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_navTiempo, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: brandEmerald)),
          Text('tiempo estimado', style: TextStyle(
            fontSize: 10, color: brandDark.withValues(alpha: 0.45))),
        ]),
        const SizedBox(width: 20),
        // Distancia
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_navDistancia, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800, color: brandDark)),
          Text('distancia total', style: TextStyle(
            fontSize: 10, color: brandDark.withValues(alpha: 0.45))),
        ]),
        const Spacer(),
        // Vista general de la ruta
        GestureDetector(
          onTap: () {
            setState(() => _camaraLibre = true);
            if (_navSteps.isNotEmpty && _navSteps.first.waypointLat != null) {
              // Ver toda la ruta
              _mapboxMap?.flyTo(
                mbx.CameraOptions(
                  center: mbx.Point(coordinates: mbx.Position(
                    _userPosition?.longitude ?? -68.1336,
                    _userPosition?.latitude  ?? -16.4930,
                  )),
                  zoom: 14.0, pitch: 0, bearing: 0,
                ),
                mbx.MapAnimationOptions(duration: 800),
              );
            }
          },
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: brandTeal.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: brandTeal.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.alt_route_rounded, color: brandTeal, size: 22),
          ),
        ),
      ]),
    );
  }

  // ── Banner compacto navegación (cuando la ficha está visible pero nav activa) ──
  Widget _buildNavBannerCompacto() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: brandEmerald, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: brandEmerald.withValues(alpha: 0.50), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
          child: Icon(_navIconoActual, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EN CAMINO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.65), letterSpacing: 1.1)),
            const SizedBox(height: 1),
            Text(
              _navInstruccionActual.isNotEmpty ? _navInstruccionActual : 'Sigue la ruta',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            Text('$_navDistancia · $_navTiempo',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.70))),
          ],
        )),
        GestureDetector(
          onTap: () => setState(() => _modoNavegacion = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text('Ver ruta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: brandEmerald)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _detenerNavegacion,
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.7), size: 14),
          ),
        ),
      ]),
    );
  }

  // ===========================================================================
  //  FABs
  // ===========================================================================

  Widget _buildFabs() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _fab(icon: Icons.my_location_rounded, primary: true, tooltip: 'Mi ubicación', onTap: _centerUser),
      const SizedBox(height: 10),
      _fab(icon: Icons.near_me_rounded, tooltip: 'Más cercano', onTap: _findNearby),
    ]);
  }

  Widget _fab({required IconData icon, required String tooltip,
      required VoidCallback onTap, bool primary = false}) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(message: tooltip, child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(23),
        child: Ink(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: primary ? brandTeal : glassWhite,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: (primary ? brandTeal : Colors.black).withValues(alpha: primary ? 0.38 : 0.14),
              blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Icon(icon,
            color: primary ? Colors.white : brandDark.withValues(alpha: 0.72), size: 22),
        ),
      )),
    );
  }

  // ===========================================================================
  //  SEARCH BAR
  // ===========================================================================

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: glassWhite, borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: brandDark.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_rounded, color: brandDark, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: _searchCtrl, focusNode: _searchFocus,
          style: const TextStyle(fontSize: 14, color: brandDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: _selectedPoi?.nombre ?? 'Buscar en La Paz...',
            hintStyle: TextStyle(color: brandDark.withValues(alpha: 0.38), fontSize: 14),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            if (_searchCtrl.text.trim().isNotEmpty && _searchResults.isNotEmpty) {
              setState(() => _showSearchResults = true);
            }
          },
        )),
        if (_searchCtrl.text.isNotEmpty)
          GestureDetector(
            onTap: _clearSearch,
            child: Padding(padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.close_rounded, color: brandDark.withValues(alpha: 0.40), size: 18)),
          )
        else
          Container(
            width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [brandEmerald, brandTeal],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
      ]),
    );
  }

  Widget _buildSearchDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: glassWhite, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
            children: _searchResults.asMap().entries.map((e) {
              final isLast = e.key == _searchResults.length - 1;
              final poi = e.value;
              return GestureDetector(
                onTap: () => _selectSearchResult(poi),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(border: isLast ? null : Border(
                    bottom: BorderSide(color: brandDark.withValues(alpha: 0.06)))),
                  child: Row(children: [
                    Container(width: 38, height: 38,
                      decoration: BoxDecoration(color: brandTeal.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(poi.icono, style: const TextStyle(fontSize: 18)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(poi.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: brandDark)),
                      Text(poi.categoriaLabel, style: TextStyle(fontSize: 11, color: brandDark.withValues(alpha: 0.45))),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Text(poi.precioLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: brandTeal)),
                      Text('entrada', style: TextStyle(fontSize: 10, color: brandDark.withValues(alpha: 0.38))),
                    ]),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  //  FICHA POI
  // ===========================================================================

  Widget _buildPoiSheet(_PoiData poi) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 32, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 18),
          decoration: BoxDecoration(color: brandDark.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildPoiThumbnail(poi),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: brandAmber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(poi.categoriaLabel.toUpperCase(),
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: brandAmber, letterSpacing: 0.8)),
                ),
                const Spacer(),
                GestureDetector(onTap: _closePoi,
                  child: Icon(Icons.close_rounded, color: brandDark.withValues(alpha: 0.30), size: 20)),
              ]),
              const SizedBox(height: 5),
              Text(poi.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: brandDark, height: 1.15)),
              if (poi.tieneAudioguia) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [brandEmerald, brandTeal]), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.headphones_rounded, size: 10, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Audioguía disponible', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ],
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _stat(Icons.sell_rounded, poi.precioLabel),
            _divider(),
            _stat(Icons.star_rounded, '4.7', starColor: true),
            _divider(),
            _stat(Icons.location_on_rounded, 'La Paz'),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(poi.descripcion,
            style: TextStyle(fontSize: 13, color: brandDark.withValues(alpha: 0.55), height: 1.4),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
          child: Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(color: brandDark.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.favorite_border_rounded, color: brandDark.withValues(alpha: 0.50), size: 22)),
            const SizedBox(width: 8),
            Container(width: 52, height: 52,
              decoration: BoxDecoration(color: brandTeal.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brandTeal.withValues(alpha: 0.25))),
              child: Icon(Icons.share_rounded, color: brandTeal, size: 22)),
            const SizedBox(width: 8),
            // ── CÓMO LLEGAR → navegación Mapbox ──
            Expanded(
              child: GestureDetector(
                onTap: () { _closePoi(); _iniciarNavegacionPoi(poi); },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [brandEmerald, brandTeal],
                      begin: Alignment.centerLeft, end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.42), blurRadius: 18, offset: const Offset(0, 5))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Cómo llegar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ===========================================================================
  //  FICHA RUTA (múltiples puntos)
  // ===========================================================================

  Widget _buildRutaSheet(_RutaData ruta) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 32, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 18),
          decoration: BoxDecoration(color: brandDark.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [brandEmerald, brandTeal]),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.route_rounded, color: Colors.white, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (ruta.iaGenerado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: brandAmber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('✨ GENERADA POR IA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: brandAmber, letterSpacing: 0.8)),
                ),
              const SizedBox(height: 4),
              Text(ruta.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: brandDark, height: 1.15)),
              Text('${ruta.puntos.length} paradas', style: TextStyle(fontSize: 12, color: brandDark.withValues(alpha: 0.45))),
            ])),
            GestureDetector(onTap: _closePoi,
              child: Icon(Icons.close_rounded, color: brandDark.withValues(alpha: 0.30), size: 20)),
          ]),
        ),
        const SizedBox(height: 12),
        if (ruta.descripcion.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(ruta.descripcion,
              style: TextStyle(fontSize: 13, color: brandDark.withValues(alpha: 0.55), height: 1.4),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        const SizedBox(height: 14),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: ruta.puntos.length,
            itemBuilder: (ctx, i) => _buildRutaStep(ruta.puntos[i], i, i == ruta.puntos.length - 1),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
          child: Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(color: brandDark.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.favorite_border_rounded, color: brandDark.withValues(alpha: 0.50), size: 22)),
            const SizedBox(width: 8),
            // ── INICIAR RECORRIDO → navegación multi-punto Mapbox ──
            Expanded(
              child: GestureDetector(
                onTap: () { _closePoi(); _iniciarNavegacionRuta(ruta); },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [brandEmerald, brandTeal],
                      begin: Alignment.centerLeft, end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.42), blurRadius: 18, offset: const Offset(0, 5))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Iniciar recorrido', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRutaStep(_PoiData poi, int index, bool isLast) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 32, child: Column(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: index == 0 ? brandEmerald : brandTeal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.35), blurRadius: 6)],
            ),
            child: Center(child: index == 0
              ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14)
              : Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))),
          ),
          if (!isLast)
            Expanded(child: Container(width: 2,
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: brandTeal.withValues(alpha: 0.25))),
        ])),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _handlePoiTap(poi),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandDark.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brandDark.withValues(alpha: 0.06)),
                ),
                child: Row(children: [
                  Text(poi.icono, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(poi.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brandDark)),
                    Text(poi.categoriaLabel, style: TextStyle(fontSize: 11, color: brandDark.withValues(alpha: 0.45))),
                  ])),
                  Text(poi.precioLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: brandTeal)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ===========================================================================
  //  SHARED HELPERS UI
  // ===========================================================================

  Widget _buildPoiThumbnail(_PoiData poi) {
    return Container(
      width: 76, height: 76,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: brandTeal.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(18),
        child: poi.imagenUrl != null && poi.imagenUrl!.isNotEmpty
            ? Image.network(poi.imagenUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _poiIconFallback(poi))
            : _poiIconFallback(poi)),
    );
  }

  Widget _poiIconFallback(_PoiData poi) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
      colors: [brandTeal.withValues(alpha: 0.85), brandEmerald],
      begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Text(poi.icono, style: const TextStyle(fontSize: 34))),
  );

  Widget _stat(IconData icon, String text, {bool starColor = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: starColor ? const Color(0xFFFFC107) : brandDark.withValues(alpha: 0.42)),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brandDark.withValues(alpha: 0.65))),
  ]);

  Widget _divider() => Container(width: 1, height: 14,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: brandDark.withValues(alpha: 0.12));
}

// =============================================================================
//  LISTENER DE TAPS EN MARCADORES
// =============================================================================

class _MarkerTapListener extends mbx.OnPointAnnotationClickListener {
  final List<_PoiData> pois;
  final void Function(_PoiData) onTap;

  _MarkerTapListener({required this.pois, required this.onTap});

  @override
  void onPointAnnotationClick(mbx.PointAnnotation annotation) {
    final lng = annotation.geometry.coordinates.lng;
    final lat = annotation.geometry.coordinates.lat;
    _PoiData? closest;
    double minDist = double.infinity;
    for (final poi in pois) {
      if (poi.latitud == null) continue;
      final d = math.sqrt(math.pow(poi.longitud! - lng, 2) + math.pow(poi.latitud! - lat, 2));
      if (d < minDist) { minDist = d; closest = poi; }
    }
    if (closest != null) onTap(closest);
  }
}