import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../domain/providers/providers.dart';
import '../../data/models/app_config.dart';
import '../../data/models/emergency_contact.dart';
import '../widgets/alert_button.dart';
import '../widgets/status_card.dart';
import '../widgets/location_card.dart';
import '../widgets/contacts_list.dart';
import '../widgets/app_drawer.dart';
import 'settings_screen.dart';
import 'remove_ads_screen.dart';
import 'police_stations_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfig = ref.watch(appConfigProvider);
    final alertStatus = ref.watch(alertStatusProvider);
    final currentLocation = ref.watch(currentLocationProvider);

    // Verificar permisos cuando se construye la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions(context, ref);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerta Telegram'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Estado de alerta
                StatusCard(status: alertStatus),

                const SizedBox(height: 16),

                // Estado premium
                _buildPremiumStatusCard(context, ref),

                const SizedBox(height: 16),

                // Función premium: comisarías de policía
                _buildPoliceStationsCard(context, ref),

                const SizedBox(height: 16),

                // Configuración rápida
                _buildQuickConfigCard(context, ref, appConfig),

                const SizedBox(height: 16),

                // Ubicación actual
                currentLocation.when(
                  data:
                      (position) =>
                          position != null
                              ? LocationCard(position: position)
                              : const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Ubicación no disponible'),
                                ),
                              ),
                  loading:
                      () => const Center(
                        child: SpinKitPulse(color: Colors.blue, size: 50.0),
                      ),
                  error:
                      (error, _) => Card(
                        color: Colors.red.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                ),

                const SizedBox(height: 16),

                // Contactos de emergencia
                Container(
                  height: 300, // Altura fija para la lista de contactos
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Contactos de Emergencia',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            color: Colors.green,
                            onPressed:
                                () => _showAddContactDialog(context, ref),
                            tooltip: 'Añadir contacto',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      appConfig.emergencyContacts.isEmpty
                          ? const Expanded(
                            child: Center(
                              child: Text(
                                'No hay contactos de emergencia',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                          : Expanded(
                            child: ContactsList(
                              contacts: appConfig.emergencyContacts,
                              onDelete:
                                  (contact) =>
                                      _deleteContact(ref, contact.chatId),
                            ),
                          ),
                    ],
                  ),
                ),

                // Botón de alerta
                const SizedBox(height: 16),
                AlertButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tarjeta de estado premium
  Widget _buildPremiumStatusCard(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final premiumAsync = ref.watch(premiumSubscriptionProvider);
        final hasPremium = ref.watch(hasPremiumProvider);

        return premiumAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (subscription) {
            if (hasPremium) {
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green.shade200, width: 1),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium Activo',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              Text(
                                'Plan ${subscription.productType?.name.toUpperCase() ?? 'DESCONOCIDO'}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              if (subscription.daysRemaining > 0)
                                Text(
                                  '${subscription.daysRemaining} días restantes',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 16,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Audio HD',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.green.shade600,
                              size: 16,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GPS Pro',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade200, width: 1),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.orange.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.star_border,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Versión Gratuita',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              Text(
                                'Mejora a Premium para funciones avanzadas',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RemoveAdsScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(80, 32),
                          ),
                          child: const Text(
                            'Mejorar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  // Tarjeta de configuración rápida
  Widget _buildQuickConfigCard(
    BuildContext context,
    WidgetRef ref,
    AppConfig appConfig,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configuración Telegram Bot',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed:
                      () => _showTokenDialog(
                        context,
                        ref,
                        appConfig.telegramBotToken,
                      ),
                  tooltip: 'Editar token',
                ),
              ],
            ),
            Text(
              appConfig.telegramBotToken.isEmpty
                  ? 'Token no configurado'
                  : 'Token: ${_maskToken(appConfig.telegramBotToken)}',
              style: TextStyle(
                color:
                    appConfig.telegramBotToken.isEmpty
                        ? Colors.red
                        : Colors.black87,
                fontStyle:
                    appConfig.telegramBotToken.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mascara el token para mostrar solo los primeros y últimos caracteres
  String _maskToken(String token) {
    if (token.length <= 8) return token;
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  // Muestra un diálogo para editar el token
  void _showTokenDialog(
    BuildContext context,
    WidgetRef ref,
    String currentToken,
  ) {
    final tokenController = TextEditingController(text: currentToken);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Token de Telegram Bot'),
            content: TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                hintText: 'Introduce el token de BotFather',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (tokenController.text.isNotEmpty) {
                    ref
                        .read(appConfigProvider.notifier)
                        .updateToken(tokenController.text);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  // Tarjeta para promocionar las comisarías de policía
  Widget _buildPoliceStationsCard(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasPremiumProvider);
    final isInTrial = ref.watch(isInTrialProvider);

    if (hasPremium || isInTrial) {
      // Si tiene premium o está en trial, mostrar acceso directo
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.shade200, width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_police,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comisarías Cercanas',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Encuentra la comisaría de policía más cercana',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PoliceStationsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text('Buscar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Si no tiene premium, mostrar promoción
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.purple.shade200, width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.purple.shade50, Colors.purple.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_police,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Comisarías Cercanas',
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Localiza comisarías, llama y navega directamente',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RemoveAdsScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 32),
                  ),
                  child: const Text('Premium', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Muestra un diálogo para añadir un contacto
  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final chatIdController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Añadir Contacto de Emergencia'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej: Familiar 1',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, introduce un nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: chatIdController,
                    decoration: const InputDecoration(
                      labelText: 'Chat ID',
                      hintText: 'ID proporcionado por el bot',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, introduce el Chat ID';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final contact = EmergencyContact(
                      name: nameController.text,
                      chatId: chatIdController.text,
                    );
                    ref
                        .read(appConfigProvider.notifier)
                        .addEmergencyContact(contact);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Añadir'),
              ),
            ],
          ),
    );
  }

  // Eliminar un contacto
  void _deleteContact(WidgetRef ref, String chatId) {
    ref.read(appConfigProvider.notifier).removeEmergencyContact(chatId);
  }

  // Método para verificar y solicitar permisos
  Future<void> _checkPermissions(BuildContext context, WidgetRef ref) async {
    // Verificar permisos actuales
    final permissionsProvider = ref.read(permissionServiceProvider);

    // Verificar ubicación y ubicación en segundo plano
    final isLocationGranted =
        await permissionsProvider.isLocationPermissionGranted();
    final isBackgroundLocationGranted =
        await permissionsProvider.isBackgroundLocationPermissionGranted();

    // Si falta algún permiso crítico, mostrar el diálogo informativo
    if (!isLocationGranted || !isBackgroundLocationGranted) {
      // Pequeño retraso para que la UI se renderice primero
      await Future.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        _showPermissionsDialog(
          context,
          ref,
          !isLocationGranted,
          !isBackgroundLocationGranted,
        );
      }
    }
  }

  // Diálogo informativo sobre permisos
  void _showPermissionsDialog(
    BuildContext context,
    WidgetRef ref,
    bool needsLocation,
    bool needsBackgroundLocation,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permisos necesarios'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Para que la aplicación funcione correctamente, se necesitan los siguientes permisos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (needsLocation) ...[
                  const Text('• Ubicación mientras se usa la app'),
                  const SizedBox(height: 8),
                  const Text(
                    'Esto permite enviar tu ubicación actual a los contactos de emergencia.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                ],
                if (needsBackgroundLocation) ...[
                  const Text('• Ubicación en segundo plano'),
                  const SizedBox(height: 8),
                  const Text(
                    'Permite enviar actualizaciones de ubicación incluso cuando la app no está abierta. Esto es crucial para el funcionamiento de las alertas.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'En iOS, primero debes aceptar el permiso "Mientras usas la app" y luego "Siempre" para la ubicación en segundo plano.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Más tarde'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final permissionService = ref.read(permissionServiceProvider);

                // Para iOS, el flujo debe ser primero 'mientras se usa' y luego 'siempre'
                if (needsLocation) {
                  await permissionService.requestLocationPermission();
                }

                if (needsBackgroundLocation) {
                  await permissionService.requestBackgroundLocationPermission();
                }
              },
              child: const Text('Solicitar permisos'),
            ),
          ],
        );
      },
    );
  }
}
