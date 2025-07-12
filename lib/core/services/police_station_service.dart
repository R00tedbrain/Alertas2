import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../../data/models/police_station.dart';
import 'debug_logger.dart';

class PoliceStationService {
  // Logger
  final _logger = Logger();
  final _debugLogger = DebugLogger.instance;

  // Singleton
  static final PoliceStationService _instance =
      PoliceStationService._internal();
  factory PoliceStationService() => _instance;
  PoliceStationService._internal() {
    _debugLogger.info('PoliceStationService', 'Instancia creada');
  }

  // URLs de APIs
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String _overpassBackupUrl =
      'https://overpass.private.coffee/api/interpreter';
  static const String _nominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  // Cache
  static const String _cacheKey = 'police_stations_cache';
  static const String _cacheTimestampKey = 'police_stations_cache_timestamp';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Límites de búsqueda
  static const int _maxResults = 50;
  static const int _maxRadiusMeters = 25000; // 25km máximo

  /// Buscar comisarías de policía cercanas
  Future<List<PoliceStation>> findNearbyPoliceStations({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    List<PoliceType>? filterTypes,
    bool forceRefresh = false,
  }) async {
    try {
      _debugLogger.info('PoliceStationService', 'Buscando comisarías cercanas');
      _debugLogger.info(
        'PoliceStationService',
        'Ubicación: $latitude, $longitude',
      );
      _debugLogger.info('PoliceStationService', 'Radio: ${radiusMeters}m');

      // Validar parámetros
      if (radiusMeters > _maxRadiusMeters) {
        radiusMeters = _maxRadiusMeters;
        _debugLogger.warning(
          'PoliceStationService',
          'Radio limitado a ${_maxRadiusMeters}m',
        );
      }

      // Intentar obtener del cache primero
      if (!forceRefresh) {
        final cachedStations = await _getCachedStations(
          latitude,
          longitude,
          radiusMeters,
        );
        if (cachedStations.isNotEmpty) {
          _debugLogger.success(
            'PoliceStationService',
            'Datos encontrados en cache: ${cachedStations.length} comisarías',
          );
          return _filterAndSortStations(
            cachedStations,
            latitude,
            longitude,
            filterTypes,
          );
        }
      }

      // Buscar en OpenStreetMap
      List<PoliceStation> stations = [];

      try {
        stations = await _searchWithOverpass(latitude, longitude, radiusMeters);
        _debugLogger.success(
          'PoliceStationService',
          'Overpass API: ${stations.length} comisarías encontradas',
        );
      } catch (e) {
        _debugLogger.error(
          'PoliceStationService',
          'Error con Overpass API: $e',
        );

        // Intentar con backup
        try {
          stations = await _searchWithOverpassBackup(
            latitude,
            longitude,
            radiusMeters,
          );
          _debugLogger.success(
            'PoliceStationService',
            'Backup Overpass API: ${stations.length} comisarías encontradas',
          );
        } catch (e2) {
          _debugLogger.error(
            'PoliceStationService',
            'Error con Backup Overpass API: $e2',
          );

          // Fallback a Nominatim
          try {
            stations = await _searchWithNominatim(
              latitude,
              longitude,
              radiusMeters,
            );
            _debugLogger.success(
              'PoliceStationService',
              'Nominatim API: ${stations.length} comisarías encontradas',
            );
          } catch (e3) {
            _debugLogger.error(
              'PoliceStationService',
              'Error con Nominatim API: $e3',
            );
            throw Exception(
              'No se pudo obtener datos de comisarías de policía',
            );
          }
        }
      }

      // Calcular distancias y filtrar
      final stationsWithDistance = _calculateDistances(
        stations,
        latitude,
        longitude,
      );

      // Guardar en cache
      await _cacheStations(stationsWithDistance, latitude, longitude);

      // Filtrar y ordenar
      final filteredStations = _filterAndSortStations(
        stationsWithDistance,
        latitude,
        longitude,
        filterTypes,
      );

      _debugLogger.info(
        'PoliceStationService',
        'Resultado final: ${filteredStations.length} comisarías',
      );
      return filteredStations;
    } catch (e) {
      _debugLogger.error(
        'PoliceStationService',
        'Error en findNearbyPoliceStations: $e',
      );
      _logger.e('Error buscando comisarías de policía: $e');
      rethrow;
    }
  }

  /// Obtener comisaría por ID
  Future<PoliceStation?> getPoliceStationById(String id) async {
    try {
      _debugLogger.info(
        'PoliceStationService',
        'Buscando comisaría por ID: $id',
      );

      // Buscar en cache primero
      final cachedStations = await _getAllCachedStations();
      final station = cachedStations.firstWhere(
        (s) => s.id == id,
        orElse: () => throw StateError('Not found'),
      );

      _debugLogger.success(
        'PoliceStationService',
        'Comisaría encontrada en cache',
      );
      return station;
    } catch (e) {
      _debugLogger.error(
        'PoliceStationService',
        'Error obteniendo comisaría por ID: $e',
      );
      return null;
    }
  }

  /// Buscar con Overpass API
  Future<List<PoliceStation>> _searchWithOverpass(
    double latitude,
    double longitude,
    int radiusMeters,
  ) async {
    final query = '''
      [out:json][timeout:30];
      (
        node["amenity"="police"]
          (around:$radiusMeters,$latitude,$longitude);
        way["amenity"="police"]
          (around:$radiusMeters,$latitude,$longitude);
        relation["amenity"="police"]
          (around:$radiusMeters,$latitude,$longitude);
      );
      out center tags;
    ''';

    return await _executeOverpassQuery(query, _overpassUrl);
  }

  /// Buscar con Overpass API backup
  Future<List<PoliceStation>> _searchWithOverpassBackup(
    double latitude,
    double longitude,
    int radiusMeters,
  ) async {
    final query = '''
      [out:json][timeout:30];
      (
        node["amenity"="police"]
          (around:$radiusMeters,$latitude,$longitude);
        way["amenity"="police"]
          (around:$radiusMeters,$latitude,$longitude);
      );
      out center tags;
    ''';

    return await _executeOverpassQuery(query, _overpassBackupUrl);
  }

  /// Ejecutar consulta Overpass
  Future<List<PoliceStation>> _executeOverpassQuery(
    String query,
    String url,
  ) async {
    _debugLogger.info(
      'PoliceStationService',
      'Ejecutando consulta Overpass...',
    );

    final response = await http
        .post(
          Uri.parse(url),
          body: 'data=${Uri.encodeComponent(query)}',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': 'AlertaTelegram/1.0',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final elements = data['elements'] as List;

      return elements
          .map((element) => PoliceStation.fromOverpassElement(element))
          .take(_maxResults)
          .toList();
    } else {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Buscar con Nominatim API
  Future<List<PoliceStation>> _searchWithNominatim(
    double latitude,
    double longitude,
    int radiusMeters,
  ) async {
    _debugLogger.info(
      'PoliceStationService',
      'Ejecutando consulta Nominatim...',
    );

    final radiusKm = radiusMeters / 1000;
    final boundingBox = _calculateBoundingBox(latitude, longitude, radiusKm);

    final url = Uri.parse(_nominatimUrl).replace(
      queryParameters: {
        'q': 'comisaría policía',
        'format': 'json',
        'addressdetails': '1',
        'extratags': '1',
        'limit': _maxResults.toString(),
        'bounded': '1',
        'viewbox': boundingBox,
        'countrycodes': 'es',
      },
    );

    final response = await http
        .get(url, headers: {'User-Agent': 'AlertaTelegram/1.0'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;

      return data
          .map((item) => _parseNominatimResult(item))
          .where((station) => station != null)
          .cast<PoliceStation>()
          .toList();
    } else {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Parsear resultado de Nominatim
  PoliceStation? _parseNominatimResult(Map<String, dynamic> item) {
    try {
      final lat = double.parse(item['lat']);
      final lon = double.parse(item['lon']);
      final displayName = item['display_name'] as String;

      return PoliceStation(
        id: item['place_id'].toString(),
        name: item['name'] ?? 'Comisaría de Policía',
        address: displayName,
        latitude: lat,
        longitude: lon,
        type: PoliceType.policiaNacional,
        isOpen: true,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      _debugLogger.error(
        'PoliceStationService',
        'Error parseando resultado Nominatim: $e',
      );
      return null;
    }
  }

  /// Calcular bounding box
  String _calculateBoundingBox(double lat, double lon, double radiusKm) {
    const double earthRadius = 6371; // km

    final latRad = lat * math.pi / 180;
    final deltaLat = radiusKm / earthRadius;
    final deltaLon = radiusKm / (earthRadius * math.cos(latRad));

    final minLat = lat - deltaLat * 180 / math.pi;
    final maxLat = lat + deltaLat * 180 / math.pi;
    final minLon = lon - deltaLon * 180 / math.pi;
    final maxLon = lon + deltaLon * 180 / math.pi;

    return '$minLon,$minLat,$maxLon,$maxLat';
  }

  /// Calcular distancias
  List<PoliceStation> _calculateDistances(
    List<PoliceStation> stations,
    double userLat,
    double userLon,
  ) {
    return stations.map((station) {
      final distance = Geolocator.distanceBetween(
        userLat,
        userLon,
        station.latitude,
        station.longitude,
      );

      return station.copyWith(distanceMeters: distance);
    }).toList();
  }

  /// Filtrar y ordenar comisarías
  List<PoliceStation> _filterAndSortStations(
    List<PoliceStation> stations,
    double userLat,
    double userLon,
    List<PoliceType>? filterTypes,
  ) {
    var filteredStations = stations;

    // Aplicar filtros de tipo
    if (filterTypes != null && filterTypes.isNotEmpty) {
      filteredStations =
          filteredStations
              .where((station) => filterTypes.contains(station.type))
              .toList();
    }

    // Ordenar por distancia
    filteredStations.sort((a, b) {
      final distA = a.distanceMeters ?? double.infinity;
      final distB = b.distanceMeters ?? double.infinity;
      return distA.compareTo(distB);
    });

    return filteredStations.take(_maxResults).toList();
  }

  /// Obtener del cache
  Future<List<PoliceStation>> _getCachedStations(
    double latitude,
    double longitude,
    int radiusMeters,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey) ?? 0;

      // Verificar si el cache ha expirado
      if (DateTime.now().millisecondsSinceEpoch - cacheTimestamp >
          _cacheExpiry.inMilliseconds) {
        _debugLogger.info(
          'PoliceStationService',
          'Cache expirado, limpiando...',
        );
        await _clearCache();
        return [];
      }

      final cacheData = prefs.getString(_cacheKey);
      if (cacheData == null) return [];

      final List<dynamic> jsonList = json.decode(cacheData);
      final allStations =
          jsonList.map((json) => PoliceStation.fromJson(json)).toList();

      // Filtrar por ubicación y radio
      final nearbyStations =
          allStations.where((station) {
            final distance = Geolocator.distanceBetween(
              latitude,
              longitude,
              station.latitude,
              station.longitude,
            );
            return distance <= radiusMeters;
          }).toList();

      return nearbyStations;
    } catch (e) {
      _debugLogger.error('PoliceStationService', 'Error obteniendo cache: $e');
      return [];
    }
  }

  /// Obtener todas las comisarías en cache
  Future<List<PoliceStation>> _getAllCachedStations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      if (cacheData == null) return [];

      final List<dynamic> jsonList = json.decode(cacheData);
      return jsonList.map((json) => PoliceStation.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Guardar en cache
  Future<void> _cacheStations(
    List<PoliceStation> stations,
    double centerLat,
    double centerLon,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obtener estaciones existentes en cache
      final existingStations = await _getAllCachedStations();

      // Combinar con las nuevas evitando duplicados
      final allStations = <String, PoliceStation>{};

      // Agregar existentes
      for (final station in existingStations) {
        allStations[station.id] = station;
      }

      // Agregar nuevas (sobrescribir si ya existe)
      for (final station in stations) {
        allStations[station.id] = station;
      }

      // Guardar en cache
      final jsonList =
          allStations.values.map((station) => station.toJson()).toList();
      await prefs.setString(_cacheKey, json.encode(jsonList));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      _debugLogger.success(
        'PoliceStationService',
        'Cache actualizado: ${allStations.length} comisarías',
      );
    } catch (e) {
      _debugLogger.error('PoliceStationService', 'Error guardando cache: $e');
    }
  }

  /// Limpiar cache
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      _debugLogger.success('PoliceStationService', 'Cache limpiado');
    } catch (e) {
      _debugLogger.error('PoliceStationService', 'Error limpiando cache: $e');
    }
  }

  /// Precargar datos para ciudades principales
  Future<void> preloadMajorCities() async {
    final majorCities = [
      {'name': 'Madrid', 'lat': 40.4168, 'lon': -3.7038},
      {'name': 'Barcelona', 'lat': 41.3851, 'lon': 2.1734},
      {'name': 'Valencia', 'lat': 39.4699, 'lon': -0.3763},
      {'name': 'Sevilla', 'lat': 37.3891, 'lon': -5.9845},
      {'name': 'Bilbao', 'lat': 43.2627, 'lon': -2.9253},
    ];

    _debugLogger.info(
      'PoliceStationService',
      'Precargando datos para ciudades principales...',
    );

    for (final city in majorCities) {
      try {
        await findNearbyPoliceStations(
          latitude: city['lat']! as double,
          longitude: city['lon']! as double,
          radiusMeters: 10000,
          forceRefresh: false,
        );
        _debugLogger.success(
          'PoliceStationService',
          '${city['name']} precargado',
        );
      } catch (e) {
        _debugLogger.error(
          'PoliceStationService',
          'Error precargando ${city['name']}: $e',
        );
      }
    }
  }

  /// Obtener estadísticas del cache
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      final cacheTimestamp = prefs.getInt(_cacheTimestampKey) ?? 0;

      if (cacheData == null) {
        return {'stations': 0, 'lastUpdate': null, 'isExpired': true};
      }

      final List<dynamic> jsonList = json.decode(cacheData);
      final lastUpdate = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
      final isExpired = DateTime.now().difference(lastUpdate) > _cacheExpiry;

      return {
        'stations': jsonList.length,
        'lastUpdate': lastUpdate,
        'isExpired': isExpired,
      };
    } catch (e) {
      return {'stations': 0, 'lastUpdate': null, 'isExpired': true};
    }
  }
}
