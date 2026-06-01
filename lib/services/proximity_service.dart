import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class ProximityService {
  static final ProximityService _instance = ProximityService._internal();
  factory ProximityService() => _instance;
  ProximityService._internal();

  Timer? _timer;
  final Set<int> _zonasNotificadas = {};
  bool _initialized = false;
  bool _isChecking = false;
  List<Map<String, dynamic>> _zonas = [];

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadZonas();
    await _refreshPositionAndCheck();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _refreshPositionAndCheck();
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  Future<void> _loadZonas() async {
    try {
      final sb = Supabase.instance.client;
      final response = await sb.from('zonas_riesgo')
          .select('id, nombre, descripcion, id_nivel_riesgo, radio_metros, latitud, longitud')
          .eq('estado', true)
          .order('id_nivel_riesgo', ascending: false)
          .limit(50);

      _zonas = List<Map<String, dynamic>>.from(response as List);
    } catch (error) {
      debugPrint('ProximityService: error cargando zonas: $error');
      _zonas = [];
    }
  }

  Future<void> _refreshPositionAndCheck() async {
    if (_isChecking) return;

    _isChecking = true;
    try {
      final position = await _determinePosition();
      if (position == null) return;

      if (_zonas.isEmpty) {
        await _loadZonas();
      }

      await _checkProximity(position.latitude, position.longitude);
    } catch (error) {
      debugPrint('ProximityService: error refrescando ubicación: $error');
    } finally {
      _isChecking = false;
    }
  }

  Future<geo.Position?> _determinePosition() async {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('ProximityService: servicio de ubicación deshabilitado');
      return null;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        debugPrint('ProximityService: permiso de ubicación denegado');
        return null;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      debugPrint('ProximityService: permiso de ubicación denegado permanentemente');
      return null;
    }

    try {
      return await geo.Geolocator.getCurrentPosition();
    } catch (error) {
      debugPrint('ProximityService: error obteniendo posición actual: $error');
      return null;
    }
  }

  Future<void> _checkProximity(double lat, double lng) async {
    if (_zonas.isEmpty) return;

    for (final zone in _zonas) {
      final id = zone['id'] as int?;
      final radioMetros = (zone['radio_metros'] as num?)?.toDouble();
      final latitud = (zone['latitud'] as num?)?.toDouble();
      final longitud = (zone['longitud'] as num?)?.toDouble();
      final nombre = zone['nombre'] as String? ?? 'Zona de riesgo';
      final descripcion = zone['descripcion'] as String? ?? '';

      if (id == null || radioMetros == null || latitud == null || longitud == null) {
        continue;
      }

      final distance = geo.Geolocator.distanceBetween(lat, lng, latitud, longitud);
      final inside = distance <= radioMetros;

      if (inside && !_zonasNotificadas.contains(id)) {
        _zonasNotificadas.add(id);
        await NotificationService().showZoneNotification(
          'Zona de riesgo cercana',
          'Estás dentro de la zona "$nombre". $descripcion',
          id: id,
        );
      } else if (!inside && _zonasNotificadas.contains(id)) {
        _zonasNotificadas.remove(id);
      }
    }
  }
}
