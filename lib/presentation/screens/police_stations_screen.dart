import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/providers/providers.dart';
import '../../data/models/police_station.dart';
import '../widgets/police_station_card.dart';
import '../widgets/police_station_filters.dart';
import '../widgets/app_drawer.dart';
import 'remove_ads_screen.dart';

class PoliceStationsScreen extends ConsumerStatefulWidget {
  const PoliceStationsScreen({super.key});

  @override
  ConsumerState<PoliceStationsScreen> createState() =>
      _PoliceStationsScreenState();
}

class _PoliceStationsScreenState extends ConsumerState<PoliceStationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PoliceType>? _selectedTypes;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeSearch() async {
    if (_isInitialized) return;

    final locationAsync = ref.read(currentLocationProvider);
    final policeStationsAvailable = ref.read(policeStationsAvailableProvider);

    if (!policeStationsAvailable) {
      _showPremiumDialog();
      return;
    }

    locationAsync.whenData((position) {
      if (position != null) {
        ref
            .read(policeStationSearchProvider.notifier)
            .searchNearbyStations(
              latitude: position.latitude,
              longitude: position.longitude,
            );
        _isInitialized = true;
      }
    });
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Función Premium'),
            content: const Text(
              'La búsqueda de comisarías cercanas es una función premium. '
              'Actualiza tu suscripción para acceder a esta funcionalidad.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RemoveAdsScreen(),
                    ),
                  );
                },
                child: const Text('Ver Planes'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policeStationsAvailable = ref.watch(policeStationsAvailableProvider);
    final searchState = ref.watch(policeStationSearchProvider);
    final currentLocation = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comisarías Cercanas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        actions: [
          if (policeStationsAvailable) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFiltersDialog(),
              tooltip: 'Filtros',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshData(),
              tooltip: 'Actualizar',
            ),
          ],
        ],
      ),
      drawer: const AppDrawer(),
      body:
          !policeStationsAvailable
              ? _buildPremiumRequired()
              : _buildContent(searchState, currentLocation),
    );
  }

  Widget _buildPremiumRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_police, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Función Premium',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'La búsqueda de comisarías cercanas es una función premium que te permite:',
              style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildFeaturesList(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemoveAdsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.star),
              label: const Text('Ver Planes Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      'Buscar comisarías más cercanas',
      'Llamar directamente desde la app',
      'Navegar con Google Maps o Apple Maps',
      'Ver horarios de atención',
      'Filtrar por tipo de policía',
      'Datos actualizados en tiempo real',
    ];

    return Column(
      children:
          features
              .map(
                (feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildContent(
    PoliceStationSearchState searchState,
    AsyncValue<Position?> currentLocation,
  ) {
    return Column(
      children: [
        // Barra de búsqueda y filtros
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Contador de resultados
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${searchState.stations.length} comisarías encontradas',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_selectedTypes != null && _selectedTypes!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedTypes = null;
                        });
                        ref
                            .read(policeStationSearchProvider.notifier)
                            .updateFilters(null);
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Limpiar filtros'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                    ),
                ],
              ),
              // Filtros activos
              if (_selectedTypes != null && _selectedTypes!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children:
                        _selectedTypes!
                            .map(
                              (type) => Chip(
                                label: Text(
                                  type.displayName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.blue.shade100,
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedTypes!.remove(type);
                                    if (_selectedTypes!.isEmpty) {
                                      _selectedTypes = null;
                                    }
                                  });
                                  ref
                                      .read(
                                        policeStationSearchProvider.notifier,
                                      )
                                      .updateFilters(_selectedTypes);
                                },
                              ),
                            )
                            .toList(),
                  ),
                ),
            ],
          ),
        ),
        // Lista de comisarías
        Expanded(child: _buildStationsList(searchState)),
      ],
    );
  }

  Widget _buildStationsList(PoliceStationSearchState searchState) {
    if (searchState.isLoading) {
      return const Center(child: SpinKitPulse(color: Colors.blue, size: 50.0));
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error al buscar comisarías',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchState.error!,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _refreshData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (searchState.stations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron comisarías',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta ampliar el radio de búsqueda o cambiar los filtros',
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _refreshData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Buscar de nuevo'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchState.stations.length,
      itemBuilder: (context, index) {
        final station = searchState.stations[index];
        return PoliceStationCard(
          station: station,
          onTap: () => _onStationTap(station),
        );
      },
    );
  }

  void _onStationTap(PoliceStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: _buildStationDetails(station),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildStationDetails(PoliceStation station) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: station.typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_police,
                color: station.typeColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    station.type.displayName,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: station.typeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Información
        _buildInfoSection('Información', [
          _buildInfoItem(Icons.location_on, 'Dirección', station.address),
          if (station.phone != null)
            _buildInfoItem(Icons.phone, 'Teléfono', station.phone!),
          if (station.openingHours != null)
            _buildInfoItem(
              Icons.access_time,
              'Horarios',
              station.openingHours!,
            ),
          _buildInfoItem(
            Icons.navigation,
            'Distancia',
            station.formattedDistance,
          ),
        ]),

        const SizedBox(height: 32),

        // Botones de acción
        Column(
          children: [
            // Llamar
            if (station.phone != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(station.phone!),
                  icon: const Icon(Icons.phone),
                  label: const Text('Llamar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Navegar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToStation(station),
                icon: const Icon(Icons.directions),
                label: const Text('Ir con Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Apple Maps (solo iOS)
            if (Theme.of(context).platform == TargetPlatform.iOS)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToStationApple(station),
                  icon: const Icon(Icons.map),
                  label: const Text('Ir con Apple Maps'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder:
          (context) => PoliceStationFiltersDialog(
            selectedTypes: _selectedTypes,
            onApply: (types) {
              setState(() {
                _selectedTypes = types;
              });
              ref
                  .read(policeStationSearchProvider.notifier)
                  .updateFilters(types);
            },
          ),
    );
  }

  void _refreshData() {
    ref.read(policeStationSearchProvider.notifier).forceRefresh();
  }

  Future<void> _makePhoneCall(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo realizar la llamada a $phone')),
        );
      }
    }
  }

  Future<void> _navigateToStation(PoliceStation station) async {
    final url =
        'https://maps.google.com/maps?daddr=${station.latitude},${station.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    }
  }

  Future<void> _navigateToStationApple(PoliceStation station) async {
    final url =
        'https://maps.apple.com/?daddr=${station.latitude},${station.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Apple Maps')),
        );
      }
    }
  }
}
