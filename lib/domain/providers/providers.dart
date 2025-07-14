import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/services.dart';

import '../../config.dart' as app_config;
import '../../core/services/audio_service.dart';
import '../../core/services/background_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/iap_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/police_station_service.dart';
import '../../core/services/telegram_service.dart';
import '../../core/services/whatsapp_centralized_service.dart';
import '../../data/models/app_config.dart';
import '../../data/models/emergency_contact.dart';
import '../../data/models/police_station.dart';
import '../../data/models/purchase_state.dart';

// Providers de Servicios
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(),
);
final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final cameraServiceProvider = Provider<CameraService>((ref) => CameraService());
final telegramServiceProvider = Provider<TelegramService>(
  (ref) => TelegramService(),
);
final backgroundServiceProvider = Provider<BackgroundAlertService>(
  (ref) => BackgroundAlertService(),
);
final iapServiceProvider = Provider<IAPService>((ref) => IAPService.instance);
final policeStationServiceProvider = Provider<PoliceStationService>(
  (ref) => PoliceStationService(),
);
final whatsappCentralizedServiceProvider = Provider<WhatsAppCentralizedService>(
  (ref) => WhatsAppCentralizedService(),
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
      final cameraService = ref.read(cameraServiceProvider);
      await cameraService.initialize();
      initializedServices.add('Camera');
    } catch (e) {
      print('Error al inicializar CameraService: $e');
      failedServices.add('Camera');
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

    // Inicializar servicio de IAP
    try {
      final iapService = ref.read(iapServiceProvider);
      final iapInitialized = await iapService.initialize();

      if (iapInitialized) {
        initializedServices.add('IAP');
        print('✅ Servicio IAP inicializado correctamente');
      } else {
        failedServices.add('IAP (tienda no disponible)');
        print('⚠️ Servicio IAP no disponible en este dispositivo');
      }
    } catch (e) {
      print('Error al inicializar IAP Service: $e');
      failedServices.add('IAP');
      // No fallamos toda la app por esto
    }

    // Inicializar servicio de comisarías de policía (precargar datos)
    try {
      final policeStationService = ref.read(policeStationServiceProvider);
      // Precargar datos en background sin bloquear la inicialización
      policeStationService
          .preloadMajorCities()
          .then((_) {
            print('✅ Datos de comisarías precargados');
          })
          .catchError((e) {
            print('⚠️ Error precargando datos de comisarías: $e');
          });
      initializedServices.add('PoliceStations');
    } catch (e) {
      print('Error al inicializar Police Station Service: $e');
      failedServices.add('PoliceStations');
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
    'camera': await permissionService.isCameraPermissionGranted(),
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

        // MEJORA CRÍTICA: temporizador de seguridad para iOS
        // Si estamos en iOS, añadimos un temporizador para verificar si la alerta sigue activa
        // después de un tiempo y forzar una segunda detención si es necesario
        if (Platform.isIOS) {
          Timer(const Duration(seconds: 5), () {
            // Verificar nuevamente con el servicio si la alerta sigue activa
            final isStillActive = backgroundService.isAlertActive;
            if (isStillActive) {
              print(
                '⚠️ Alerta todavía activa después de 5 segundos, forzando una segunda detención',
              );
              // Intentar detener nuevamente y actualizar el estado
              backgroundService.stopAlert().then((secondSuccess) {
                if (secondSuccess) {
                  print('✅ Segunda detención exitosa');
                  state = state.copyWith(
                    isActive: false,
                    statusMessage: 'Alerta desactivada (segunda verificación)',
                  );
                }
              });
            } else {
              print(
                '✅ Alerta correctamente desactivada, verificación de seguridad',
              );
            }
          });
        }
      }

      return success;
    } catch (e) {
      state = state.copyWith(statusMessage: 'Error al detener alerta: $e');
      return false;
    }
  }

  // Método para forzar la detención de la alerta
  // Esto es útil cuando los métodos normales de detención fallan
  Future<void> forceStopAlert() async {
    print('Forzando detención de alerta desde UI');

    try {
      // Marcar como inactiva en el estado inmediatamente
      state = state.copyWith(
        isActive: false,
        statusMessage: 'Alerta forzada a detenerse',
      );

      // Obtener servicio de fondo
      final backgroundService = _ref.read(backgroundServiceProvider);

      // Primer intento: llamada normal a stopAlert
      print('Primer intento de detención forzada - método normal');
      await backgroundService.stopAlert();

      // Segundo intento: múltiples llamadas a stopAlert
      print('Segundo intento - múltiples llamadas a stopAlert');
      try {
        await backgroundService.stopAlert();
        print('Segunda llamada a stopAlert completada');

        await Future.delayed(Duration(milliseconds: 500));
        await backgroundService.stopAlert();
        print('Tercera llamada a stopAlert completada');
      } catch (e) {
        print('Error en llamadas múltiples: $e');
      }

      // Específico para iOS: intentar obtener y liberar recursos
      if (Platform.isIOS) {
        print('iOS: Forzando limpieza adicional de recursos');
        try {
          // Notificar al sistema para liberar recursos
          final audioService = AudioService();
          await audioService.dispose();
          print('Recursos de audio liberados forzosamente');

          // Intento adicional de cancelar tareas BGTaskScheduler
          try {
            final methodChannel = MethodChannel(
              'com.alerta.telegram/background_tasks',
            );
            await methodChannel.invokeMethod('cancelBackgroundTasks');
            print(
              'iOS: Tareas BGTaskScheduler canceladas forzosamente desde forceStopAlert',
            );
          } catch (methodError) {
            print('Error al cancelar tareas BGTaskScheduler: $methodError');
          }
        } catch (e) {
          print('Error al liberar recursos de audio: $e');
        }
      }

      print('Alerta marcada como inactiva forzosamente');

      // Actualizar estado una vez más para confirmar
      await Future.delayed(Duration(seconds: 1));
      state = state.copyWith(
        isActive: false,
        statusMessage: 'Alerta detenida forzosamente',
      );
    } catch (e) {
      print('Error al forzar detención: $e');
      state = state.copyWith(statusMessage: 'Error al forzar detención: $e');
    }
  }

  void updateStatus(String message) {
    state = state.copyWith(statusMessage: message);
  }
}

// ====== PROVIDERS DE IN-APP PURCHASES ======

/// Provider para inicializar el servicio de IAP
final iapInitializationProvider = FutureProvider<bool>((ref) async {
  final iapService = ref.read(iapServiceProvider);
  return await iapService.initialize();
});

/// Provider para obtener el estado de la suscripción premium
final premiumSubscriptionProvider = StreamProvider<PremiumSubscription>((ref) {
  final iapService = ref.read(iapServiceProvider);
  return iapService.subscriptionStream;
});

/// Provider para obtener productos disponibles
final availableProductsProvider = FutureProvider<List<IAPProduct>>((ref) async {
  final iapService = ref.read(iapServiceProvider);

  // Asegurar que el servicio esté inicializado
  await ref.read(iapInitializationProvider.future);

  return iapService.availableProducts;
});

/// Provider para obtener el producto mensual
final monthlyProductProvider = FutureProvider<IAPProduct?>((ref) async {
  final iapService = ref.read(iapServiceProvider);

  // Asegurar que el servicio esté inicializado
  await ref.read(iapInitializationProvider.future);

  return iapService.monthlyProduct;
});

/// Provider para obtener el producto anual
final yearlyProductProvider = FutureProvider<IAPProduct?>((ref) async {
  final iapService = ref.read(iapServiceProvider);

  // Asegurar que el servicio esté inicializado
  await ref.read(iapInitializationProvider.future);

  return iapService.yearlyProduct;
});

/// Provider para verificar si el usuario tiene premium
final hasPremiumProvider = Provider<bool>((ref) {
  final subscriptionAsync = ref.watch(premiumSubscriptionProvider);

  return subscriptionAsync.when(
    data: (subscription) => subscription.isValid,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider para obtener días restantes de suscripción
final premiumDaysRemainingProvider = Provider<int>((ref) {
  final subscriptionAsync = ref.watch(premiumSubscriptionProvider);

  return subscriptionAsync.when(
    data: (subscription) => subscription.daysRemaining,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider para manejar compras
final purchaseProvider = StateNotifierProvider<PurchaseNotifier, PurchaseState>(
  (ref) {
    final iapService = ref.read(iapServiceProvider);
    return PurchaseNotifier(iapService);
  },
);

/// Notifier para manejar las compras
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final IAPService _iapService;

  PurchaseNotifier(this._iapService) : super(PurchaseState.none);

  /// Iniciar prueba gratuita de 7 días
  Future<bool> startTrial() async {
    state = PurchaseState.pending;

    try {
      final success = await _iapService.purchaseProduct('7_day_trial');

      if (!success) {
        state = PurchaseState.error;
        return false;
      }

      // El estado se actualizará automáticamente a través del stream
      return true;
    } catch (e) {
      state = PurchaseState.error;
      return false;
    }
  }

  /// Comprar producto mensual
  Future<bool> purchaseMonthly() async {
    state = PurchaseState.pending;

    try {
      final success = await _iapService.purchaseProduct('premium_monthly');

      if (!success) {
        state = PurchaseState.error;
        return false;
      }

      // El estado se actualizará automáticamente a través del stream
      return true;
    } catch (e) {
      state = PurchaseState.error;
      return false;
    }
  }

  /// Comprar producto anual
  Future<bool> purchaseYearly() async {
    state = PurchaseState.pending;

    try {
      final success = await _iapService.purchaseProduct('premium_yearly');

      if (!success) {
        state = PurchaseState.error;
        return false;
      }

      // El estado se actualizará automáticamente a través del stream
      return true;
    } catch (e) {
      state = PurchaseState.error;
      return false;
    }
  }

  /// Restaurar compras
  Future<bool> restorePurchases() async {
    state = PurchaseState.pending;

    try {
      final success = await _iapService.restorePurchases();

      if (!success) {
        state = PurchaseState.error;
        return false;
      }

      // El estado se actualizará automáticamente a través del stream
      return true;
    } catch (e) {
      state = PurchaseState.error;
      return false;
    }
  }

  /// Resetear estado
  void resetState() {
    state = PurchaseState.none;
  }
}

/// Provider para verificar si el usuario puede usar la prueba gratuita
final canUseTrialProvider = FutureProvider<bool>((ref) async {
  final iapService = ref.read(iapServiceProvider);
  final hasUsedTrial = await iapService.hasUsedTrial();
  final isCurrentlyInTrial = iapService.isInTrial;

  // Puede usar trial si no la ha usado y no está actualmente en una
  return !hasUsedTrial && !isCurrentlyInTrial;
});

/// Provider para obtener el producto de prueba gratuita
final trialProductProvider = FutureProvider<IAPProduct?>((ref) async {
  final iapService = ref.read(iapServiceProvider);

  // Asegurar que el servicio esté inicializado
  await ref.read(iapInitializationProvider.future);

  return iapService.trialProduct;
});

/// Provider para verificar si el onboarding ya se completó
final isOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  } catch (e) {
    print('Error verificando onboarding completado: $e');
    return false; // En caso de error, mostrar onboarding
  }
});

/// Provider para marcar el onboarding como completado
final onboardingNotifierProvider = Provider<OnboardingNotifier>((ref) {
  return OnboardingNotifier();
});

class OnboardingNotifier {
  /// Marcar onboarding como completado
  Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      print('Onboarding marcado como completado');
    } catch (e) {
      print('Error al marcar onboarding como completado: $e');
    }
  }

  /// Resetear onboarding (para testing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
      print('Onboarding reseteado');
    } catch (e) {
      print('Error al resetear onboarding: $e');
    }
  }
}

/// Provider para verificar si el usuario está en período de prueba
final isInTrialProvider = Provider<bool>((ref) {
  final subscriptionAsync = ref.watch(premiumSubscriptionProvider);

  return subscriptionAsync.when(
    data:
        (subscription) =>
            subscription.isValid &&
            subscription.productType == ProductType.trial,
    loading: () => false,
    error: (_, __) => false,
  );
});

// =============================================================================
// PROVIDERS DE COMISARÍAS DE POLICÍA
// =============================================================================

/// Provider para buscar comisarías de policía cercanas
final nearbyPoliceStationsProvider =
    FutureProvider.family<List<PoliceStation>, Map<String, dynamic>>((
      ref,
      params,
    ) async {
      final policeStationService = ref.read(policeStationServiceProvider);
      final latitude = params['latitude'] as double;
      final longitude = params['longitude'] as double;
      final radiusMeters = params['radiusMeters'] as int? ?? 5000;
      final filterTypes = params['filterTypes'] as List<PoliceType>?;
      final forceRefresh = params['forceRefresh'] as bool? ?? false;

      return await policeStationService.findNearbyPoliceStations(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        filterTypes: filterTypes,
        forceRefresh: forceRefresh,
      );
    });

/// Provider para obtener una comisaría específica por ID
final policeStationByIdProvider = FutureProvider.family<PoliceStation?, String>(
  (ref, id) async {
    final policeStationService = ref.read(policeStationServiceProvider);
    return await policeStationService.getPoliceStationById(id);
  },
);

/// Provider para obtener estadísticas del cache
final policeStationCacheStatsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final policeStationService = ref.read(policeStationServiceProvider);
  return await policeStationService.getCacheStats();
});

/// StateNotifier para manejar el estado de búsqueda de comisarías
class PoliceStationSearchNotifier
    extends StateNotifier<PoliceStationSearchState> {
  final PoliceStationService _policeStationService;

  PoliceStationSearchNotifier(this._policeStationService)
    : super(PoliceStationSearchState.initial());

  /// Buscar comisarías cercanas
  Future<void> searchNearbyStations({
    required double latitude,
    required double longitude,
    int radiusMeters = 5000,
    List<PoliceType>? filterTypes,
    bool forceRefresh = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final stations = await _policeStationService.findNearbyPoliceStations(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        filterTypes: filterTypes,
        forceRefresh: forceRefresh,
      );

      state = state.copyWith(
        stations: stations,
        isLoading: false,
        error: null,
        lastSearchLatitude: latitude,
        lastSearchLongitude: longitude,
        lastSearchRadius: radiusMeters,
        lastSearchTypes: filterTypes,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Actualizar filtros
  void updateFilters(List<PoliceType>? filterTypes) {
    final currentStations = state.stations;
    if (currentStations.isEmpty) return;

    List<PoliceStation> filteredStations = currentStations;

    if (filterTypes != null && filterTypes.isNotEmpty) {
      filteredStations =
          currentStations
              .where((station) => filterTypes.contains(station.type))
              .toList();
    }

    state = state.copyWith(
      stations: filteredStations,
      lastSearchTypes: filterTypes,
    );
  }

  /// Limpiar búsqueda
  void clearSearch() {
    state = PoliceStationSearchState.initial();
  }

  /// Forzar actualización
  Future<void> forceRefresh() async {
    if (state.lastSearchLatitude != null && state.lastSearchLongitude != null) {
      await searchNearbyStations(
        latitude: state.lastSearchLatitude!,
        longitude: state.lastSearchLongitude!,
        radiusMeters: state.lastSearchRadius,
        filterTypes: state.lastSearchTypes,
        forceRefresh: true,
      );
    }
  }
}

/// Provider para el notifier de búsqueda de comisarías
final policeStationSearchProvider = StateNotifierProvider<
  PoliceStationSearchNotifier,
  PoliceStationSearchState
>((ref) {
  final policeStationService = ref.read(policeStationServiceProvider);
  return PoliceStationSearchNotifier(policeStationService);
});

/// Estado de búsqueda de comisarías
class PoliceStationSearchState {
  final List<PoliceStation> stations;
  final bool isLoading;
  final String? error;
  final double? lastSearchLatitude;
  final double? lastSearchLongitude;
  final int lastSearchRadius;
  final List<PoliceType>? lastSearchTypes;

  const PoliceStationSearchState({
    required this.stations,
    required this.isLoading,
    this.error,
    this.lastSearchLatitude,
    this.lastSearchLongitude,
    this.lastSearchRadius = 5000,
    this.lastSearchTypes,
  });

  factory PoliceStationSearchState.initial() {
    return const PoliceStationSearchState(stations: [], isLoading: false);
  }

  PoliceStationSearchState copyWith({
    List<PoliceStation>? stations,
    bool? isLoading,
    String? error,
    double? lastSearchLatitude,
    double? lastSearchLongitude,
    int? lastSearchRadius,
    List<PoliceType>? lastSearchTypes,
  }) {
    return PoliceStationSearchState(
      stations: stations ?? this.stations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastSearchLatitude: lastSearchLatitude ?? this.lastSearchLatitude,
      lastSearchLongitude: lastSearchLongitude ?? this.lastSearchLongitude,
      lastSearchRadius: lastSearchRadius ?? this.lastSearchRadius,
      lastSearchTypes: lastSearchTypes ?? this.lastSearchTypes,
    );
  }
}

/// Provider para verificar si las comisarías están disponibles (función premium)
final policeStationsAvailableProvider = Provider<bool>((ref) {
  final hasPremium = ref.watch(hasPremiumProvider);
  final isInTrial = ref.watch(isInTrialProvider);

  return hasPremium || isInTrial;
});

/// Provider para precargar datos de ciudades principales
final preloadPoliceStationsProvider = FutureProvider<void>((ref) async {
  final policeStationService = ref.read(policeStationServiceProvider);
  await policeStationService.preloadMajorCities();
});
