import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../core/services/debug_logger.dart';

class DebugConsoleScreen extends ConsumerStatefulWidget {
  const DebugConsoleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends ConsumerState<DebugConsoleScreen> {
  final ScrollController _scrollController = ScrollController();
  final DebugLogger _logger = DebugLogger.instance;
  StreamSubscription<LogEntry>? _logSubscription;

  LogLevel? _selectedFilter;
  bool _autoScroll = true;
  bool _showTimestamp = true;

  @override
  void initState() {
    super.initState();

    // Escuchar nuevos logs
    _logSubscription = _logger.logStream.listen((logEntry) {
      if (_autoScroll && _scrollController.hasClients) {
        // Scroll automático a la parte inferior
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredLogs {
    if (_selectedFilter == null) {
      return _logger.logs;
    }
    return _logger.logs.where((log) => log.level == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          // Botón de auto-scroll
          IconButton(
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_center,
            ),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip:
                _autoScroll ? 'Desactivar auto-scroll' : 'Activar auto-scroll',
          ),
          // Botón de timestamp
          IconButton(
            icon: Icon(
              _showTimestamp ? Icons.access_time : Icons.access_time_outlined,
            ),
            onPressed: () {
              setState(() {
                _showTimestamp = !_showTimestamp;
              });
            },
            tooltip:
                _showTimestamp ? 'Ocultar timestamps' : 'Mostrar timestamps',
          ),
          // Botón de copiar
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogsToClipboard,
            tooltip: 'Copiar logs',
          ),
          // Botón de limpiar
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Limpiar logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Text(
                  'Filtrar: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                ..._buildFilterChips(),
              ],
            ),
          ),
          // Lista de logs
          Expanded(
            child: Container(color: Colors.black, child: _buildLogsList()),
          ),
          // Información del estado
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Text('Total: ${_logger.logs.length}'),
                const SizedBox(width: 16),
                Text('Filtrados: ${_filteredLogs.length}'),
                const Spacer(),
                Text('Auto-scroll: ${_autoScroll ? "ON" : "OFF"}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    return [
      FilterChip(
        label: const Text('Todos'),
        selected: _selectedFilter == null,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = null;
          });
        },
      ),
      const SizedBox(width: 8),
      ...LogLevel.values.map(
        (level) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: FilterChip(
            label: Text('${level.icon} ${level.name}'),
            selected: _selectedFilter == level,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = selected ? level : null;
              });
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildLogsList() {
    final logs = _filteredLogs;

    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No hay logs disponibles',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    Color textColor;
    switch (log.level) {
      case LogLevel.debug:
        textColor = Colors.blue[300]!;
        break;
      case LogLevel.info:
        textColor = Colors.green[300]!;
        break;
      case LogLevel.warning:
        textColor = Colors.orange[300]!;
        break;
      case LogLevel.error:
        textColor = Colors.red[300]!;
        break;
      case LogLevel.success:
        textColor = Colors.green[400]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: SelectableText(
        _showTimestamp
            ? log.fullText
            : '${log.levelIcon} ${log.tag}: ${log.message}',
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  void _copyLogsToClipboard() async {
    final logs = _logger.exportLogs();
    await Clipboard.setData(ClipboardData(text: logs));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_logger.logs.length} logs copiados al portapapeles'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Limpiar Logs'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar todos los logs?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  _logger.clear();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logs limpiados'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Limpiar'),
              ),
            ],
          ),
    );
  }
}
