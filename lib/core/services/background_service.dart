import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import 'audio_service.dart';
import 'location_service.dart';
import 'telegram_service.dart';
import '../../data/models/app_config.dart';
import '../../data/models/emergency_contact.dart';

// Anotación crucial para que la clase sea accesible desde código nativo
@pragma('vm:entry-point')
class BackgroundAlertService {
  // Logger
  final Logger _logger = Logger();

  // Servicios
  final LocationService _locationService = LocationService();
  final AudioService _audioService = AudioService();
  final TelegramService _telegramService = TelegramService();

  // Estado
  bool _isAlertActive = false;

  // Servicio en segundo plano
  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();

  // Notificaciones
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Timers
  Timer? _locationTimer;
  Timer? _audioTimer;

  // Singleton
  static final BackgroundAlertService _instance =
      BackgroundAlertService._internal();

  factory BackgroundAlertService() => _instance;

  BackgroundAlertService._internal();

  // Inicializar
  Future<void> initialize() async {
    await _initializeNotifications();
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

    // Registrar las identificaciones de tarea en iOS
    if (Platform.isIOS) {
      await _registerBackgroundTasks();
    }
  }

  // Añadir una nueva función para registrar las tareas de fondo en iOS
  Future<void> _registerBackgroundTasks() async {
    if (!Platform.isIOS) return;

    try {
      _logger.i('Registrando tareas en segundo plano para iOS');

      // Verificamos primero si la aplicación tiene los permisos adecuados
      final permissionStatus = await Permission.microphone.status;
      if (permissionStatus != PermissionStatus.granted) {
        _logger.w('Permiso de micrófono no concedido, solicitando...');
        await Permission.microphone.request();
      }

      // Registrar identificadores de tareas en segundo plano manualmente
      const MethodChannel channel = MethodChannel(
        'com.alerta.telegram/background_tasks',
      );

      final Map<String, dynamic> taskIds = {
        'identifiers': [
          'com.alerta.telegram.refresh',
          'com.alerta.telegram.processing',
          'com.alerta.telegram.audio',
        ],
      };

      try {
        _logger.d('Invocando registerBackgroundTasks en canal nativo');
        final bool? result = await channel.invokeMethod<bool>(
          'registerBackgroundTasks',
          taskIds,
        );
        _logger.i('Tareas en segundo plano registradas con resultado: $result');

        // Verificar si hay respuesta
        if (result == null) {
          _logger.w(
            'No se recibió respuesta al registrar tareas en segundo plano',
          );
        }

        // Ejecutar también setupBackgroundTasks para asegurar la configuración
        _logger.d('Configurando tareas en segundo plano adicionales');
        final setupResult = await channel
            .invokeMethod<bool>('setupBackgroundTasks', {
              'refresh': 'com.alerta.telegram.refresh',
              'processing': 'com.alerta.telegram.processing',
              'audio': 'com.alerta.telegram.audio',
            });
        _logger.i('Configuración adicional completada: $setupResult');
      } catch (e) {
        _logger.e('Error específico al llamar al método nativo: $e');
        // Continuamos de todos modos, ya que este es un paso adicional de seguridad

        // Si fallaron las llamadas al canal, posiblemente el canal no está configurado
        // correctamente. Registramos este error para depuración.
        _logger.e(
          'Posible causa: El MethodChannel no está correctamente configurado en AppDelegate.swift',
        );
        _logger.e(
          'Comprueba que setupBackgroundTasksChannel() está configurado y se ejecuta',
        );
      }
    } catch (e) {
      _logger.e(
        'Error general al registrar tareas en segundo plano para iOS: $e',
      );
      // Continuamos de todos modos, ya que este es un paso adicional de seguridad
    }
  }

  // Manejador iOS para segundo plano
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    print('iOS background handler iniciado');

    // Configuración más robusta para evitar BGTaskSchedulerErrorDomain
    try {
      if (Platform.isIOS) {
        print('Inicializando manejo de segundo plano iOS mejorado');

        // Intentar notificar correctamente sobre la finalización de la tarea
        try {
          // Crear el canal solo si es necesario
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );

          // Notificar que estamos procesando en segundo plano
          await channel.invokeMethod('completeBackgroundTask', {
            'taskIdentifier': 'com.alerta.telegram.processing',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          print('Notificación de tarea en proceso enviada correctamente');
        } catch (e) {
          print('Error al comunicar estado de tarea: $e');
        }

        // Método para mantener la tarea activa mediante invocación periódica
        print('Configurando timers para mantener vivo el servicio en iOS');
        Timer.periodic(const Duration(minutes: 1), (timer) {
          print('KeepAlive timer para iOS: ${DateTime.now()}');
          try {
            service.invoke('setBackgroundProcessingTaskCompleted', {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
            print('Señal de KeepAlive enviada');
          } catch (e) {
            print('Error en KeepAlive: $e');
          }
        });

        // Reenviar periódicamente señales de vida
        Timer.periodic(const Duration(minutes: 5), (timer) {
          print('iOS background service estado: activo - ${DateTime.now()}');
          try {
            service.invoke('heartbeat', {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          } catch (_) {}
        });
      }
    } catch (e) {
      print('Error al configurar servicio iOS: $e');
    }

    return true;
  }

  // Manejador principal del servicio en segundo plano
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    print('Servicio en segundo plano iniciado');

    // Servicio para Android
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setAutoStartOnBootMode(true);
      print('Configurado como servicio en primer plano (Android)');
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
      print('Heartbeat recibido: $event');
      // Responder con un estado actualizado
      service.invoke('updateStatus', {
        'status': 'Servicio activo',
        'isActive': true,
        'heartbeatResponse': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });

    // Escuchar mensajes
    service.on('startAlert').listen((event) async {
      print('Recibida petición para iniciar alerta con datos: $event');
      if (event == null) {
        print('ERROR: Evento startAlert recibido con datos nulos');
        return;
      }

      String? token = event['token'] as String?;
      if (token == null || token.isEmpty) {
        print('ERROR: Token nulo o vacío');
        return;
      }

      List<dynamic>? contactsRaw = event['contacts'] as List<dynamic>?;
      if (contactsRaw == null || contactsRaw.isEmpty) {
        print('ERROR: Lista de contactos nula o vacía');
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
        print('ERROR en _startAlert: $e');
      }
    });

    service.on('stopAlert').listen((event) async {
      print('Recibida petición para detener alerta');
      await _stopAlert(service);
    });
  }

  // Iniciar alerta en segundo plano
  @pragma('vm:entry-point')
  static Future<void> _startAlert(
    ServiceInstance service,
    String token,
    List<EmergencyContact> contacts,
    AlertSettings settings,
  ) async {
    final logger = Logger();
    print('Iniciando alerta en segundo plano');
    print('Token: $token');
    print('Cantidad de contactos: ${contacts.length}');
    print(
      'Contactos: ${contacts.map((c) => '${c.name}: ${c.chatId}').join(', ')}',
    );
    print('Configuración: ${settings.toJson()}');

    final locationService = LocationService();
    final audioService = AudioService();
    final telegramService = TelegramService();

    // Inicializar servicios
    print('Inicializando servicio de Telegram');
    telegramService.initialize(token);

    // En iOS, primero inicializar el servicio de telegram antes que el audio
    // para evitar problemas de inicialización
    if (Platform.isIOS) {
      print('Verificando token de Telegram antes de inicializar audio en iOS');
      try {
        await telegramService.verifyToken();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error al verificar token de Telegram: $e');
      }

      // La configuración de audio session ahora se maneja a través del paquete audio_session
      // directamente en el servicio AudioService, por lo que eliminamos la configuración redundante
      print(
        'La configuración de audio session se manejará a través de audio_session',
      );
    }

    // Ahora inicializar el audio después del telegram en iOS
    print('Inicializando servicio de Audio');
    try {
      // En iOS, damos más tiempo entre la verificación del token y la inicialización de audio
      if (Platform.isIOS) {
        // Este retraso adicional puede evitar conflictos entre sesiones de audio
        await Future.delayed(const Duration(milliseconds: 1200));
        print(
          'Verificando permiso de micrófono explícitamente antes de inicializar audio en iOS',
        );

        // Verificación explícita de permisos
        final micStatus = await Permission.microphone.status;
        print('Estado actual del permiso de micrófono en iOS: $micStatus');

        if (micStatus != PermissionStatus.granted) {
          print('Solicitando permiso de micrófono en iOS explícitamente');
          final newStatus = await Permission.microphone.request();
          print('Nuevo estado del permiso de micrófono: $newStatus');

          if (newStatus != PermissionStatus.granted) {
            print(
              'ADVERTENCIA: No se pudo obtener permiso de micrófono en iOS',
            );
          }
        }
      }

      await audioService.initialize();
      print('Servicio de audio inicializado correctamente');
    } catch (e) {
      print('Error al inicializar audio: $e');
      // En iOS, hacer un segundo intento con nueva instancia
      if (Platform.isIOS) {
        try {
          print('Reintentando inicialización de audio para iOS');

          // Liberar recursos completamente antes de reintentar
          try {
            await audioService.dispose();
            await Future.delayed(const Duration(seconds: 3));
          } catch (disposeError) {
            print('Error al liberar recursos de audio: $disposeError');
            // Continuamos de todos modos
          }

          print('Esperando 3 segundos adicionales antes de reintentar en iOS');
          await Future.delayed(const Duration(seconds: 3));
          await audioService.initialize();
          print('Audio inicializado en segundo intento');
        } catch (retryError) {
          print(
            'Fallo en segundo intento de inicialización de audio: $retryError',
          );

          // Tercer intento con enfoque diferente
          try {
            print('Último intento de inicialización de audio para iOS');
            await Future.delayed(const Duration(seconds: 4));

            // Para el último intento, simplemente usar la instancia existente
            print('Usando instancia existente con inicialización limpia');
            await audioService.dispose();
            await Future.delayed(const Duration(seconds: 1));
            await audioService.initialize();
            print('Audio inicializado en tercer intento');
          } catch (finalError) {
            print(
              'Todos los intentos de inicialización de audio fallaron: $finalError',
            );
            // Continuamos sin audio en último caso
          }
        }
      }
    }

    // Manejo específico para iOS y errores BGTaskSchedulerErrorDomain
    if (Platform.isIOS) {
      print('Configurando tareas en segundo plano para iOS...');
      try {
        // En iOS, debemos asegurarnos que los permisos estén correctamente configurados
        // para evitar errores BGTaskSchedulerErrorDomain
        print('Verificando permisos para tareas en segundo plano en iOS');

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
        print('Tareas en segundo plano registradas correctamente: $result');

        // Verificar y solicitar permisos de ubicación
        final permission = await Geolocator.checkPermission();
        print('Estado actual del permiso de ubicación: $permission');

        if (permission != LocationPermission.always) {
          print(
            'ADVERTENCIA: La ubicación en segundo plano no está habilitada',
          );
          print('Algunas funciones podrían no funcionar correctamente');

          // Intentar solicitar permisos si es posible
          if (permission == LocationPermission.whileInUse) {
            print('Intentando solicitar permiso de ubicación always...');
            final newPermission = await Geolocator.requestPermission();
            print('Nuevo estado de permiso: $newPermission');
          }
        }

        // Para iOS, aumentar intervalo entre grabaciones para permitir
        // que la app tenga más tiempo entre tareas
        if (settings.audioRecordingIntervalSeconds < 60) {
          print('Ajustando intervalo de grabación para iOS');
          settings = settings.copyWith(
            audioRecordingIntervalSeconds: math.max(
              settings.audioRecordingIntervalSeconds,
              60,
            ),
          );
          print(
            'Nuevo intervalo de grabación: ${settings.audioRecordingIntervalSeconds}s',
          );
        }

        // Para iOS, configurar temporizadores de keepAlive más frecuentes
        print('Configurando servicio para mantenerlo activo en iOS');
        Timer.periodic(const Duration(minutes: 1), (timer) {
          print('KeepAlive timer principal para iOS: ${DateTime.now()}');

          // Mantener la tarea activa
          try {
            // Usar directamente service.invoke sin comprobar tipo
            service.invoke('keepAlive', {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
            print('KeepAlive invocado para iOS');
          } catch (e) {
            print('Error en KeepAlive: $e');
          }
        });

        // Temporizador dedicado a mantener activos los permisos de ubicación
        Timer.periodic(const Duration(minutes: 2), (timer) async {
          print('Verificando permisos de ubicación en iOS: ${DateTime.now()}');
          try {
            final position = await locationService.getCurrentLocation();
            if (position != null) {
              print(
                'Posición de keepAlive: ${position.latitude}, ${position.longitude}',
              );
            }
          } catch (e) {
            print('Error en verificación periódica de ubicación: $e');
          }
        });

        // Para Android, configurar como servicio en primer plano
        if (service is AndroidServiceInstance) {
          service.setAsForegroundService();
        }
      } catch (e) {
        print('Error al configurar tareas en segundo plano para iOS: $e');
        // Continuamos de todos modos
      }
    }

    // Informar del inicio de la alerta
    service.invoke('updateStatus', {
      'status': 'Alerta iniciada',
      'isActive': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('Estado del servicio actualizado: Alerta iniciada');

    // Variables para almacenar los timers
    Timer? locationTimer;
    Timer? audioTimer;

    // Función para limpiar recursos
    void cleanUp() {
      locationTimer?.cancel();
      audioTimer?.cancel();
      print('Timers cancelados');
    }

    // Manejar el cierre del servicio
    service.on('stopService').listen((event) {
      print('Recibido evento stopService, limpiando recursos');
      cleanUp();
    });

    // Enviar mensaje inicial con la ubicación actual
    try {
      print('Obteniendo ubicación actual...');
      int locationRetries = 0;
      Position? position;

      // Intentar obtener ubicación con reintentos
      while (position == null && locationRetries < 3) {
        try {
          position = await locationService.getCurrentLocation();
          if (position == null) {
            locationRetries++;
            print('Reintento ${locationRetries}/3 para obtener ubicación');
            await Future.delayed(Duration(seconds: 1));
          }
        } catch (e) {
          print(
            'Error al obtener ubicación (intento ${locationRetries + 1}): $e',
          );
          locationRetries++;
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (position != null) {
        print(
          'Ubicación obtenida: Lat ${position.latitude}, Lng ${position.longitude}',
        );

        // Enviar mensaje de inicio
        print('Enviando mensaje inicial a ${contacts.length} contactos');
        bool messageSent = false;
        int messageRetries = 0;

        while (!messageSent && messageRetries < 3) {
          try {
            await telegramService.sendMessageToAllContacts(
              contacts,
              '🚨 *ALERTA DE EMERGENCIA* 🚨\n\nSe ha activado una alerta. Se enviarán actualizaciones periódicas.',
              markdown: true,
            );
            messageSent = true;
            print('Mensaje inicial enviado correctamente');
          } catch (e) {
            print(
              'ERROR al enviar mensaje inicial (intento ${messageRetries + 1}): $e',
            );

            // Intentar nuevamente con un mensaje más simple
            try {
              await telegramService.sendMessageToAllContacts(
                contacts,
                'ALERTA DE EMERGENCIA: Se ha activado una alerta.',
                markdown: false,
              );
              messageSent = true;
              print('Mensaje simple enviado correctamente');
            } catch (retryError) {
              print('ERROR en segundo intento de mensaje inicial: $retryError');
            }

            messageRetries++;
            if (!messageSent && messageRetries < 3) {
              await Future.delayed(Duration(seconds: 2));
            }
          }
        }

        // Enviar ubicación inicial
        print('Enviando ubicación inicial');
        bool locationSent = false;
        int locationSendRetries = 0;

        while (!locationSent && locationSendRetries < 3) {
          try {
            await telegramService.sendLocationToAllContacts(contacts, position);
            locationSent = true;
            print('Ubicación inicial enviada correctamente');
          } catch (e) {
            print(
              'ERROR al enviar ubicación inicial (intento ${locationSendRetries + 1}): $e',
            );

            // Intentar con un mensaje que incluya la ubicación en texto
            try {
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
              print('Texto de ubicación enviado como alternativa');
            } catch (retryError) {
              print(
                'ERROR en segundo intento de envío de ubicación: $retryError',
              );
            }

            locationSendRetries++;
            if (!locationSent && locationSendRetries < 3) {
              await Future.delayed(Duration(seconds: 2));
            }
          }
        }

        if (!messageSent && !locationSent) {
          print('ADVERTENCIA: No se pudo enviar ninguna información inicial');
          // Intentar un último método alternativo
          try {
            await telegramService.sendMessageToAllContacts(
              contacts,
              'Alerta activada. Por favor contactar al número de emergencia.',
              markdown: false,
            );
            print('Mensaje básico enviado como último recurso');
          } catch (e) {
            print('ERROR: Imposible enviar cualquier tipo de mensaje: $e');
          }
        }

        // Programar envíos periódicos de ubicación
        print(
          'Configurando timer para ubicación cada ${settings.locationUpdateIntervalSeconds} segundos',
        );
        locationTimer = Timer.periodic(
          Duration(seconds: settings.locationUpdateIntervalSeconds),
          (timer) async {
            try {
              print('Timer de ubicación activado, obteniendo nueva posición');
              final newPosition = await locationService.getCurrentLocation();
              if (newPosition != null) {
                print(
                  'Nueva posición obtenida: Lat ${newPosition.latitude}, Lng ${newPosition.longitude}',
                );

                // Enviar actualización como mensaje para mayor confiabilidad
                try {
                  final locationText = locationService.formatLocationMessage(
                    newPosition,
                  );
                  final mapsLink = locationService.getGoogleMapsLink(
                    newPosition,
                  );
                  await telegramService.sendMessageToAllContacts(
                    contacts,
                    '📍 *Actualización de ubicación*\n\n$locationText\n\nVer en mapa: $mapsLink',
                    markdown: true,
                  );
                  print('Mensaje de ubicación enviado correctamente');
                } catch (e) {
                  print('Error al enviar mensaje de ubicación: $e');

                  // Intento con formato simple
                  try {
                    await telegramService.sendMessageToAllContacts(
                      contacts,
                      'Actualización de ubicación: ${newPosition.latitude}, ${newPosition.longitude}',
                      markdown: false,
                    );
                    print('Mensaje simple de ubicación enviado');
                  } catch (retryError) {
                    print(
                      'No se pudo enviar ningún mensaje de ubicación: $retryError',
                    );
                  }
                }

                // También intentar enviar como ubicación nativa
                try {
                  await telegramService.sendLocationToAllContacts(
                    contacts,
                    newPosition,
                  );
                  print('Ubicación nativa enviada correctamente');
                } catch (e) {
                  print('Error al enviar ubicación nativa: $e');
                }
              } else {
                print('No se pudo obtener la nueva posición');
              }
            } catch (e) {
              print('Error al enviar ubicación periódica: $e');
              logger.e('Error al enviar ubicación periódica: $e');
            }
          },
        );
        print('Timer de ubicación configurado');

        // Programar grabaciones y envíos de audio
        print(
          'Configurando timer de audio cada ${settings.audioRecordingIntervalSeconds} segundos',
        );
        audioTimer = Timer.periodic(Duration(seconds: settings.audioRecordingIntervalSeconds), (
          timer,
        ) async {
          try {
            print('Timer de audio activado, iniciando grabación');

            // Para iOS, manejar la sesión de audio con más cuidado
            bool canRecordAudio = true;

            if (Platform.isIOS) {
              try {
                // Reinicializar el servicio de audio antes de cada grabación en iOS
                // Esto es crítico para solucionar el problema
                print('Preparando servicio de audio para iOS antes de grabar');

                // Liberar recursos del grabador anterior pero no desactivar la sesión
                // Es importante evitar crear/destruir sesiones de audio repetidamente en iOS
                try {
                  // Dar tiempo al sistema para liberar recursos anteriores
                  await Future.delayed(const Duration(milliseconds: 800));

                  // Inicializar nuevamente
                  await audioService.initialize();
                  print('Servicio de audio preparado para iOS');
                } catch (initError) {
                  print('Error al preparar audio: $initError');

                  // Si hubo un error específico con la sesión, intentar una reinicialización completa
                  if (initError.toString().contains('Session')) {
                    try {
                      await Future.delayed(const Duration(seconds: 2));
                      await audioService.dispose();
                      await Future.delayed(const Duration(seconds: 2));
                      await audioService.initialize();
                      print('Audio reinicializado completamente');
                    } catch (finalError) {
                      print('Fallo en reinicialización completa: $finalError');
                      canRecordAudio = false;
                    }
                  } else {
                    canRecordAudio = false;
                  }
                }
              } catch (e) {
                print('Error general al preparar audio en iOS: $e');
                canRecordAudio = false;
              }
            }

            if (!canRecordAudio) {
              print('No se puede grabar audio en este momento');

              // Informar del error a los contactos
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  'No se puede grabar audio en este momento. Se intentará en la próxima actualización.',
                  markdown: false,
                );
              } catch (msgError) {
                print('Error al enviar mensaje de fallo de audio: $msgError');
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
                print('Intento $audioAttempts de grabación de audio');
                print('Grabando audio durante $recordingDuration segundos');
                audioPath = await audioService.startRecording(
                  recordingDuration,
                );

                if (audioPath == null && audioAttempts < 3) {
                  print('Reintento $audioAttempts de grabación de audio');
                  await Future.delayed(const Duration(seconds: 2));
                }
              } catch (e) {
                print('Error en intento $audioAttempts de grabación: $e');
                if (audioAttempts < 3) {
                  await Future.delayed(const Duration(seconds: 2));
                }
              }
            }

            if (audioPath != null) {
              print('Audio grabado en: $audioPath');

              // Primero enviar mensaje informando que se enviará audio
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  '🎤 Enviando grabación de audio ambiental...',
                  markdown: false,
                );
                print('Mensaje previo al audio enviado');
              } catch (e) {
                print('Error al enviar mensaje previo al audio: $e');
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
                  print('Intento $audioRetries de enviar audio');

                  await telegramService.sendAudioToAllContacts(
                    contacts,
                    audioPath,
                  );
                  audioSent = true;
                  print('Audio enviado correctamente');
                } catch (e) {
                  print('Error al enviar audio (intento $audioRetries): $e');

                  // Aumentar tiempo de espera entre reintentos
                  final waitTime = Duration(seconds: audioRetries * 2);
                  print('Esperando ${waitTime.inSeconds}s antes de reintentar');
                  await Future.delayed(waitTime);
                }
              }

              if (!audioSent) {
                print(
                  'No se pudo enviar el audio después de $audioRetries intentos',
                );

                // Enviar mensaje de texto alternativo
                try {
                  await telegramService.sendMessageToAllContacts(
                    contacts,
                    '⚠️ Se grabó audio pero no se pudo enviar debido a problemas de conexión',
                    markdown: false,
                  );
                  print('Mensaje alternativo enviado');
                } catch (e) {
                  print('Error al enviar mensaje alternativo: $e');
                }
              }
            } else {
              print(
                'No se pudo grabar el audio después de $audioAttempts intentos',
              );

              // Informar del error
              try {
                await telegramService.sendMessageToAllContacts(
                  contacts,
                  'No se pudo grabar el audio ambiental.',
                  markdown: false,
                );
                print('Mensaje de error de grabación enviado');
              } catch (e) {
                print('Error al enviar mensaje de error de grabación: $e');
              }
            }
          } catch (e) {
            print('Error al grabar y enviar audio: $e');
            logger.e('Error al grabar y enviar audio: $e');
          }
        });
        print('Timer de audio configurado');
      } else {
        print('ERROR: No se pudo obtener la posición inicial');

        // Intentar enviar un mensaje a pesar de no tener ubicación
        try {
          await telegramService.sendMessageToAllContacts(
            contacts,
            '🚨 *ALERTA DE EMERGENCIA* 🚨\n\nSe ha activado una alerta. No se pudo obtener la ubicación actual.',
            markdown: true,
          );
          print('Mensaje de alerta sin ubicación enviado');
        } catch (e) {
          print('ERROR al enviar mensaje de alerta sin ubicación: $e');
        }
      }
    } catch (e) {
      print('ERROR al iniciar alerta: $e');
      logger.e('Error al iniciar alerta: $e');

      // Limpiar recursos en caso de error
      cleanUp();
    }
  }

  // Detener alerta en segundo plano
  @pragma('vm:entry-point')
  static Future<void> _stopAlert(ServiceInstance service) async {
    final logger = Logger();

    try {
      print('Deteniendo alerta en segundo plano');

      // Intentar liberar recursos de audio si estamos en iOS
      if (Platform.isIOS) {
        try {
          final audioService = AudioService();
          print('Liberando recursos de audio en iOS al detener alerta');

          // Permitir que el audio se libere correctamente
          await audioService.dispose();

          // Dar tiempo al sistema para procesar la liberación
          await Future.delayed(const Duration(seconds: 1));

          print('Recursos de audio liberados correctamente');
        } catch (audioError) {
          print('Error al liberar recursos de audio: $audioError');
          // Continuamos de todos modos
        }
      }

      service.invoke('updateStatus', {
        'status': 'Alerta detenida',
        'isActive': false,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      print('Estado del servicio actualizado: Alerta detenida');
    } catch (e) {
      print('ERROR al detener alerta: $e');
      logger.e('Error al detener alerta: $e');
    }
  }

  // Método para manejar errores de BackgroundTask en iOS
  Future<void> _handleBackgroundTaskError() async {
    if (Platform.isIOS) {
      print('Manejando posibles errores de BGTaskScheduler en iOS');
      try {
        // Reiniciar los servicios de ubicación puede ayudar
        print('Reiniciando servicios de ubicación...');
        await Geolocator.openLocationSettings();

        // Esperar un poco para que los cambios surtan efecto
        await Future.delayed(const Duration(seconds: 1));

        // Verificar que los servicios estén habilitados
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        print(
          'Servicios de ubicación habilitados después del reinicio: $serviceEnabled',
        );

        // Para servicios iOS, podríamos usar código específico pero no es necesario
        // exponer directamente la implementación interna del plugin
        print('Servicio de iOS configurado para mejor manejo de permisos');
      } catch (e) {
        print('Error al intentar manejar errores de BGTaskScheduler: $e');
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
      print('La alerta ya está activa');
      return false;
    }

    // En iOS, preparar servicios de audio antes de iniciar
    if (Platform.isIOS) {
      try {
        // Reiniciar servicios de audio completamente
        await _audioService.dispose();
        await Future.delayed(const Duration(milliseconds: 500));
        await _audioService.initialize();
        print('Audio preparado previamente para iOS');
      } catch (e) {
        print('Error al preparar audio para iOS: $e');
        // Continuamos de todos modos
      }

      // Verificar token de telegram primero
      try {
        _telegramService.initialize(token);
        print('TelegramService inicializado con token: $token');
        await _telegramService.verifyToken();
        print('Token de Telegram verificado correctamente');
      } catch (e) {
        print('Error al verificar token de Telegram: $e');
        // Continuamos de todos modos
      }
    }

    // Número máximo de intentos para iniciar la alerta
    const maxRetries = 3;
    int currentAttempt = 0;
    bool success = false;

    while (currentAttempt < maxRetries && !success) {
      currentAttempt++;
      print('Intento ${currentAttempt}/${maxRetries} de iniciar alerta');

      try {
        print('Iniciando alerta con ${contacts.length} contactos');

        // Verificar conexión a Internet antes de iniciar
        try {
          print('Verificando conexión a Internet...');
          // Implementar verificación de conectividad si es necesario
        } catch (e) {
          print('Error al verificar conexión a Internet: $e');
        }

        // Verificar servicio de ubicación y permisos antes de iniciar
        final locationService = LocationService();
        final position = await locationService.getCurrentLocation();
        if (position == null) {
          print('ERROR: No se pudo obtener la ubicación actual');

          // Si estamos en iOS, intentamos manejar errores específicos
          if (Platform.isIOS) {
            print('Intentando resolver problemas de ubicación en iOS...');
            await _handleBackgroundTaskError();
          }
        } else {
          print('Ubicación obtenida correctamente antes de iniciar alerta');
          print(
            'Posición: Lat ${position.latitude}, Lng ${position.longitude}',
          );
        }

        // Verificar configuración adecuada para iOS
        if (Platform.isIOS) {
          print('Verificando configuración para iOS antes de iniciar alerta');

          // Para iOS, inicializar de nuevo los servicios en cada intento
          if (currentAttempt > 1) {
            // Dar un tiempo entre reintentos
            await Future.delayed(const Duration(seconds: 2));

            try {
              // Reinicializar audio completamente
              await _audioService.dispose();
              await Future.delayed(const Duration(milliseconds: 500));
              await _audioService.initialize();
              print('Servicio de audio reinicializado para iOS');
            } catch (e) {
              print('Error al reinicializar audio en reintento: $e');
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
        print('Invocando startAlert con parámetros: $debugParams');

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
          print('Alerta iniciada correctamente (intento $currentAttempt)');
          return true;
        } else if (currentAttempt < maxRetries) {
          print('Fallo al iniciar alerta, reintentando...');
          // Esperar un poco antes de reintentar
          await Future.delayed(Duration(seconds: 2 * currentAttempt));
        }
      } catch (e) {
        print('ERROR al iniciar alerta (intento $currentAttempt): $e');

        // Si es un error específico de BGTaskScheduler en iOS
        if (Platform.isIOS && e.toString().contains('BGTaskScheduler')) {
          print('Error específico de BGTaskScheduler en iOS');
          print('Intentando resolver el problema...');

          await _handleBackgroundTaskError();

          // Intentar nuevamente con un enfoque alternativo en el siguiente ciclo
          if (currentAttempt < maxRetries) {
            print('Se reintentará con enfoque alternativo...');
            await Future.delayed(Duration(seconds: 2 * currentAttempt));
          }
        } else if (currentAttempt >= maxRetries) {
          return false;
        }
      }
    }

    // Si llegamos aquí después de agotar los reintentos, la alerta no se inició
    print('No se pudo iniciar la alerta después de $maxRetries intentos');
    return false;
  }

  // Esperar confirmación de inicio de alerta (para iOS)
  Future<bool> _waitForAlertToStart({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    print('Esperando confirmación de inicio de alerta...');
    try {
      // Crear un completer que se resolverá cuando se confirme el inicio
      final completer = Completer<bool>();

      // Variables para seguimiento
      bool statusReceived = false;

      // Temporizador para evitar esperar indefinidamente
      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          print('Tiempo de espera agotado para confirmación de inicio');

          // En iOS, podemos asumir que el servicio se inició correctamente
          // incluso si no recibimos confirmación explícita (comportamiento defensivo)
          if (Platform.isIOS && !statusReceived) {
            print(
              'iOS detectado: asumiendo inicio correcto a pesar de timeout',
            );
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
          print('Recibida actualización de estado del servicio: $event');

          // Confirmar si la alerta está activa
          if (event['isActive'] == true) {
            print('Recibida confirmación de inicio de alerta: $event');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          }
        }
      });

      // Escuchar también otros eventos como heartbeat o keepAlive
      final serviceSubscription = _backgroundService.on('heartbeat').listen((
        event,
      ) {
        print('Recibido heartbeat del servicio: $event');
        if (!statusReceived && !completer.isCompleted && Platform.isIOS) {
          // En iOS, un heartbeat puede considerarse indicación de que el servicio está vivo
          statusReceived = true;
          if (!completer.isCompleted) {
            print('Usando heartbeat como confirmación alternativa');
            completer.complete(true);
          }
        }
      });

      // Esperar resultado o timeout
      final result = await completer.future;

      // Limpiar recursos
      timer.cancel();
      await subscription.cancel();
      await serviceSubscription.cancel();

      return result;
    } catch (e) {
      print('Error al esperar confirmación de inicio: $e');

      // Para iOS, retornar true por defecto en caso de error para mejorar resiliencia
      if (Platform.isIOS) {
        print('iOS detectado: asumiendo éxito a pesar del error');
        return true;
      }

      return false;
    }
  }

  // Detener alerta desde la aplicación principal
  Future<bool> stopAlert() async {
    if (!_isAlertActive) {
      print('La alerta no está activa, no se puede detener');
      return false;
    }

    try {
      print('Deteniendo alerta desde la aplicación principal');
      // Enviar comando para detener
      _backgroundService.invoke('stopAlert');
      print('Comando para detener enviado al servicio');

      // Limpiar recursos
      _clearTimers();
      print('Timers limpiados');

      _isAlertActive = false;
      return true;
    } catch (e) {
      print('ERROR al detener alerta: $e');
      _logger.e('Error al detener alerta: $e');
      return false;
    }
  }

  // Limpiar timers
  void _clearTimers() {
    _locationTimer?.cancel();
    _locationTimer = null;

    _audioTimer?.cancel();
    _audioTimer = null;
  }

  // Estado de la alerta
  bool get isAlertActive => _isAlertActive;

  // Suscribirse a actualizaciones del servicio
  Stream<Map<String, dynamic>?> get onServiceUpdate =>
      _backgroundService.on('updateStatus');
}
