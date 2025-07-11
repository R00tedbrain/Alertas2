import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';

import '../../domain/providers/providers.dart';

class MyLocationScreen extends ConsumerStatefulWidget {
  const MyLocationScreen({super.key});

  @override
  ConsumerState<MyLocationScreen> createState() => _MyLocationScreenState();
}

class _MyLocationScreenState extends ConsumerState<MyLocationScreen> {
  MapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  bool _isMapReady = false;
  DateTime? _lastUpdateTime;
  Timer? _updateTimer;

  // Configuración del mapa
  static const LatLng _initialCenter = LatLng(
    40.4168,
    -3.7038,
  ); // Madrid como posición inicial

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _updateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
          _lastUpdateTime = DateTime.now();
        });

        if (_isMapReady && _mapController != null) {
          _animateToCurrentPosition();
        }
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  void _startLocationUpdates() {
    // Actualizar cada 10 segundos para mejor precisión en emergencias
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Actualizar cada 5 metros
        timeLimit: Duration(seconds: 10), // Actualizar cada 10 segundos mínimo
      ),
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            _lastUpdateTime = DateTime.now();
          });

          if (_isMapReady && _mapController != null) {
            _animateToCurrentPosition();
          }
        }
      },
      onError: (error) {
        print('Error en stream de ubicación: $error');
      },
    );

    // Timer adicional para forzar actualización cada 10 segundos
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _getCurrentLocation();
    });
  }

  void _animateToCurrentPosition() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        17.0,
      );
    }
  }

  void _onMapReady() {
    _isMapReady = true;

    // Si ya tenemos una posición, animamos hacia ella
    if (_currentPosition != null) {
      _animateToCurrentPosition();
    }
  }

  void _shareLocation() {
    if (_currentPosition != null) {
      final locationService = ref.read(locationServiceProvider);
      final locationText = locationService.formatLocationMessage(
        _currentPosition!,
      );
      final mapsLink = locationService.getGoogleMapsLink(_currentPosition!);

      // Mostrar opciones de compartir
      showModalBottomSheet(
        context: context,
        builder:
            (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compartir ubicación',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🚨 Mi ubicación de emergencia:\n\n$locationText\n\nVer en mapa: $mapsLink',
                    style: GoogleFonts.nunito(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Aquí podrías integrar con share_plus plugin si lo necesitas
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Funcionalidad de compartir disponible',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Permitir volver atrás con el botón del sistema o gesto iOS
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🚨 Mapa de Emergencia'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () {
                Navigator.of(context).pop();
              },
              tooltip: 'Volver al inicio',
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _getCurrentLocation,
              tooltip: 'Actualizar ubicación',
            ),
          ],
          elevation: 4,
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        body: Stack(
          children: [
            // Mapa principal
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _currentPosition != null
                        ? LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        )
                        : _initialCenter,
                initialZoom: 15.0,
                minZoom: 1.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: _onMapReady,
                onTap: (tapPosition, point) {
                  // Opcional: manejar taps en el mapa
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.emergencia.alertaTelegram',
                  maxNativeZoom: 18,
                ),
                MarkerLayer(markers: _createMarkers()),
              ],
            ),

            // Información superior
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildLocationInfo(),
            ),

            // Botones flotantes
            Positioned(
              bottom: 100,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón compartir ubicación
                  FloatingActionButton(
                    onPressed: _shareLocation,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    mini: true,
                    child: const Icon(Icons.share_location),
                  ),
                  const SizedBox(height: 8),
                  // Botón centrar ubicación
                  FloatingActionButton(
                    onPressed: _getCurrentLocation,
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    mini: true,
                    child: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),

            // Información inferior
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildBottomInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      _currentPosition != null ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currentPosition != null
                    ? 'Ubicación Activa'
                    : 'Obteniendo ubicación...',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_currentPosition != null) ...[
            _buildInfoRow(
              'Latitud:',
              _currentPosition!.latitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Longitud:',
              _currentPosition!.longitude.toStringAsFixed(6),
            ),
            _buildInfoRow(
              'Precisión:',
              '${_currentPosition!.accuracy.toStringAsFixed(0)}m',
            ),
            if (_lastUpdateTime != null)
              _buildInfoRow(
                'Última actualización:',
                _getTimeAgo(_lastUpdateTime!),
              ),
          ] else ...[
            const Center(child: SpinKitPulse(color: Colors.blue, size: 30)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '🚨 Modo Emergencia: Actualización cada 10 segundos o 5 metros. Perfecta precisión para rutas de escape.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inHours}h';
    }
  }

  List<Marker> _createMarkers() {
    if (_currentPosition == null) return [];

    return [
      Marker(
        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            // Mostrar información del marcador
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mi Ubicación - Tu posición actual'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      ),
    ];
  }
}
