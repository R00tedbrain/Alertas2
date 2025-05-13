import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/providers/providers.dart';

class StatusCard extends StatelessWidget {
  final AlertStatus status;

  const StatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: status.isActive ? Colors.red.shade50 : Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status.isActive ? Colors.red.shade300 : Colors.blue.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isActive ? Icons.warning_amber : Icons.info_outline,
                  color: status.isActive ? Colors.red : Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado: ${status.isActive ? 'ALERTA ACTIVA' : 'Inactivo'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: status.isActive ? Colors.red : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status.statusMessage,
              style: TextStyle(
                fontSize: 14,
                color: status.isActive ? Colors.red.shade800 : Colors.black87,
              ),
            ),
            if (status.isActive && status.startTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Iniciada: ${_formatDateTime(status.startTime!)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tiempo activa: ${_getElapsedTime(status.startTime!)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  String _getElapsedTime(DateTime startTime) {
    final Duration elapsed = DateTime.now().difference(startTime);
    final int hours = elapsed.inHours;
    final int minutes = elapsed.inMinutes % 60;
    final int seconds = elapsed.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
