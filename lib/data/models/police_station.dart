import 'package:flutter/material.dart';

class PoliceStation {
  final String id;
  final String name;
  final String? operator;
  final String? phone;
  final String address;
  final double latitude;
  final double longitude;
  final String? openingHours;
  final String? website;
  final double? distanceMeters;
  final PoliceType type;
  final bool isOpen;
  final DateTime? lastUpdated;

  const PoliceStation({
    required this.id,
    required this.name,
    this.operator,
    this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.openingHours,
    this.website,
    this.distanceMeters,
    required this.type,
    required this.isOpen,
    this.lastUpdated,
  });

  // Desde JSON
  factory PoliceStation.fromJson(Map<String, dynamic> json) {
    return PoliceStation(
      id: json['id'] as String,
      name: json['name'] as String,
      operator: json['operator'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      openingHours: json['opening_hours'] as String?,
      website: json['website'] as String?,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      type: PoliceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PoliceType.policiaNacional,
      ),
      isOpen: json['is_open'] as bool? ?? false,
      lastUpdated:
          json['last_updated'] != null
              ? DateTime.parse(json['last_updated'])
              : null,
    );
  }

  // Desde OpenStreetMap/Overpass API
  factory PoliceStation.fromOverpassElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final lat = (element['lat'] ?? element['center']?['lat']) as double;
    final lon = (element['lon'] ?? element['center']?['lon']) as double;

    return PoliceStation(
      id: element['id'].toString(),
      name: _extractName(tags),
      operator: tags['operator'] as String?,
      phone: tags['phone'] as String? ?? tags['contact:phone'] as String?,
      address: _buildAddress(tags),
      latitude: lat,
      longitude: lon,
      openingHours: tags['opening_hours'] as String?,
      website: tags['website'] as String? ?? tags['contact:website'] as String?,
      type: _determinePoliceType(tags),
      isOpen: _isCurrentlyOpen(tags['opening_hours'] as String?),
      lastUpdated: DateTime.now(),
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'operator': operator,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'opening_hours': openingHours,
      'website': website,
      'distance_meters': distanceMeters,
      'type': type.name,
      'is_open': isOpen,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  // Copiar con
  PoliceStation copyWith({
    String? id,
    String? name,
    String? operator,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? openingHours,
    String? website,
    double? distanceMeters,
    PoliceType? type,
    bool? isOpen,
    DateTime? lastUpdated,
  }) {
    return PoliceStation(
      id: id ?? this.id,
      name: name ?? this.name,
      operator: operator ?? this.operator,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      openingHours: openingHours ?? this.openingHours,
      website: website ?? this.website,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      type: type ?? this.type,
      isOpen: isOpen ?? this.isOpen,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Formatear distancia
  String get formattedDistance {
    if (distanceMeters == null) return 'Distancia desconocida';

    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    } else {
      return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
    }
  }

  // Obtener icono según tipo
  String get iconPath {
    switch (type) {
      case PoliceType.guardiaCivil:
        return 'assets/icons/guardia_civil.png';
      case PoliceType.policiaNacional:
        return 'assets/icons/policia_nacional.png';
      case PoliceType.policiaLocal:
        return 'assets/icons/policia_local.png';
      case PoliceType.mossos:
        return 'assets/icons/mossos.png';
      case PoliceType.ertzaintza:
        return 'assets/icons/ertzaintza.png';
      default:
        return 'assets/icons/police_default.png';
    }
  }

  // Obtener color según tipo
  Color get typeColor {
    switch (type) {
      case PoliceType.guardiaCivil:
        return const Color(0xFF0F4C75);
      case PoliceType.policiaNacional:
        return const Color(0xFF1E3A8A);
      case PoliceType.policiaLocal:
        return const Color(0xFF059669);
      case PoliceType.mossos:
        return const Color(0xFF7C3AED);
      case PoliceType.ertzaintza:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  // Métodos privados auxiliares
  static String _extractName(Map<String, dynamic> tags) {
    if (tags['name'] != null) return tags['name'];
    if (tags['official_name'] != null) return tags['official_name'];

    final operator = tags['operator'] as String?;
    if (operator != null) {
      return operator;
    }

    return 'Comisaría de Policía';
  }

  static String _buildAddress(Map<String, dynamic> tags) {
    final parts = <String>[];

    if (tags['addr:street'] != null) {
      final street = tags['addr:street'];
      final number = tags['addr:housenumber'];
      if (number != null) {
        parts.add('$street $number');
      } else {
        parts.add(street);
      }
    }

    if (tags['addr:city'] != null) parts.add(tags['addr:city']);
    if (tags['addr:postcode'] != null) parts.add(tags['addr:postcode']);

    return parts.isNotEmpty ? parts.join(', ') : 'Dirección no disponible';
  }

  static PoliceType _determinePoliceType(Map<String, dynamic> tags) {
    final operator = (tags['operator'] as String?)?.toLowerCase();

    if (operator == null) return PoliceType.policiaNacional;

    if (operator.contains('guardia civil')) return PoliceType.guardiaCivil;
    if (operator.contains('policía nacional') ||
        operator.contains('policia nacional')) {
      return PoliceType.policiaNacional;
    }
    if (operator.contains('policía local') ||
        operator.contains('policia local')) {
      return PoliceType.policiaLocal;
    }
    if (operator.contains('mossos')) return PoliceType.mossos;
    if (operator.contains('ertzaintza')) return PoliceType.ertzaintza;

    return PoliceType.policiaNacional;
  }

  static bool _isCurrentlyOpen(String? openingHours) {
    if (openingHours == null || openingHours.isEmpty) return true;

    // Implementación simple para horarios básicos
    // En una implementación completa, se usaría una librería como opening_hours_parser
    if (openingHours.toLowerCase().contains('24/7')) return true;
    if (openingHours.toLowerCase().contains('24 hours')) return true;

    return true; // Por defecto asumimos que está abierto
  }

  @override
  String toString() =>
      'PoliceStation(name: $name, type: $type, distance: $formattedDistance)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PoliceStation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum PoliceType {
  policiaNacional,
  guardiaCivil,
  policiaLocal,
  mossos,
  ertzaintza,
  other,
}

extension PoliceTypeExtension on PoliceType {
  String get displayName {
    switch (this) {
      case PoliceType.policiaNacional:
        return 'Policía Nacional';
      case PoliceType.guardiaCivil:
        return 'Guardia Civil';
      case PoliceType.policiaLocal:
        return 'Policía Local';
      case PoliceType.mossos:
        return 'Mossos d\'Esquadra';
      case PoliceType.ertzaintza:
        return 'Ertzaintza';
      case PoliceType.other:
        return 'Otro';
    }
  }
}
