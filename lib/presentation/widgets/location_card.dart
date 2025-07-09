import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import '../screens/my_location_screen.dart';

class LocationCard extends StatefulWidget {
  final Position position;

  const LocationCard({super.key, required this.position});

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  MapController? _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la posición cambió significativamente, actualizar el mapa
    if (oldWidget.position.latitude != widget.position.latitude ||
        oldWidget.position.longitude != widget.position.longitude) {
      _animateToCurrentPosition();
    }
  }

  // Método para navegar a la pantalla de mapa completo
  void _navigateToFullMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyLocationScreen()),
    );
  }

  // Animar el mapa a la posición actual
  void _animateToCurrentPosition() {
    if (_mapController != null && mounted) {
      _mapController!.move(
        LatLng(widget.position.latitude, widget.position.longitude),
        16.0,
      );
    }
  }

  // Crear marcadores actualizados
  List<Marker> _createMarkers() {
    return [
      Marker(
        point: LatLng(widget.position.latitude, widget.position.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            // Mostrar información del marcador
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Mi Ubicación - Precisión: ${widget.position.accuracy.toStringAsFixed(1)}m',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      ),
    ];
  }

  // Método para abrir el navegador con la ubicación en OpenStreetMap (backup)
  Future<void> _openMap(double latitude, double longitude) async {
    final url =
        'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=16/$latitude/$longitude';

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('No se pudo abrir el mapa: $url');
      }
    } catch (e) {
      print('Error al abrir el mapa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Icon(Icons.location_on, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Ubicación actual',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Mapa integrado - Solo mostrar en móvil/tablet, no en web
          if (!kIsWeb)
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      widget.position.latitude,
                      widget.position.longitude,
                    ),
                    initialZoom: 16.0,
                    minZoom: 1.0,
                    maxZoom: 18.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.emergencia.alertaTelegram',
                      maxNativeZoom: 18,
                    ),
                    MarkerLayer(markers: _createMarkers()),
                  ],
                ),
              ),
            ),

          // Información de la ubicación
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!kIsWeb) const SizedBox(height: 8),
                _buildInfoRow(
                  'Latitud',
                  widget.position.latitude.toStringAsFixed(6),
                ),
                _buildInfoRow(
                  'Longitud',
                  widget.position.longitude.toStringAsFixed(6),
                ),
                _buildInfoRow(
                  'Precisión',
                  '${widget.position.accuracy.toStringAsFixed(2)} m',
                ),
                _buildInfoRow(
                  'Altitud',
                  '${widget.position.altitude.toStringAsFixed(2)} m',
                ),
                _buildInfoRow(
                  'Velocidad',
                  '${widget.position.speed.toStringAsFixed(2)} m/s',
                ),
                _buildInfoRow(
                  'Hora',
                  DateFormat('HH:mm:ss').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      widget.position.timestamp.millisecondsSinceEpoch ?? 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed:
                        kIsWeb
                            ? () => _openMap(
                              widget.position.latitude,
                              widget.position.longitude,
                            )
                            : () => _navigateToFullMap(),
                    icon: const Icon(Icons.map),
                    label: Text(
                      kIsWeb ? 'Ver en OpenStreetMap' : 'Ver mapa completo',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
