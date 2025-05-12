import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class LocationCard extends StatelessWidget {
  final Position position;

  const LocationCard({Key? key, required this.position}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.location_on, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Ubicación actual',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Latitud', position.latitude.toStringAsFixed(6)),
            _buildInfoRow('Longitud', position.longitude.toStringAsFixed(6)),
            _buildInfoRow(
              'Precisión',
              '${position.accuracy.toStringAsFixed(2)} m',
            ),
            _buildInfoRow(
              'Altitud',
              '${position.altitude.toStringAsFixed(2)} m',
            ),
            _buildInfoRow(
              'Velocidad',
              '${position.speed.toStringAsFixed(2)} m/s',
            ),
            _buildInfoRow(
              'Hora',
              DateFormat('HH:mm:ss').format(
                DateTime.fromMillisecondsSinceEpoch(
                  position.timestamp?.millisecondsSinceEpoch ?? 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.map),
                label: const Text('Ver en mapa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
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
