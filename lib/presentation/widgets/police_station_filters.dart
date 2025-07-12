import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/police_station.dart';

class PoliceStationFiltersDialog extends StatefulWidget {
  final List<PoliceType>? selectedTypes;
  final Function(List<PoliceType>?) onApply;

  const PoliceStationFiltersDialog({
    super.key,
    this.selectedTypes,
    required this.onApply,
  });

  @override
  State<PoliceStationFiltersDialog> createState() =>
      _PoliceStationFiltersDialogState();
}

class _PoliceStationFiltersDialogState
    extends State<PoliceStationFiltersDialog> {
  Set<PoliceType> _selectedTypes = {};

  @override
  void initState() {
    super.initState();
    if (widget.selectedTypes != null) {
      _selectedTypes = Set.from(widget.selectedTypes!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Filtrar por Tipo de Policía',
        style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona los tipos de comisarías que quieres ver:',
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ...PoliceType.values.map((type) => _buildTypeCheckbox(type)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedTypes.clear();
            });
          },
          child: const Text('Limpiar Todo'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(
              _selectedTypes.isEmpty ? null : _selectedTypes.toList(),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Widget _buildTypeCheckbox(PoliceType type) {
    final isSelected = _selectedTypes.contains(type);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            _selectedTypes.add(type);
          } else {
            _selectedTypes.remove(type);
          }
        });
      },
      title: Text(
        type.displayName,
        style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _getTypeDescription(type),
        style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[600]),
      ),
      secondary: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _getTypeColor(type).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.local_police, color: _getTypeColor(type), size: 16),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getTypeDescription(PoliceType type) {
    switch (type) {
      case PoliceType.policiaNacional:
        return 'Cuerpo Nacional de Policía';
      case PoliceType.guardiaCivil:
        return 'Fuerza de seguridad estatal';
      case PoliceType.policiaLocal:
        return 'Policía municipal y local';
      case PoliceType.mossos:
        return 'Cataluña - Mossos d\'Esquadra';
      case PoliceType.ertzaintza:
        return 'País Vasco - Ertzaintza';
      case PoliceType.other:
        return 'Otros cuerpos de policía';
    }
  }

  Color _getTypeColor(PoliceType type) {
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
      case PoliceType.other:
        return const Color(0xFF6B7280);
    }
  }
}
