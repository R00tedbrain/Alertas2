import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

import '../../config.dart' as app_config;
import '../../core/services/audio_service.dart';
import '../../core/services/background_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/telegram_service.dart';
import '../../data/models/app_config.dart';
import '../../data/models/emergency_contact.dart';

// Providers de Servicios
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(),
);
final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final telegramServiceProvider = Provider<TelegramService>(
  (ref) => TelegramService(),
);
final backgroundServiceProvider = Provider<BackgroundAlertService>(
  (ref) => BackgroundAlertService(),
);

// Provider para verificar el token de Telegram
final verifyTelegramTokenProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final telegramService = ref.read(telegramServiceProvider);
  final configService = ref.read(configServiceProvider);

  if (configService.telegramBotToken.isEmpty) {
    print('El token de Telegram está vacío, no se puede verificar');
    return false;
  }

  telegramService.initialize(configService.telegramBotToken);
  return await telegramService.verifyToken();
});

// Provider para la inicialización de la aplicación
final appInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    // Configuración
    final configService = ref.read(configServiceProvider);
    await configService.initialize();

    // Solicitar permisos al inicio
    final permissionService = ref.read(permissionServiceProvider);
    print('Solicitando permisos iniciales...');

    // Solicitar permiso de micrófono específicamente
    final micStatus = await permissionService.requestMicrophonePermission();
    print('Estado del permiso de micrófono: $micStatus');

    if (!micStatus.isGranted) {
      print(
        'ADVERTENCIA: Permiso de micrófono no concedido. Estado: $micStatus',
      );
      if (micStatus.isPermanentlyDenied) {
        print(
          'El permiso de micrófono está permanentemente denegado. Se requiere acción del usuario en la configuración.',
        );
      }
    }

    // Solicitar otros permisos
    final permissions = await permissionService.requestAllPermissions();
    print('Permisos solicitados: $permissions');

    // Lista para llevar registro de servicios inicializados
    final List<String> initializedServices = [];
    final List<String> failedServices = [];

    // Inicializar servicios principales uno por uno con manejo de errores
    try {
      final audioService = ref.read(audioServiceProvider);
      await audioService.initialize();
      initializedServices.add('Audio');
    } catch (e) {
      print('Error al inicializar AudioService: $e');
      failedServices.add('Audio');
      // En modo seguro continuamos aunque falle este servicio
      if (!app_config.AppConfig.enableSafeMode) rethrow;
    }

    try {
      final backgroundService = ref.read(backgroundServiceProvider);
      await backgroundService.initialize();
      initializedServices.add('Background');
    } catch (e) {
      print('Error al inicializar BackgroundService: $e');
      failedServices.add('Background');
      // En modo seguro continuamos aunque falle este servicio
      if (!app_config.AppConfig.enableSafeMode) rethrow;
    }

    // Telegram puede fallar sin bloquear la aplicación
    try {
      final telegramService = ref.read(telegramServiceProvider);
      // Solo inicializar si hay un token válido
      if (configService.telegramBotToken.isNotEmpty) {
        telegramService.initialize(configService.telegramBotToken);

        // Verificar si el token es válido
        print('Verificando token de Telegram...');
        final isTokenValid = await telegramService.verifyToken();
        if (isTokenValid) {
          print('Token de Telegram verificado correctamente');
          initializedServices.add('Telegram');
        } else {
          print('ADVERTENCIA: El token de Telegram parece ser inválido');
          failedServices.add('Telegram (token inválido)');
        }
      } else {
        print('Token de Telegram vacío, no se inicializó el servicio');
        failedServices.add('Telegram (token vacío)');
      }
    } catch (e) {
      print('Error al inicializar TelegramService: $e');
      failedServices.add('Telegram');
      // No fallamos toda la app por esto
    }

    // Registrar servicios inicializados y fallidos
    print('Servicios inicializados: $initializedServices');
    if (failedServices.isNotEmpty) {
      print('ADVERTENCIA: Servicios no inicializados: $failedServices');
    }

    return true;
  } catch (e) {
    print('Error crítico al inicializar la aplicación: $e');
    return false;
  }
});

// Provider para el estado de los permisos
final permissionsProvider = FutureProvider<Map<String, bool>>((ref) async {
  final permissionService = ref.read(permissionServiceProvider);

  return {
    'location': await permissionService.isLocationPermissionGranted(),
    'backgroundLocation':
        await permissionService.isBackgroundLocationPermissionGranted(),
    'microphone': await permissionService.isMicrophonePermissionGranted(),
    'notification': await permissionService.isNotificationPermissionGranted(),
    'allGranted': await permissionService.areAllPermissionsGranted(),
  };
});

// Provider específico para el permiso de micrófono
final microphonePermissionProvider = FutureProvider<PermissionStatus>((
  ref,
) async {
  final permissionService = ref.read(permissionServiceProvider);
  return await Permission.microphone.status;
});

// Provider para solicitar explícitamente el permiso de micrófono
final requestMicrophonePermissionProvider =
    FutureProvider.autoDispose<PermissionStatus>((ref) async {
      final permissionService = ref.read(permissionServiceProvider);
      return await permissionService.requestMicrophonePermission();
    });

// Provider para la configuración
final appConfigProvider = StateNotifierProvider<AppConfigNotifier, AppConfig>((
  ref,
) {
  final configService = ref.read(configServiceProvider);
  return AppConfigNotifier(configService);
});

class AppConfigNotifier extends StateNotifier<AppConfig> {
  final ConfigService _configService;

  AppConfigNotifier(this._configService) : super(_configService.config);

  Future<void> updateToken(String token) async {
    await _configService.setTelegramBotToken(token);
    state = _configService.config;

    // Actualizar servicio de Telegram
    final telegramService = TelegramService();
    telegramService.initialize(token);

    // Verificar el token después de actualizarlo
    final isValid = await telegramService.verifyToken();
    if (!isValid) {
      print('ADVERTENCIA: El token actualizado parece no ser válido');
    }
  }

  Future<void> addEmergencyContact(EmergencyContact contact) async {
    // Validar que el chat ID tenga el formato correcto (numérico)
    if (contact.chatId.isEmpty) {
      print('ERROR: Chat ID vacío');
      return;
    }

    // Intentar convertir a número para validar
    try {
      int.parse(contact.chatId);
    } catch (e) {
      print('ERROR: El chat ID no es un número válido: ${contact.chatId}');
      return;
    }

    await _configService.addEmergencyContact(contact);
    state = _configService.config;
    print('Contacto añadido: ${contact.name} (${contact.chatId})');
  }

  Future<void> removeEmergencyContact(String chatId) async {
    await _configService.removeEmergencyContact(chatId);
    state = _configService.config;
  }

  Future<void> updateAlertSettings(AlertSettings settings) async {
    await _configService.updateAlertSettings(settings);
    state = _configService.config;
  }
}

// Provider para la ubicación actual
final currentLocationProvider = StreamProvider<Position?>((ref) {
  final locationService = ref.read(locationServiceProvider);
  return Stream.periodic(
    const Duration(seconds: 10),
  ).asyncMap((_) => locationService.getCurrentLocation());
});

// Provider para el estado de la alerta
final alertStatusProvider =
    StateNotifierProvider<AlertStatusNotifier, AlertStatus>((ref) {
      return AlertStatusNotifier(ref);
    });

class AlertStatus {
  final bool isActive;
  final String statusMessage;
  final DateTime? startTime;

  AlertStatus({
    required this.isActive,
    required this.statusMessage,
    this.startTime,
  });

  // Copiar con
  AlertStatus copyWith({
    bool? isActive,
    String? statusMessage,
    DateTime? startTime,
  }) {
    return AlertStatus(
      isActive: isActive ?? this.isActive,
      statusMessage: statusMessage ?? this.statusMessage,
      startTime: startTime ?? this.startTime,
    );
  }
}

class AlertStatusNotifier extends StateNotifier<AlertStatus> {
  final Ref _ref;

  AlertStatusNotifier(this._ref)
    : super(AlertStatus(isActive: false, statusMessage: 'Alerta inactiva'));

  Future<bool> startAlert() async {
    if (state.isActive) return false;

    try {
      // Verificar permiso de micrófono antes de iniciar alerta
      final permissionService = _ref.read(permissionServiceProvider);
      final micStatus = await permissionService.requestMicrophonePermission();

      if (!micStatus.isGranted) {
        state = state.copyWith(
          statusMessage: 'No se puede iniciar: permiso de micrófono denegado',
        );
        return false;
      }

      // Verificar permisos de ubicación
      final locationStatus =
          await permissionService.requestLocationPermission();

      if (!locationStatus.isGranted) {
        state = state.copyWith(
          statusMessage: 'No se puede iniciar: permiso de ubicación denegado',
        );
        return false;
      }

      // Para iOS, verificar específicamente la ubicación en segundo plano
      if (Platform.isIOS) {
        final backgroundLocationStatus =
            await permissionService.requestBackgroundLocationPermission();

        if (backgroundLocationStatus != LocationPermission.always) {
          print(
            'ADVERTENCIA: La ubicación en segundo plano no está configurada como "Siempre"',
          );
          // Continuamos pero advertimos al usuario
          state = state.copyWith(
            statusMessage: 'Advertencia: ubicación en segundo plano limitada',
          );
          // Pequeño retraso para que el usuario vea el mensaje
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Verificar que la ubicación actual se puede obtener
      final locationService = _ref.read(locationServiceProvider);
      final currentPosition = await locationService.getCurrentLocation();

      if (currentPosition == null) {
        print('ERROR: No se pudo obtener la ubicación actual');
        state = state.copyWith(
          statusMessage: 'No se puede iniciar: error al obtener ubicación',
        );

        // Intenta resolver el problema
        if (Platform.isIOS) {
          print('Intentando resolver problema de ubicación en iOS...');
          await Geolocator.openLocationSettings();
          state = state.copyWith(
            statusMessage: 'Verificando configuración de ubicación...',
          );
          await Future.delayed(const Duration(seconds: 2));

          // Reintentar obtener ubicación
          final retryPosition = await locationService.getCurrentLocation();
          if (retryPosition == null) {
            state = state.copyWith(
              statusMessage: 'No se pudo resolver el problema de ubicación',
            );
            return false;
          }
        } else {
          return false;
        }
      }

      // Verificar que hay contactos configurados
      final configService = _ref.read(configServiceProvider);
      if (configService.emergencyContacts.isEmpty) {
        print('ERROR: No hay contactos de emergencia configurados');
        state = state.copyWith(
          statusMessage: 'No se puede iniciar: no hay contactos configurados',
        );
        return false;
      }

      // Verificar que el token es válido
      final telegramService = _ref.read(telegramServiceProvider);
      telegramService.initialize(configService.telegramBotToken);
      final isTokenValid = await telegramService.verifyToken();
      if (!isTokenValid) {
        print('ERROR: El token de Telegram no es válido');
        state = state.copyWith(
          statusMessage: 'No se puede iniciar: token de Telegram inválido',
        );
        return false;
      }

      final backgroundService = _ref.read(backgroundServiceProvider);

      final success = await backgroundService.startAlert(
        configService.telegramBotToken,
        configService.emergencyContacts,
        configService.alertSettings,
      );

      if (success) {
        state = state.copyWith(
          isActive: true,
          statusMessage: 'Alerta activada',
          startTime: DateTime.now(),
        );
      } else {
        // Si no se pudo iniciar, actualizar el mensaje
        state = state.copyWith(
          statusMessage: 'Error al iniciar la alerta. Intente nuevamente.',
        );
      }

      return success;
    } catch (e) {
      state = state.copyWith(statusMessage: 'Error al iniciar alerta: $e');
      return false;
    }
  }

  Future<bool> stopAlert() async {
    if (!state.isActive) return false;

    try {
      final backgroundService = _ref.read(backgroundServiceProvider);
      final success = await backgroundService.stopAlert();

      if (success) {
        state = state.copyWith(
          isActive: false,
          statusMessage: 'Alerta desactivada',
        );
      }

      return success;
    } catch (e) {
      state = state.copyWith(statusMessage: 'Error al detener alerta: $e');
      return false;
    }
  }

  void updateStatus(String message) {
    state = state.copyWith(statusMessage: message);
  }
}
