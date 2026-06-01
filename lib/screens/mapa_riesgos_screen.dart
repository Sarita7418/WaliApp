import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Le agregamos "as geo" para que no choque con la clase Position de Mapbox
import 'package:geolocator/geolocator.dart' as geo; 
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Map<int, String> nivelRiesgoSignificado = {
  801: 'Precaución (Robo Menor)',
  802: 'Peligro (Evitar de Noche)',
  803: 'Zona de Bloqueo/Marcha',
};

class MapaRiesgosScreen extends StatefulWidget {
  const MapaRiesgosScreen({super.key});

  @override
  State<MapaRiesgosScreen> createState() => _MapaRiesgosScreenState();
}

class _MapaRiesgosScreenState extends State<MapaRiesgosScreen> {
  static const double _defaultCenterLat = -16.504231;
  static const double _defaultCenterLng = -68.162453;

  // Variables dinámicas para rastrear la posición actual
  double _currentLat = _defaultCenterLat;
  double _currentLng = _defaultCenterLng;

  MapboxMap? _mapboxMap;
  bool _styleReady = false;
  bool _zoneCirclesAdded = false;

  List<ZonaRiesgo> _zonas = [];
  List<Map<String, dynamic>> _subdominios = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _determinePosition(); // Obtiene la ubicación actual del GPS
    _loadZonas();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Función para pedir permisos y obtener las coordenadas del GPS
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    // Verificar si los servicios de ubicación están activos
    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    
    if (permission == geo.LocationPermission.deniedForever) return; 

    // Obtenemos la posición usando el alias "geo"
    geo.Position position = await geo.Geolocator.getCurrentPosition();
    
    if (!mounted) return;

    setState(() {
      _currentLat = position.latitude;
      _currentLng = position.longitude;
    });

    // Si el mapa ya se cargó, movemos la cámara a la ubicación real
    if (_mapboxMap != null) {
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_currentLng, _currentLat)), // Aquí usa el Position de Mapbox
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  Future<void> _loadZonas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sb = Supabase.instance.client;
      final zonasRes = await sb.from('zonas_riesgo')
          .select('id, nombre, descripcion, id_nivel_riesgo, radio_metros, latitud, longitud')
          .eq('estado', true)
          .order('id_nivel_riesgo', ascending: false)
          .limit(50);

      final subdominiosRes = await sb.from('subdominios')
          .select()
          .order('id');

      if (!mounted) return;
      final subdominiosList = List<Map<String, dynamic>>.from(subdominiosRes as List);
      debugPrint('MapaRiesgosScreen: subdominios count = ${subdominiosList.length}');
      setState(() {
        _zonas = (zonasRes as List).map((e) => ZonaRiesgo.fromMap(e)).toList();
        _subdominios = subdominiosList;
        _isLoading = false;
      });

      if (_styleReady) {
        await _addShadedZoneAreas();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de riesgos'),
        backgroundColor: const Color(0xFF0F988A),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              SizedBox(height: 320, child: _buildMapWidget()),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    MapboxOptions.setAccessToken(token);

    return MapWidget(
      key: const ValueKey('mapWidget'),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      cameraOptions: CameraOptions(
        // Centra inicialmente en la ubicación actual (o por defecto si el GPS tarda)
        center: Point(coordinates: Position(_currentLng, _currentLat)),
        zoom: 13.0,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
  }

Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    if (_mapboxMap == null) return;
    _styleReady = true;

    // MODIFICACIÓN: Activar el indicador visual de la posición actual del usuario (Puck)
    await _mapboxMap!.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );  
}

  Future<void> _addShadedZoneAreas() async {
    if (_mapboxMap == null) return;
    if (_zoneCirclesAdded) return;
    final polygonZones = _zonas
        .where((z) => z.latitud != null && z.longitud != null && z.radioMetros != null)
        .toList();
    if (polygonZones.isEmpty) return;

    final features = polygonZones.map((zone) {
      return {
        'type': 'Feature',
        'properties': {
          'id': zone.id,
          'nombre': zone.nombre,
          'descripcion': zone.descripcion,
          'nivelRiesgo': zone.idNivelRiesgo,
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': _generateCircleCoordinates(
            zone.latitud!,
            zone.longitud!,
            zone.radioMetros!,
          ),
        },
      };
    }).toList();

    final geojsonSource = {
      'type': 'FeatureCollection',
      'features': features,
    };

    await _mapboxMap!.style.addSource(
      GeoJsonSource(
        id: 'fuente-zonas-riesgo',
        data: jsonEncode(geojsonSource),
      ),
    );

    final fillLayer = FillLayer(
      id: 'capa-zonas-riesgo',
      sourceId: 'fuente-zonas-riesgo',
      fillColor: Colors.red.value,
      fillOpacity: 0.22,
      fillOutlineColor: Colors.redAccent.value,
    );

await _mapboxMap!.style.addLayer(fillLayer);

    // MODIFICACIÓN: Nueva capa de tipo símbolo para renderizar los nombres en el centro de los círculos
    final textLayer = SymbolLayer(
      id: 'capa-texto-zonas-riesgo',
      sourceId: 'fuente-zonas-riesgo',
      textField: '{nombre}', // Extrae dinámicamente la propiedad 'nombre' de cada Feature
      textSize: 13.0,
      textColor: Colors.black.value,
      textHaloColor: Colors.white.value, // Borde blanco para mejorar legibilidad
      textHaloWidth: 2.0,
      textAnchor: TextAnchor.CENTER,
    );

    await _mapboxMap!.style.addLayer(textLayer);
    _zoneCirclesAdded = true;
  }

  List<List<List<double>>> _generateCircleCoordinates(
      double latCenter, double lngCenter, double radiusMeters) {
    const pointCount = 64;
    final latRad = latCenter * math.pi / 180;
    final radiusLat = radiusMeters / 111320.0;
    final radiusLng = radiusMeters / (111320.0 * math.cos(latRad));

    final ring = List<List<double>>.generate(pointCount + 1, (index) {
      final angle = 2 * math.pi * index / pointCount;
      final lat = latCenter + radiusLat * math.sin(angle);
      final lng = lngCenter + radiusLng * math.cos(angle);
      return [lng, lat];
    });

    return [ring];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Error cargando zonas: $_error',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.red),
        ),
      );
    }

    if (_zonas.isEmpty) {
      return const Center(
        child: Text(
          'No se encontró contenido en la tabla de zonas de precaución.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lista de zonas de precaución',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _zonas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final zona = _zonas[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zona.nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        zona.descripcion,
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFE53935)),
                          const SizedBox(width: 6),
                          Text(
                            'Significado: ${zona.nivelRiesgoDescripcion}',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 6),
                      // Row(
                      //   children: [
                      //     const Icon(Icons.my_location, size: 16, color: Color(0xFF0F988A)),
                      //     const SizedBox(width: 6),
                      //     Text(
                      //       'Radio: ${zona.radioMetros?.toStringAsFixed(0) ?? 'N/A'} m',
                      //       style: const TextStyle(fontSize: 13, color: Colors.black54),
                      //     ),
                      //   ],
                      // ),
                      // const SizedBox(height: 6),
                      // ORDENANDO LAS LLAVES Y CORCHETES

                      
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // const SizedBox(height: 16),
        // const Text(
        //   'Subdominios (id_dominio = 8)',
        //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        // ),
        // const SizedBox(height: 10),
        // if (_subdominios.isEmpty)
        //   const Padding(
        //     padding: EdgeInsets.symmetric(vertical: 20),
        //     child: Text(
        //       'No se encontraron subdominios para id_dominio = 8.',
        //       style: TextStyle(fontSize: 15, color: Colors.black54),
        //     ),
        //   )
        // else
          // Expanded(
          //   child: ListView.separated(
          //     itemCount: _subdominios.length,
          //     separatorBuilder: (_, __) => const SizedBox(height: 10),
          //     itemBuilder: (context, index) {
          //       final subdominio = _subdominios[index];
          //       return Card(
          //         elevation: 2,
          //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          //         child: Padding(
          //           padding: const EdgeInsets.all(14),
          //           child: Column(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             children: subdominio.entries.map((entry) {
          //               return Padding(
          //                 padding: const EdgeInsets.only(bottom: 6),
          //                 child: Text(
          //                   '${entry.key}: ${entry.value ?? ''}',
          //                   style: const TextStyle(fontSize: 14, color: Colors.black87),
          //                 ),
          //               );
          //             }).toList(),
          //           ),
          //         ),
          //       );
          //     },
          //   ),
          // ),
      ],
    );
  }
}

class ZonaRiesgo {
  final int id;
  final String nombre;
  final String descripcion;
  final int idNivelRiesgo;
  final double? radioMetros;
  final double? latitud;
  final double? longitud;

  const ZonaRiesgo({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.idNivelRiesgo,
    this.radioMetros,
    this.latitud,
    this.longitud,
  });

  factory ZonaRiesgo.fromMap(Map<String, dynamic> map) {
    return ZonaRiesgo(
      id: map['id'] as int,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      idNivelRiesgo: map['id_nivel_riesgo'] as int? ?? 0,
      radioMetros: (map['radio_metros'] as num?)?.toDouble(),
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
    );
  }

  String get nivelRiesgoDescripcion =>
      nivelRiesgoSignificado[idNivelRiesgo] ?? 'Descripción no disponible';
}