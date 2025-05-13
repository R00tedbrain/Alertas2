import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_constants.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../services/telegram_service.dart';
import '../services/config_service.dart';
import '../../data/models/app_config.dart';
import '../../data/models/emergency_contact.dart';

// Método para imprimir logs solo en modo debug - accesible en todo el archivo
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

// Método auxiliar para completar tareas BGTask
Future<void> _completeBGTask(MethodChannel channel) async {
  _log('▶️ Finalizando tarea en segundo plano');
  try {
    // Usar siempre el mismo nombre de método para la comunicación con iOS
    await channel.invokeMethod('completeBackgroundTask');
  } catch (e) {
    _log('⚠️ No se pudo notificar finalización: $e');
  }
}

// Anotación crucial para que la clase sea accesible desde código nativo
@pragma('vm:entry-point')
class BackgroundAlertService {
  // Servicios
  final LocationService _locationService = LocationService();
  final AudioService _audioService = AudioService();
  final TelegramService _telegramService = TelegramService();

  // Estado
  bool _isAlertActive = false;

  // Getter público para _isAlertActive
  bool get isAlertActive => _isAlertActive;

  // Servicio en segundo plano
  late FlutterBackgroundService _backgroundService;

  // Canal de método para comunicación nativa
  late MethodChannel _backgroundChannel;

  // Logger
  final _logger = Logger();

  // Notificaciones
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Lista centralizada de timers para facilitar la limpieza
  static final List<Timer> _timers = [];

  // Variables para mantener los suscriptores activos y facilitar su limpieza
  final List<StreamSubscription> _activeSubscriptions = [];

  // Stream para recibir actualizaciones de estado del servicio
  Stream<Map<String, dynamic>?> get onServiceUpdate =>
      _backgroundService.on('updateStatus');

  // Singleton
  static final BackgroundAlertService _instance =
      BackgroundAlertService._internal();

  factory BackgroundAlertService() => _instance;

  BackgroundAlertService._internal();

  // Inicializar
  Future<void> initialize() async {
    await _initializeNotifications();
    _backgroundService = FlutterBackgroundService();

    // Configurar el canal para comunicación nativa
    _setupBackgroundTasksChannel();

    // Inicializar el servicio en segundo plano
    await _initializeBackgroundService();
  }

  // Configurar notificaciones
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  // Configurar servicio en segundo plano
  Future<void> _initializeBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConstants.emergencyChannelId,
        initialNotificationTitle: AppConstants.appName,
        initialNotificationContent: 'Preparando servicio de alerta',
        foregroundServiceNotificationId: AppConstants.emergencyNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    // PASO 1: Iniciar el servicio después de configurarlo
    _log('Iniciando servicio en segundo plano');
    await _backgroundService.startService();

    // Registrar las identificaciones de tarea en iOS
    if (Platform.isIOS) {
      await _registerBackgroundTasks();

      // PASO 2: Programar las tareas BGTask para iOS
      _log('Programando tareas BGTask para iOS');
      try {
        // Primero inicializar ConfigService para obtener configuración
        final configService = ConfigService();
        await configService.initialize();
        final alertSettings = configService.alertSettings;

        // Usar el canal para programar tareas
        await _scheduleBGTasksManually();

        _log('Tareas programadas manualmente desde Flutter');
      } catch (e) {
        _log('Error al programar tareas BGTask: $e');
      }
    }
  }

  // Método para programar tareas BGTask manualmente a través del MethodChannel
  Future<void> _scheduleBGTasksManually() async {
    try {
      // Llamar a los métodos nativos correspondientes
      await _backgroundChannel.invokeMethod('scheduleTasks', {
        'refresh': {
          'id': 'com.alerta.telegram.refresh',
          'delay': 60, // segundos
        },
        'processing': {
          'id': 'com.alerta.telegram.processing',
          'delay': 15 * 60, // 15 minutos en segundos
        },
        'audio': {
          'id': 'com.alerta.telegram.audio',
          'delay': 60, // segundos
        },
      });

      _log('✅ Tareas en segundo plano programadas correctamente desde Flutter');
    } catch (e) {
      _log('❌ Error al programar tareas BGTask manualmente: $e');
    }
  }

  // Añadir una nueva función para registrar las tareas de fondo en iOS
  Future<bool> _registerBackgroundTasks() async {
    _log('🐛 Registrando tareas en segundo plano para iOS');

    if (Platform.isIOS) {
      try {
        // Para iOS, manejar el registro a través del canal nativo
        _log('🐛 Invocando registerBackgroundTasks en canal nativo');
        final result = await _backgroundChannel.invokeMethod(
          'registerBackgroundTasks',
          {
            'identifiers': [
              'com.alerta.telegram.refresh',
              'com.alerta.telegram.processing',
              'com.alerta.telegram.audio',
            ],
          },
        );
        _log('💡 Tareas en segundo plano registradas con resultado: $result');

        // Configurar manejo adicional de tareas
        _log('🐛 Configurando tareas en segundo plano adicionales');
        final additionalResult = await _backgroundChannel.invokeMethod(
          'setupBackgroundTasks',
        );
        _log('💡 Configuración adicional completada: $additionalResult');

        return result == true;
      } catch (e) {
        _log('Error al registrar tareas en segundo plano para iOS: $e');
        return false;
      }
    }

    // En Android, usar el enfoque nativo de flutter_background_service
    return true;
  }

  // Configurar el canal de comunicación para tareas en segundo plano
  void _setupBackgroundTasksChannel() {
    _backgroundChannel = const MethodChannel(
      'com.alerta.telegram/background_tasks',
    );

    // Configurar manejadores para métodos invocados desde nativo
    _backgroundChannel.setMethodCallHandler((call) async {
      _log('Método invocado desde nativo: ${call.method}');

      switch (call.method) {
        case 'updateStatus':
          // Actualizar el estado del servicio
          final Map<String, dynamic> args = call.arguments;
          final String status = args['status'];
          final bool isActive = args['isActive'];
          final int timestamp = args['timestamp'];

          _log(
            'Estado actualizado: $status, Activo: $isActive, Timestamp: $timestamp',
          );
          return true;

        case 'startBackgroundFetch':
          // Manejar la solicitud de ejecución en segundo plano desde iOS
          _log('⚠️ Recibido startBackgroundFetch desde iOS');
          final Map<String, dynamic> args = call.arguments;
          final String taskId = args['taskId'];

          _log('⚠️ Tarea en segundo plano solicitada: $taskId');

          try {
            // Cargar configuración
            final configService = await _getConfigService();
            if (configService == null) {
              _log('❌ ERROR: No se pudo obtener ConfigService');
              return false;
            }

            final token = configService.telegramBotToken;
            final contacts = configService.emergencyContacts;

            if (token.isEmpty || contacts.isEmpty) {
              _log(
                '❌ ERROR: Configuración incompleta para la alerta en segundo plano',
              );
              return false;
            }

            // Inicializar servicio de Telegram
            final telegramService = TelegramService();
            telegramService.initialize(token);

            // Obtener ubicación
            final locationService = LocationService();
            _log('⏳ Obteniendo ubicación para envío en segundo plano...');
            final position = await locationService.getCurrentLocation();

            if (position == null) {
              _log('❌ ERROR: No se pudo obtener ubicación');

              // Intentar enviar mensaje sin ubicación
              _log(
                '⏳ INICIANDO ENVÍO DE MENSAJE SIN UBICACIÓN a Telegram (BGTask)',
              );
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  '🚨 ALERTA AUTOMÁTICA: Actualización periódica (sin ubicación disponible)',
                  markdown: false,
                );
                _log(
                  '✅ Mensaje enviado exitosamente desde tarea en segundo plano (sin ubicación)',
                );
                return true;
              } catch (e) {
                _log('❌ ERROR al enviar mensaje desde BGTask: $e');
                return false;
              }
            } else {
              // Enviar mensaje con ubicación
              _log(
                '⏳ INICIANDO ENVÍO DE MENSAJE CON UBICACIÓN a Telegram (BGTask)',
              );
              try {
                // Primero enviar mensaje
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  '🚨 ALERTA AUTOMÁTICA: Ubicación actualizada',
                  markdown: false,
                );
                _log('✅ Mensaje enviado exitosamente desde BGTask');

                // Luego intentar enviar ubicación
                await telegramService.sendLocationToAllContacts(
                  contacts,
                  position,
                );
                _log('✅ Ubicación enviada exitosamente desde BGTask');
                return true;
              } catch (e) {
                _log('❌ ERROR al enviar actualizaciones desde BGTask: $e');

                // Intentar con formato alternativo
                try {
                  final locationText =
                      'Lat: ${position.latitude}, Lng: ${position.longitude}';
                  final mapsLink =
                      'https://maps.google.com/maps?q=${position.latitude},${position.longitude}';

                  await telegramService.sendMessageToAllContacts(
                    contacts,
                    '🚨 ALERTA: Mi ubicación actual: $locationText\n\nVer en mapa: $mapsLink',
                    markdown: false,
                  );
                  _log(
                    '✅ Texto de ubicación enviado como alternativa desde BGTask',
                  );
                  return true;
                } catch (retryError) {
                  _log('❌ ERROR en segundo intento desde BGTask: $retryError');
                  return false;
                }
              }
            }
          } catch (e) {
            _log('❌ ERROR CRÍTICO en BGTask: $e');
            return false;
          }

        default:
          throw PlatformException(
            code: 'Unimplemented',
            message: 'Método no implementado: ${call.method}',
          );
      }
    });
  }

  // Método auxiliar para obtener ConfigService inicializado
  Future<ConfigService?> _getConfigService() async {
    try {
      final configService = ConfigService();
      await configService.initialize();
      return configService;
    } catch (e) {
      _log('Error al inicializar ConfigService: $e');
      return null;
    }
  }

  // Manejador iOS para segundo plano
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    _log('iOS background handler iniciado');

    // Configuración más eficiente para evitar BGTaskSchedulerErrorDomain
    try {
      if (Platform.isIOS) {
        _log('Inicializando manejo de segundo plano iOS mejorado');

        // Notificar inmediatamente que la tarea se ha completado
        try {
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );

          // Notificar que hemos completado la tarea BGTask
          await channel.invokeMethod('completeBackgroundTask', {
            'taskIdentifier': 'com.alerta.telegram.processing',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          _log('Tarea en segundo plano completada correctamente');
        } catch (e) {
          _log('Error al comunicar finalización de tarea: $e');
        }

        // Solo un timer para enviar una señal final de vida antes de salir
        Timer(const Duration(seconds: 2), () {
          try {
            service.invoke('heartbeat', {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'status': 'backgroundFetch_completed',
            });
            _log('Señal final de heartbeat enviada');
          } catch (e) {
            _log('Error en señal final: $e');
          }
        });
      }
    } catch (e) {
      _log('Error al configurar servicio iOS: $e');
    }

    return true;
  }

  // Manejador principal del servicio en segundo plano
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    _log('Servicio en segundo plano iniciado');

    // Servicio para Android
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setAutoStartOnBootMode(true);
      _log('Configurado como servicio en primer plano (Android)');
    }

    // Para iOS, enviar una señal inicial de que el servicio está activo
    if (Platform.isIOS) {
      service.invoke('updateStatus', {
        'status': 'Servicio iniciado en iOS',
        'isActive': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // Responder a los heartbeats (principalmente para iOS)
    service.on('heartbeat').listen((event) {
      _log('Heartbeat recibido: $event');
      // Responder con un estado actualizado
      service.invoke('updateStatus', {
        'status': 'Servicio activo',
        'isActive': true,
        'heartbeatResponse': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // ÚNICO EVENTO DE DETENCIÓN: detendrá todo el servicio al recibir 'stop'
    service.on('stop').listen((event) async {
      _log('Evento STOP recibido, deteniendo todo el servicio');
      try {
        // 1. Cancelar todos los timers activos
        _cancelAllTimers();
        _log('Todos los timers cancelados');

        // 2. Para iOS, liberar recursos de audio
        if (Platform.isIOS) {
          try {
            final audioService = AudioService();
            _log('Liberando recursos de audio en iOS desde el evento stop');
            audioService.dispose();
            _log('Recursos de audio liberados correctamente');
          } catch (e) {
            _log('Error al liberar recursos de audio: $e');
          }
        }

        // 3. Notificar al UI que el servicio se está deteniendo
        service.invoke('updateStatus', {
          'status': 'Servicio detenido',
          'isActive': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // 4. Detener el servicio completamente
        _log('⚠️ Llamando a stopSelf() para detener el isolate');
        await service.stopSelf();
      } catch (e) {
        _log('Error al detener el servicio: $e');

        // Si hay un error, intentar forzar la detención de todos modos
        try {
          await service.stopSelf();
        } catch (e2) {
          _log('Error secundario al intentar stopSelf: $e2');
        }
      }
    });

    // Responder a los comandos para iniciar alerta
    service.on('startAlert').listen((event) async {
      _log('Recibida petición para iniciar alerta con datos: $event');
      if (event == null) {
        _log('ERROR: Evento startAlert recibido con datos nulos');
        return;
      }

      String? token = event['token'] as String?;
      if (token == null || token.isEmpty) {
        _log('ERROR: Token nulo o vacío');
        return;
      }

      List<dynamic>? contactsRaw = event['contacts'] as List<dynamic>?;
      if (contactsRaw == null || contactsRaw.isEmpty) {
        _log('ERROR: Lista de contactos nula o vacía');
        return;
      }

      try {
        await _startAlert(
          service,
          token,
          contactsRaw
              .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList(),
          AlertSettings.fromJson(
            event['settings'] as Map<String, dynamic>? ?? {},
          ),
        );
      } catch (e) {
        _log('ERROR en _startAlert: $e');
      }
    });

    // Responder a los comandos para detener alerta
    service.on('stopAlert').listen((event) async {
      _log('Recibida petición para detener alerta via stopAlert');
      try {
        // 1. Cancelar todos los timers activos
        _cancelAllTimers();
        _log('Todos los timers cancelados');

        // 2. Para iOS, liberar recursos de audio
        if (Platform.isIOS) {
          try {
            final audioService = AudioService();
            _log(
              'Liberando recursos de audio en iOS desde el evento stopAlert',
            );

            // Verificar si se solicitó detención forzada
            bool forceStop = false;
            if (event != null && event is Map<String, dynamic>) {
              forceStop = event['force_stop_audio'] == true;
            }

            if (forceStop) {
              _log('Solicitada detención forzada del audio');

              // Llamada directa al código nativo para forzar detención
              try {
                const MethodChannel channel = MethodChannel(
                  'com.alerta.telegram/background_tasks',
                );
                await channel.invokeMethod('forceStopAudio');
                _log('Detención forzada del audio completada desde servicio');
              } catch (e) {
                _log('Error en detención forzada desde servicio: $e');
                // Continuar con dispose normal
              }
            }

            audioService.dispose();
            _log('Recursos de audio liberados correctamente');
          } catch (e) {
            _log('Error al liberar recursos de audio: $e');
          }
        }

        // 3. Notificar al UI que la alerta se está deteniendo, pero el servicio continúa
        service.invoke('updateStatus', {
          'status': 'Alerta detenida (servicio sigue activo)',
          'isActive': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _log('Alerta detenida pero servicio mantenido activo');
      } catch (e) {
        _log('Error al detener la alerta: $e');

        // Notificar error
        service.invoke('updateStatus', {
          'status': 'Error al detener alerta: ' + e.toString(),
          'isActive': false,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });

    service.on('stopService').listen((event) {
      _log(
        'Recibida petición para detener alerta via stopService - redirigiendo a stop',
      );
      service.invoke('stop', {});
    });
  }

  // Función mejorada para cancelar todos los timers
  static void _cancelAllTimers() {
    _log('Cancelando todos los timers...');
    while (_timers.isNotEmpty) {
      _timers.removeLast().cancel();
    }
    _timers.clear();
    _log('Todos los timers han sido cancelados');
  }

  // Método para configurar servicios en segundo plano específicos para iOS
  @pragma('vm:entry-point')
  static Future<void> _setupBackgroundServices(
    ServiceInstance service,
    AlertSettings settings,
    LocationService locationService,
  ) async {
    // Manejo específico para iOS y errores BGTaskSchedulerErrorDomain
    if (Platform.isIOS) {
      _log('Configurando tareas en segundo plano para iOS...');
      try {
        // En iOS, debemos asegurarnos que los permisos estén correctamente configurados
        // para evitar errores BGTaskSchedulerErrorDomain
        _log('Verificando permisos para tareas en segundo plano en iOS');

        // Configurar background tasks manualmente para iOS
        const MethodChannel taskChannel = MethodChannel(
          'com.alerta.telegram/background_tasks',
        );
        final Map<String, dynamic> taskInfo = {
          'refresh': 'com.alerta.telegram.refresh',
          'processing': 'com.alerta.telegram.processing',
        };

        // Registrar e iniciar tareas
        final result = await taskChannel.invokeMethod(
          'setupBackgroundTasks',
          taskInfo,
        );
        _log('Tareas en segundo plano registradas correctamente: $result');

        // Verificar y solicitar permisos de ubicación
        final permission = await Geolocator.checkPermission();
        _log('Estado actual del permiso de ubicación: $permission');

        if (permission != LocationPermission.always) {
          _log('ADVERTENCIA: La ubicación en segundo plano no está habilitada');
          _log('Algunas funciones podrían no funcionar correctamente');

          // Intentar solicitar permisos si es posible
          if (permission == LocationPermission.whileInUse) {
            _log('Intentando solicitar permiso de ubicación always...');
            final newPermission = await Geolocator.requestPermission();
            _log('Nuevo estado de permiso: $newPermission');
          }
        }

        // Para iOS, aumentar intervalo entre grabaciones para permitir
        // que la app tenga más tiempo entre tareas
        if (settings.audioRecordingIntervalSeconds < 60) {
          _log('Ajustando intervalo de grabación para iOS');
          settings = settings.copyWith(
            audioRecordingIntervalSeconds: math.max(
              settings.audioRecordingIntervalSeconds,
              60,
            ),
          );
          _log(
            'Nuevo intervalo de grabación: ${settings.audioRecordingIntervalSeconds}s',
          );
        }

        // Para iOS, configurar temporizadores de keepAlive más frecuentes
        _log('Configurando servicio para mantenerlo activo en iOS');
        _timers.add(
          Timer.periodic(const Duration(minutes: 1), (timer) {
            _log('KeepAlive timer principal para iOS: ${DateTime.now()}');

            // Mantener la tarea activa
            try {
              // Usar directamente service.invoke sin comprobar tipo
              service.invoke('keepAlive', {
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
              _log('KeepAlive invocado para iOS');
            } catch (e) {
              _log('Error en KeepAlive: $e');
            }
          }),
        );

        // Temporizador dedicado a mantener activos los permisos de ubicación
        _timers.add(
          Timer.periodic(const Duration(minutes: 2), (timer) async {
            _log('Verificando permisos de ubicación en iOS: ${DateTime.now()}');
            try {
              final position = await locationService.getCurrentLocation();
              if (position != null) {
                _log(
                  'Posición de keepAlive: ${position.latitude}, ${position.longitude}',
                );
              }
            } catch (e) {
              _log('Error en verificación periódica de ubicación: $e');
            }
          }),
        );
      } catch (e) {
        _log('Error al configurar tareas en segundo plano para iOS: $e');
        // Continuamos de todos modos
      }
    }
  }

  // Método para enviar el mensaje inicial con ubicación
  @pragma('vm:entry-point')
  static Future<bool> _sendInitialMessage(
    TelegramService telegramService,
    LocationService locationService,
    List<EmergencyContact> contacts,
  ) async {
    _log('⏳ Obteniendo ubicación actual para enviar mensaje inicial...');
    int locationRetries = 0;
    Position? position;

    // Intentar obtener ubicación con reintentos
    while (position == null && locationRetries < 3) {
      try {
        position = await locationService.getCurrentLocation();
        if (position == null) {
          locationRetries++;
          _log('Reintento ${locationRetries}/3 para obtener ubicación');
          await Future.delayed(Duration(seconds: 1));
        }
      } catch (e) {
        _log('Error al obtener ubicación (intento ${locationRetries + 1}): $e');
        locationRetries++;
        await Future.delayed(Duration(seconds: 1));
      }
    }

    if (position != null) {
      _log(
        '✅ Ubicación obtenida: Lat ${position.latitude}, Lng ${position.longitude}',
      );

      // Enviar mensaje de inicio
      _log('⏳ Enviando mensaje inicial a ${contacts.length} contactos');
      bool messageSent = false;
      int messageRetries = 0;

      while (!messageSent && messageRetries < 3) {
        try {
          _log(
            '⏳ INICIANDO ENVÍO DE MENSAJE CRÍTICO a Telegram - intento ${messageRetries + 1}',
          );
          await telegramService.sendMessageToAllContacts(
            contacts,
            '🚨 *ALERTA DE EMERGENCIA* 🚨\n\nSe ha activado una alerta. Se enviarán actualizaciones periódicas.',
            markdown: true,
          );
          messageSent = true;
          _log('✅ Mensaje inicial enviado correctamente');
        } catch (e) {
          _log(
            '❌ ERROR al enviar mensaje inicial (intento ${messageRetries + 1}): $e',
          );

          // Intentar nuevamente con un mensaje más simple
          try {
            _log(
              '⏳ Reintentando con mensaje simple - intento ${messageRetries + 1}',
            );
            await telegramService.sendMessageToAllContacts(
              contacts,
              'ALERTA DE EMERGENCIA: Se ha activado una alerta.',
              markdown: false,
            );
            messageSent = true;
            _log('✅ Mensaje simple enviado correctamente');
          } catch (retryError) {
            _log('❌ ERROR en segundo intento de mensaje inicial: $retryError');
          }

          messageRetries++;
          if (!messageSent && messageRetries < 3) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }

      // Enviar ubicación inicial
      _log('⏳ INICIANDO ENVÍO DE UBICACIÓN a Telegram');
      bool locationSent = false;
      int locationSendRetries = 0;

      while (!locationSent && locationSendRetries < 3) {
        try {
          await telegramService.sendLocationToAllContacts(contacts, position);
          locationSent = true;
          _log('✅ Ubicación inicial enviada correctamente');
        } catch (e) {
          _log(
            '❌ ERROR al enviar ubicación inicial (intento ${locationSendRetries + 1}): $e',
          );

          // Intentar con un mensaje que incluya la ubicación en texto
          try {
            _log('⏳ Reintentando con mensaje de texto de ubicación');
            final locationText = locationService.formatLocationMessage(
              position,
            );
            final mapsLink = locationService.getGoogleMapsLink(position);
            await telegramService.sendMessageToAllContacts(
              contacts,
              'Mi ubicación actual:\n$locationText\n\nVer en mapa: $mapsLink',
              markdown: false,
            );
            locationSent = true;
            _log('✅ Texto de ubicación enviado como alternativa');
          } catch (retryError) {
            _log(
              '❌ ERROR en segundo intento de envío de ubicación: $retryError',
            );
          }

          locationSendRetries++;
          if (!locationSent && locationSendRetries < 3) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }

      return messageSent || locationSent;
    } else {
      _log('❌ ERROR: No se pudo obtener la posición inicial');

      // Intentar enviar un mensaje a pesar de no tener ubicación
      try {
        _log('⏳ INICIANDO ENVÍO DE MENSAJE SIN UBICACIÓN a Telegram');
        await telegramService.sendMessageToAllContacts(
          contacts,
          '🚨 *ALERTA DE EMERGENCIA* 🚨\n\nSe ha activado una alerta. No se pudo obtener la ubicación actual.',
          markdown: true,
        );
        _log('✅ Mensaje de alerta sin ubicación enviado');
        return true;
      } catch (e) {
        _log('❌ ERROR al enviar mensaje de alerta sin ubicación: $e');
        return false;
      }
    }
  }

  // Método para programar actualizaciones periódicas de ubicación
  @pragma('vm:entry-point')
  static void _scheduleLocationUpdates(
    ServiceInstance service,
    TelegramService telegramService,
    LocationService locationService,
    List<EmergencyContact> contacts,
    AlertSettings settings,
  ) {
    _log(
      '⏳ Configurando timer para ubicación cada ${settings.locationUpdateIntervalSeconds} segundos',
    );

    _timers.add(
      Timer.periodic(Duration(seconds: settings.locationUpdateIntervalSeconds), (
        timer,
      ) async {
        try {
          _log('⏳ Timer de ubicación activado, obteniendo nueva posición');
          final newPosition = await locationService.getCurrentLocation();
          if (newPosition != null) {
            _log(
              '✅ Nueva posición obtenida: Lat ${newPosition.latitude}, Lng ${newPosition.longitude}',
            );

            // Enviar actualización como mensaje para mayor confiabilidad
            try {
              _log('⏳ INICIANDO ENVÍO DE MENSAJE DE ACTUALIZACIÓN a Telegram');
              final locationText = locationService.formatLocationMessage(
                newPosition,
              );
              final mapsLink = locationService.getGoogleMapsLink(newPosition);
              await telegramService.sendMessageToAllContacts(
                contacts,
                '📍 *Actualización de ubicación*\n\n$locationText\n\nVer en mapa: $mapsLink',
                markdown: true,
              );
              _log('✅ Mensaje de ubicación enviado correctamente');
            } catch (e) {
              _log('❌ Error al enviar mensaje de ubicación: $e');

              // Intento con formato simple
              try {
                _log('⏳ Reintentando con formato simple');
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  'Actualización de ubicación: ${newPosition.latitude}, ${newPosition.longitude}',
                  markdown: false,
                );
                _log('✅ Mensaje simple de ubicación enviado');
              } catch (retryError) {
                _log(
                  '❌ No se pudo enviar ningún mensaje de ubicación: $retryError',
                );
              }
            }

            // También intentar enviar como ubicación nativa
            try {
              _log('⏳ INICIANDO ENVÍO DE UBICACIÓN NATIVA a Telegram');
              await telegramService.sendLocationToAllContacts(
                contacts,
                newPosition,
              );
              _log('✅ Ubicación nativa enviada correctamente');
            } catch (e) {
              _log('❌ Error al enviar ubicación nativa: $e');
            }
          } else {
            _log('❌ No se pudo obtener la nueva posición');
          }
        } catch (e) {
          _log('❌ Error al enviar ubicación periódica: $e');
          service.invoke('logError', {
            'source': 'locationTimer',
            'error': e.toString(),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }),
    );

    _log('✅ Timer de ubicación configurado');
  }

  // Método para programar grabaciones periódicas de audio
  @pragma('vm:entry-point')
  static void _scheduleAudioRecordings(
    ServiceInstance service,
    TelegramService telegramService,
    AudioService audioService,
    List<EmergencyContact> contacts,
    AlertSettings settings,
  ) {
    _log(
      '⏳ Configurando timer de audio cada ${settings.audioRecordingIntervalSeconds} segundos',
    );

    _timers.add(
      Timer.periodic(Duration(seconds: settings.audioRecordingIntervalSeconds), (
        timer,
      ) async {
        try {
          _log('⏳ Timer de audio activado, iniciando grabación');

          // Para iOS, manejar la sesión de audio con más cuidado
          bool canRecordAudio = true;

          if (Platform.isIOS) {
            try {
              // Reinicializar el servicio de audio antes de cada grabación en iOS
              // Esto es crítico para solucionar el problema
              _log('Preparando servicio de audio para iOS antes de grabar');

              // Liberar recursos del grabador anterior pero no desactivar la sesión
              // Es importante evitar crear/destruir sesiones de audio repetidamente en iOS
              try {
                // Dar tiempo al sistema para liberar recursos anteriores
                await Future.delayed(const Duration(milliseconds: 800));

                // Inicializar nuevamente
                await audioService.initialize();
                _log('Servicio de audio preparado para iOS');
              } catch (initError) {
                _log('Error al preparar audio: $initError');

                // Si hubo un error específico con la sesión, intentar una reinicialización completa
                if (initError.toString().contains('Session')) {
                  try {
                    await Future.delayed(const Duration(seconds: 2));
                    await audioService.dispose();
                    await Future.delayed(const Duration(seconds: 2));
                    await audioService.initialize();
                    _log('Audio reinicializado completamente');
                  } catch (finalError) {
                    _log('Fallo en reinicialización completa: $finalError');
                    canRecordAudio = false;
                  }
                } else {
                  canRecordAudio = false;
                }
              }
            } catch (e) {
              _log('Error general al preparar audio en iOS: $e');
              canRecordAudio = false;
            }
          }

          if (!canRecordAudio) {
            _log('No se puede grabar audio en este momento');

            // Informar del error a los contactos
            try {
              await telegramService.sendMessageToAllContacts(
                contacts,
                'No se puede grabar audio en este momento. Se intentará en la próxima actualización.',
                markdown: false,
              );
            } catch (msgError) {
              _log('Error al enviar mensaje de fallo de audio: $msgError');
            }

            return;
          }

          // Grabar audio con la duración ajustada para iOS
          final recordingDuration =
              (Platform.isIOS)
                  ? math.min(
                    settings.audioRecordingDurationSeconds,
                    20,
                  ) // máximo 20 segundos en iOS
                  : settings.audioRecordingDurationSeconds;

          // Grabar audio
          int audioAttempts = 0;
          String? audioPath;

          while (audioPath == null && audioAttempts < 3) {
            audioAttempts++;
            try {
              _log('Intento $audioAttempts de grabación de audio');
              _log('Grabando audio durante $recordingDuration segundos');
              audioPath = await audioService.startRecording(recordingDuration);

              if (audioPath == null && audioAttempts < 3) {
                _log('Reintento $audioAttempts de grabación de audio');
                await Future.delayed(const Duration(seconds: 2));
              }
            } catch (e) {
              _log('Error en intento $audioAttempts de grabación: $e');
              if (audioAttempts < 3) {
                await Future.delayed(const Duration(seconds: 2));
              }
            }
          }

          if (audioPath != null) {
            _log('Audio grabado en: $audioPath');

            // Verificar que el archivo realmente existe
            final audioFile = File(audioPath);
            if (!await audioFile.exists()) {
              _log(
                '⚠️ El archivo de audio no existe a pesar del path válido: $audioPath',
              );

              // Intentar enviar mensaje informando del problema
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  '⚠️ Se intentó grabar audio pero el archivo no está accesible. Se intentará nuevamente más tarde.',
                  markdown: false,
                );
                _log('Mensaje de advertencia enviado');
              } catch (e) {
                _log('Error al enviar mensaje de advertencia: $e');
              }

              return;
            }

            // Verificar tamaño del archivo
            final fileSize = await audioFile.length();
            _log('Tamaño del archivo de audio: $fileSize bytes');

            if (fileSize <= 0) {
              _log('⚠️ El archivo de audio está vacío (0 bytes): $audioPath');

              // Intentar enviar mensaje informando del problema
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  '⚠️ Se grabó audio pero el archivo resultó vacío. Se intentará nuevamente más tarde.',
                  markdown: false,
                );
                _log('Mensaje de advertencia enviado');
              } catch (e) {
                _log('Error al enviar mensaje de advertencia: $e');
              }

              return;
            }

            // Primero enviar mensaje informando que se enviará audio
            try {
              await telegramService.sendMessageToAllContacts(
                contacts,
                '🎤 Enviando grabación de audio ambiental...',
                markdown: false,
              );
              _log('Mensaje previo al audio enviado');
            } catch (e) {
              _log('Error al enviar mensaje previo al audio: $e');
            }

            // Enviar audio a todos los contactos con sistema de reintentos mejorado
            int audioRetries = 0;
            bool audioSent = false;

            // Para iOS, esperar un poco antes de intentar enviar el audio
            if (Platform.isIOS) {
              await Future.delayed(const Duration(seconds: 1));
            }

            while (!audioSent && audioRetries < 5) {
              try {
                audioRetries++;
                _log('Intento $audioRetries de enviar audio');

                // Verificar que el archivo aún existe antes de enviarlo
                if (!await audioFile.exists()) {
                  _log(
                    '⚠️ El archivo dejó de existir antes del intento $audioRetries: $audioPath',
                  );
                  throw Exception(
                    'El archivo dejó de existir durante el proceso de envío',
                  );
                }

                await telegramService.sendAudioToAllContacts(
                  contacts,
                  audioPath,
                );
                audioSent = true;
                _log('Audio enviado correctamente');
              } catch (e) {
                _log('Error al enviar audio (intento $audioRetries): $e');

                // Aumentar tiempo de espera entre reintentos
                final waitTime = Duration(seconds: audioRetries * 2);
                _log('Esperando ${waitTime.inSeconds}s antes de reintentar');
                await Future.delayed(waitTime);
              }
            }

            if (!audioSent) {
              _log(
                'No se pudo enviar el audio después de $audioRetries intentos',
              );

              // Enviar mensaje de texto alternativo
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  '⚠️ Se grabó audio pero no se pudo enviar debido a problemas de conexión',
                  markdown: false,
                );
                _log('Mensaje alternativo enviado');
              } catch (e) {
                _log('Error al enviar mensaje alternativo: $e');
              }
            }
          } else {
            _log(
              'No se pudo grabar el audio después de $audioAttempts intentos',
            );

            // Informar del error
            try {
              await telegramService.sendMessageToAllContacts(
                contacts,
                'No se pudo grabar el audio ambiental.',
                markdown: false,
              );
              _log('Mensaje de error de grabación enviado');
            } catch (e) {
              _log('Error al enviar mensaje de error de grabación: $e');
            }
          }
        } catch (e) {
          _log('❌ Error al grabar y enviar audio: $e');
          service.invoke('logError', {
            'source': 'audioTimer',
            'error': e.toString(),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }),
    );

    _log('✅ Timer de audio configurado');
  }

  // Iniciar alerta en segundo plano - método refactorizado
  @pragma('vm:entry-point')
  static Future<void> _startAlert(
    ServiceInstance service,
    String token,
    List<EmergencyContact> contacts,
    AlertSettings settings,
  ) async {
    final logger = Logger();
    _log('▶️ _startAlert entró - PUNTO DE ENTRADA CRÍTICO');
    _log('Iniciando alerta en segundo plano');
    _log('Token: $token');
    _log('Cantidad de contactos: ${contacts.length}');

    // Información detallada sobre la lista de contactos para depuración
    _log('Contactos detallados:');
    if (contacts.isEmpty) {
      _log('ERROR CRÍTICO: Lista de contactos está VACÍA');
    } else {
      for (var i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        _log(
          '  Contacto #$i - Nombre: ${contact.name}, Chat ID: ${contact.chatId}',
        );
        // Verificar que el chat ID sea válido
        try {
          final chatIdNum = int.parse(contact.chatId);
          _log('    Chat ID válido: $chatIdNum');
        } catch (e) {
          _log(
            '    ERROR: Chat ID inválido, no es un número: ${contact.chatId}',
          );
        }
      }
    }

    _log('Configuración: ${settings.toJson()}');

    final locationService = LocationService();
    final audioService = AudioService();
    final telegramService = TelegramService();

    // Inicializar servicios
    _log('Inicializando servicio de Telegram');
    telegramService.initialize(token);

    // En iOS, primero inicializar el servicio de telegram antes que el audio
    // para evitar problemas de inicialización
    if (Platform.isIOS) {
      _log('Verificando token de Telegram antes de inicializar audio en iOS');
      try {
        await telegramService.verifyToken();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _log('Error al verificar token de Telegram: $e');
      }

      // La configuración de audio session ahora se maneja a través del paquete audio_session
      // directamente en el servicio AudioService, por lo que eliminamos la configuración redundante
      _log(
        'La configuración de audio session se manejará a través de audio_session',
      );
    }

    // Ahora inicializar el audio después del telegram en iOS
    _log('Inicializando servicio de Audio');
    try {
      // En iOS, damos más tiempo entre la verificación del token y la inicialización de audio
      if (Platform.isIOS) {
        // Este retraso adicional puede evitar conflictos entre sesiones de audio
        await Future.delayed(const Duration(milliseconds: 1200));
        _log(
          'Verificando permiso de micrófono explícitamente antes de inicializar audio en iOS',
        );

        // Verificación explícita de permisos
        final micStatus = await Permission.microphone.status;
        _log('Estado actual del permiso de micrófono en iOS: $micStatus');

        if (micStatus != PermissionStatus.granted) {
          _log('Solicitando permiso de micrófono en iOS explícitamente');
          final newStatus = await Permission.microphone.request();
          _log('Nuevo estado del permiso de micrófono: $newStatus');

          if (newStatus != PermissionStatus.granted) {
            _log('ADVERTENCIA: No se pudo obtener permiso de micrófono en iOS');
          }
        }
      }

      await audioService.initialize();
      _log('Servicio de audio inicializado correctamente');
    } catch (e) {
      _log('Error al inicializar audio: $e');
      // En iOS, hacer un segundo intento con nueva instancia
      if (Platform.isIOS) {
        try {
          _log('Reintentando inicialización de audio para iOS');

          // Liberar recursos completamente antes de reintentar
          try {
            await audioService.dispose();
            await Future.delayed(const Duration(seconds: 3));
          } catch (disposeError) {
            _log('Error al liberar recursos de audio: $disposeError');
            // Continuamos de todos modos
          }

          _log('Esperando 3 segundos adicionales antes de reintentar en iOS');
          await Future.delayed(const Duration(seconds: 3));
          await audioService.initialize();
          _log('Audio inicializado en segundo intento');
        } catch (retryError) {
          _log(
            'Fallo en segundo intento de inicialización de audio: $retryError',
          );

          // Tercer intento con enfoque diferente
          try {
            _log('Último intento de inicialización de audio para iOS');
            await Future.delayed(const Duration(seconds: 4));

            // Para el último intento, simplemente usar la instancia existente
            _log('Usando instancia existente con inicialización limpia');
            await audioService.dispose();
            await Future.delayed(const Duration(seconds: 1));
            await audioService.initialize();
            _log('Audio inicializado en tercer intento');
          } catch (finalError) {
            _log(
              'Todos los intentos de inicialización de audio fallaron: $finalError',
            );
            // Continuamos sin audio en último caso
          }
        }
      }
    }

    // Configurar servicios específicos para iOS
    await _setupBackgroundServices(service, settings, locationService);

    // Informar del inicio de la alerta
    service.invoke('updateStatus', {
      'status': 'Alerta iniciada',
      'isActive': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _log('Estado del servicio actualizado: Alerta iniciada');

    // Función para limpiar recursos
    void cleanUp() {
      // Cancelar timers de manera segura
      try {
        for (var timer in _timers) {
          timer.cancel();
        }
        _timers.clear();
        _log('Todos los timers cancelados');
      } catch (e) {
        _log('Error al cancelar timers: $e');
      }

      // Verificación para iOS - limpieza más agresiva
      if (Platform.isIOS) {
        try {
          _log('iOS: Realizando limpieza adicional de recursos...');

          // Forzar NULL en los timers para ayudar al GC
          for (var timer in _timers) {
            timer.cancel();
          }
          _timers.clear();

          // Liberar recursos de audio
          try {
            final audioService = AudioService();
            audioService
                .dispose()
                .then((_) {
                  _log('Recursos de audio liberados en cleanUp');
                })
                .catchError((e) {
                  _log('Error al liberar audio en cleanUp: $e');
                });
          } catch (audioError) {
            _log('Error al inicializar audio para limpieza: $audioError');
          }

          // Forzar actualización de estado
          Future.delayed(Duration(milliseconds: 300), () {
            try {
              // Notificar la limpieza exitosa
              service.invoke('updateStatus', {
                'status': 'Recursos limpiados completamente',
                'isActive': false,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
              _log('Estado actualizado: recursos limpiados');
            } catch (e) {
              _log('Error al actualizar estado después de limpieza: $e');
            }
          });
        } catch (e) {
          _log('Error en limpieza adicional iOS: $e');
        }
      }
    }

    // Manejar el cierre del servicio
    final stopServiceSubscription = service.on('stopService').listen((event) {
      _log('Recibido evento stopService, limpiando recursos');
      cleanUp();

      // En iOS, enviar un reconocimiento de detención
      if (Platform.isIOS) {
        try {
          service.invoke('updateStatus', {
            'status': 'Evento stopService procesado correctamente',
            'isActive': false,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        } catch (e) {
          _log('Error al enviar reconocimiento de stopService: $e');
        }
      }
    });

    // Añadir a la lista de suscripciones estáticas
    _timers.add(
      Timer(const Duration(seconds: 1), () {
        // No podemos acceder a _activeSubscriptions desde un método estático,
        // así que usamos la lista de timers para asegurar su limpieza
        stopServiceSubscription.onDone(() {
          _log('Suscripción stopService terminada');
        });
      }),
    );

    try {
      // 1. Enviar mensaje inicial con ubicación
      bool initialMessageSent = await _sendInitialMessage(
        telegramService,
        locationService,
        contacts,
      );

      if (initialMessageSent) {
        // 2. Programar actualizaciones periódicas de ubicación
        _scheduleLocationUpdates(
          service,
          telegramService,
          locationService,
          contacts,
          settings,
        );

        // 3. Programar grabaciones y envíos de audio
        _scheduleAudioRecordings(
          service,
          telegramService,
          audioService,
          contacts,
          settings,
        );
      } else {
        _log(
          '❌ ERROR: No se pudo enviar la información inicial, no se programarán actualizaciones',
        );
      }
    } catch (e) {
      _log('❌ ERROR CRÍTICO al iniciar alerta: $e');
      logger.e('Error al iniciar alerta: $e');

      // Limpiar recursos en caso de error
      cleanUp();
    }
  }

  // Método para manejar errores de BackgroundTask en iOS
  Future<void> _handleBackgroundTaskError() async {
    if (Platform.isIOS) {
      _log('Manejando posibles errores de BGTaskScheduler en iOS');
      try {
        // Reiniciar los servicios de ubicación puede ayudar
        _log('Reiniciando servicios de ubicación...');
        await Geolocator.openLocationSettings();

        // Esperar un poco para que los cambios surtan efecto
        await Future.delayed(const Duration(seconds: 1));

        // Verificar que los servicios estén habilitados
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        _log(
          'Servicios de ubicación habilitados después del reinicio: $serviceEnabled',
        );

        // Para servicios iOS, podríamos usar código específico pero no es necesario
        // exponer directamente la implementación interna del plugin
        _log('Servicio de iOS configurado para mejor manejo de permisos');
      } catch (e) {
        _log('Error al intentar manejar errores de BGTaskScheduler: $e');
      }
    }
  }

  // Iniciar alerta desde la aplicación principal
  Future<bool> startAlert(
    String token,
    List<EmergencyContact> contacts,
    AlertSettings settings,
  ) async {
    if (_isAlertActive) {
      _log('La alerta ya está activa');
      return false;
    }

    // Verificar que el servicio esté activo, si no, iniciarlo
    _log('Verificando si el servicio está activo');
    if (!await _backgroundService.isRunning()) {
      _log('El servicio no está activo, iniciándolo');
      await _backgroundService.startService();
      // Dar tiempo a que el servicio se inicie completamente
      await Future.delayed(const Duration(seconds: 2));
      _log('Servicio iniciado correctamente');
    } else {
      _log('El servicio ya está activo');
    }

    // En iOS, preparar servicios de audio antes de iniciar
    if (Platform.isIOS) {
      try {
        // Reiniciar servicios de audio completamente
        await _audioService.dispose();
        await Future.delayed(const Duration(milliseconds: 500));
        await _audioService.initialize();
        _log('Audio preparado previamente para iOS');
      } catch (e) {
        _log('Error al preparar audio para iOS: $e');
        // Continuamos de todos modos
      }

      // Verificar token de telegram primero
      try {
        _telegramService.initialize(token);
        _log('TelegramService inicializado con token: $token');
        await _telegramService.verifyToken();
        _log('Token de Telegram verificado correctamente');
      } catch (e) {
        _log('Error al verificar token de Telegram: $e');
        // Continuamos de todos modos
      }
    }

    // Número máximo de intentos para iniciar la alerta
    const maxRetries = 3;
    int currentAttempt = 0;
    bool success = false;

    while (currentAttempt < maxRetries && !success) {
      currentAttempt++;
      _log('Intento ${currentAttempt}/${maxRetries} de iniciar alerta');

      try {
        _log('Iniciando alerta con ${contacts.length} contactos');

        // Verificar conexión a Internet antes de iniciar
        try {
          _log('Verificando conexión a Internet...');
          // Implementar verificación de conectividad si es necesario
        } catch (e) {
          _log('Error al verificar conexión a Internet: $e');
        }

        // Verificar servicio de ubicación y permisos antes de iniciar
        final locationService = LocationService();
        final position = await locationService.getCurrentLocation();
        if (position == null) {
          _log('ERROR: No se pudo obtener la ubicación actual');

          // Si estamos en iOS, intentamos manejar errores específicos
          if (Platform.isIOS) {
            _log('Intentando resolver problemas de ubicación en iOS...');
            await _handleBackgroundTaskError();
          }
        } else {
          _log('Ubicación obtenida correctamente antes de iniciar alerta');
          _log('Posición: Lat ${position.latitude}, Lng ${position.longitude}');
        }

        // Verificar configuración adecuada para iOS
        if (Platform.isIOS) {
          _log('Verificando configuración para iOS antes de iniciar alerta');

          // Para iOS, inicializar de nuevo los servicios en cada intento
          if (currentAttempt > 1) {
            // Dar un tiempo entre reintentos
            await Future.delayed(const Duration(seconds: 2));

            try {
              // Reinicializar audio completamente
              await _audioService.dispose();
              await Future.delayed(const Duration(milliseconds: 500));
              await _audioService.initialize();
              _log('Servicio de audio reinicializado para iOS');
            } catch (e) {
              _log('Error al reinicializar audio en reintento: $e');
            }
          }
        }

        final service = _backgroundService;

        // Preparar parámetros adicionales para mejor manejo en iOS
        final params = {
          'token': token,
          'contacts': contacts.map((e) => e.toJson()).toList(),
          'settings': settings.toJson(),
          'attempt': currentAttempt,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Para depuración, mostrar parámetros (ocultar token completo)
        final debugParams = Map<String, dynamic>.from(params);
        if (debugParams.containsKey('token')) {
          final tokenStr = debugParams['token'] as String;
          debugParams['token'] =
              tokenStr.length > 8
                  ? '${tokenStr.substring(0, 4)}...${tokenStr.substring(tokenStr.length - 4)}'
                  : tokenStr;
        }
        _log('Invocando startAlert con parámetros: $debugParams');

        // Invocar el servicio en segundo plano
        service.invoke('startAlert', params);

        // En iOS, hacer un seguimiento explícito del estado y esperar más tiempo
        if (Platform.isIOS) {
          // Registrar un escuchador para confirmar inicio de alerta
          success = await _waitForAlertToStart(timeout: Duration(seconds: 30));
        } else {
          // En Android asumimos que se inició correctamente
          success = true;
        }

        if (success) {
          _isAlertActive = true;
          _log('Alerta iniciada correctamente (intento $currentAttempt)');
          return true;
        } else if (currentAttempt < maxRetries) {
          _log('Fallo al iniciar alerta, reintentando...');
          // Esperar un poco antes de reintentar
          await Future.delayed(Duration(seconds: 2 * currentAttempt));
        }
      } catch (e) {
        _log('ERROR al iniciar alerta (intento $currentAttempt): $e');

        // Si es un error específico de BGTaskScheduler en iOS
        if (Platform.isIOS && e.toString().contains('BGTaskScheduler')) {
          _log('Error específico de BGTaskScheduler en iOS');
          _log('Intentando resolver el problema...');

          await _handleBackgroundTaskError();

          // Intentar nuevamente con un enfoque alternativo en el siguiente ciclo
          if (currentAttempt < maxRetries) {
            _log('Se reintentará con enfoque alternativo...');
            await Future.delayed(Duration(seconds: 2 * currentAttempt));
          }
        } else if (currentAttempt >= maxRetries) {
          return false;
        }
      }
    }

    // Si llegamos aquí después de agotar los reintentos, la alerta no se inició
    _log('No se pudo iniciar la alerta después de $maxRetries intentos');
    return false;
  }

  // Esperar confirmación de inicio de alerta (para iOS)
  Future<bool> _waitForAlertToStart({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _log('Esperando confirmación de inicio de alerta...');
    try {
      // Crear un completer que se resolverá cuando se confirme el inicio
      final completer = Completer<bool>();

      // Variables para seguimiento
      bool statusReceived = false;

      // Temporizador para evitar esperar indefinidamente
      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _log('Tiempo de espera agotado para confirmación de inicio');

          // En iOS, podemos asumir que el servicio se inició correctamente
          // incluso si no recibimos confirmación explícita (comportamiento defensivo)
          if (Platform.isIOS && !statusReceived) {
            _log('iOS detectado: asumiendo inicio correcto a pesar de timeout');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        }
      });

      // Escuchar actualizaciones del servicio
      final subscription = onServiceUpdate.listen((event) {
        if (event != null) {
          statusReceived = true;
          _log('Recibida actualización de estado del servicio: $event');

          // Confirmar si la alerta está activa
          if (event['isActive'] == true) {
            _log('Recibida confirmación de inicio de alerta: $event');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          }
        }
      });

      // Añadir a la lista de suscripciones activas
      _activeSubscriptions.add(subscription);

      // Escuchar también otros eventos como heartbeat o keepAlive
      final serviceSubscription = _backgroundService.on('heartbeat').listen((
        event,
      ) {
        _log('Recibido heartbeat del servicio: $event');
        if (!statusReceived && !completer.isCompleted && Platform.isIOS) {
          // En iOS, un heartbeat puede considerarse indicación de que el servicio está vivo
          statusReceived = true;
          if (!completer.isCompleted) {
            _log('Usando heartbeat como confirmación alternativa');
            completer.complete(true);
          }
        }
      });

      // Añadir a la lista de suscripciones activas
      _activeSubscriptions.add(serviceSubscription);

      // Esperar resultado o timeout
      final result = await completer.future;

      // Limpiar recursos
      timer.cancel();

      // Cancelar estos suscriptores específicos y eliminarlos de la lista
      await subscription.cancel();
      _activeSubscriptions.remove(subscription);

      await serviceSubscription.cancel();
      _activeSubscriptions.remove(serviceSubscription);

      return result;
    } catch (e) {
      _log('Error al esperar confirmación de inicio: $e');

      // Para iOS, retornar true por defecto en caso de error para mejorar resiliencia
      if (Platform.isIOS) {
        _log('iOS detectado: asumiendo éxito a pesar del error');
        return true;
      }

      return false;
    }
  }

  // Método para limpiar suscriptores
  void _clearSubscriptions() {
    _log('Cancelando suscripciones activas...');
    for (var subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _log('Todas las suscripciones canceladas');
  }

  // Método unificado para limpiar todos los recursos
  void dispose() {
    _log('Limpiando todos los recursos...');
    _clearTimers();
    _clearSubscriptions();
    _log('Todos los recursos limpiados');
  }

  // Detener alerta desde la aplicación principal
  Future<bool> stopAlert() async {
    if (!_isAlertActive) {
      _log('La alerta no está activa, no se puede detener');
      return false;
    }

    try {
      _log('Deteniendo alerta desde la aplicación principal');

      // Limpiar recursos locales de forma simple
      dispose();

      // En iOS, forzar la detención del audio
      if (Platform.isIOS) {
        try {
          _log('iOS: Forzando detención del audio');
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );
          await channel.invokeMethod('forceStopAudio');
          _log('iOS: Detención forzada del audio completada');
        } catch (e) {
          _log('Error al forzar detención del audio: $e');
          // Continuar de todos modos
        }
      }

      // SIMPLIFICADO: Solo enviar el comando de stop sin intentar limpiar recursos manualmente
      // Esto es importante para evitar interferir con la funcionalidad de grabación
      _log(
        'Enviando comando para detener la alerta pero manteniendo el servicio activo',
      );

      final FlutterBackgroundService service = FlutterBackgroundService();
      service.invoke("stopAlert", {
        'reason': 'user_stopped',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'force_stop_audio':
            true, // Indicar que se debe forzar la detención del audio
      });

      // Dar tiempo al sistema para procesar el comando
      await Future.delayed(const Duration(seconds: 1));

      _log('Comando para detener la alerta enviado correctamente');
      _isAlertActive = false;
      return true;
    } catch (e) {
      _log('ERROR al detener alerta: $e');
      _logger.e('Error al detener alerta: $e');

      // En iOS, consideramos exitoso incluso con errores para evitar bloqueos
      if (Platform.isIOS) {
        _log('iOS detectado: marcando alerta como detenida a pesar del error');
        _isAlertActive = false;
        return true;
      }

      return false;
    }
  }

  // Método para limpiar timers locales (no estáticos)
  void _clearTimers() {
    _log('Cancelando timers locales...');
    // Implementación real para cancelar los timers
    List<Timer> timersToCancel = List.from(_timers);
    for (var timer in timersToCancel) {
      timer.cancel();
    }
    _timers.clear();
    _log('Todos los timers locales cancelados');
  }
}
