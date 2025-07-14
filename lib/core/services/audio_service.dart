import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Servicio para grabación de audio
class AudioService {
  final Logger _logger = Logger();
  FlutterSoundRecorder? _recorder;
  AudioSession? _audioSession;
  String? _tempPath;
  bool _isInitialized = false;
  bool _isDisposing = false;

  // Subscripciones a eventos
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  // Tiempo máximo para reintentos
  static const Duration _retryDelay = Duration(milliseconds: 800);
  static const int _maxRetries = 3;

  /// Inicializar el servicio de audio
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d('El servicio de audio ya está inicializado');
      return;
    }

    if (_isDisposing) {
      _logger.e(
        'El servicio está en proceso de liberación, no se puede inicializar',
      );
      return;
    }

    // Limpiar instancias previas si existen
    _logger.d('Limpiando recursos previos');
    await _releaseResources();

    try {
      _logger.d('Inicializando servicio de audio');

      // Verificar permisos de micrófono - Esencial para iOS
      _logger.d('Verificando permisos de micrófono - crítico para iOS');
      await _checkMicrophonePermission();
      _logger.d('Permisos de micrófono verificados correctamente');

      // Obtener directorio temporal para grabaciones
      _logger.d('Obteniendo directorio temporal...');
      final directory = await getTemporaryDirectory();
      _tempPath = directory.path;
      _logger.d('Directorio temporal obtenido: $_tempPath');

      // En iOS, verificar que el directorio existe y es accesible
      if (Platform.isIOS) {
        _logger.d('Verificando directorio temporal en iOS...');
        final dir = Directory(_tempPath!);
        if (!await dir.exists()) {
          _logger.e('El directorio temporal no existe: $_tempPath');
          try {
            await dir.create(recursive: true);
            _logger.d('Directorio temporal creado exitosamente');
          } catch (e) {
            _logger.e('Error al crear directorio temporal: $e');
            throw Exception('No se pudo crear el directorio temporal: $e');
          }
        } else {
          _logger.d('Directorio temporal ya existe');
        }

        // Verificar permisos de escritura intentando crear un archivo de prueba
        _logger.d('Verificando permisos de escritura...');
        try {
          final testFile = File('$_tempPath/test_audio_permissions.tmp');
          await testFile.writeAsString('test');
          await testFile.delete();
          _logger.d('Permisos de escritura verificados');
        } catch (e) {
          _logger.e('Error al verificar permisos de escritura: $e');
          _logger.e('Error al verificar permisos de escritura: $e');
          // Intentar usar un directorio alternativo
          try {
            _logger.d('Intentando directorio alternativo...');
            final docsDir = await getApplicationDocumentsDirectory();
            _tempPath = docsDir.path;
            _logger.d(
              'Usando directorio de documentos como alternativa: $_tempPath',
            );
          } catch (e2) {
            _logger.e('Error al obtener directorio alternativo: $e2');
            _logger.e('Error al obtener directorio alternativo: $e2');
            throw Exception(
              'No se pudo acceder a un directorio de escritura: $e, $e2',
            );
          }
        }
      } else {
        _logger.d('Plataforma Android, omitiendo verificaciones iOS');
      }

      // Configurar la sesión de audio antes de crear el grabador
      _logger.d('Configurando sesión de audio...');
      await _setupAudioSession();
      _logger.d('Sesión de audio configurada correctamente');

      // Crear e inicializar el grabador con reintentos
      _logger.d('Inicializando grabador...');
      await _initializeRecorder();
      _logger.d('Grabador inicializado correctamente');

      _isInitialized = true;
      _logger.d('Servicio de audio inicializado con éxito');
    } catch (e) {
      _logger.e('Error al inicializar servicio de audio: $e');
      _logger.e('Error al inicializar servicio de audio: $e');

      // Intentar liberar recursos en caso de error
      await _releaseResources();
      throw Exception('No se pudo inicializar el servicio de audio: $e');
    }
  }

  /// Verificar permiso de micrófono
  Future<void> _checkMicrophonePermission() async {
    _logger.d('Verificando permiso de micrófono');
    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      _logger.e('Permiso de micrófono no concedido: $status');
      throw RecordingPermissionException(
        'Se requiere permiso de micrófono para grabar audio',
      );
    }

    _logger.d('Permiso de micrófono concedido');
  }

  /// Configurar la sesión de audio (especialmente importante para iOS)
  Future<void> _setupAudioSession() async {
    try {
      _logger.d('Configurando sesión de audio básica');

      // Obtener la instancia singleton de AudioSession
      _logger.d('Obteniendo instancia de AudioSession...');
      _audioSession = await AudioSession.instance;
      _logger.d('Instancia de AudioSession obtenida');

      // Usar una configuración muy básica
      _logger.d('Configurando AudioSession con parámetros básicos...');
      await _audioSession!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
      _logger.d('AudioSession configurada con parámetros básicos');
      _logger.d('Sesión de audio configurada con parámetros básicos');

      // Activar la sesión
      _logger.d('Activando sesión de audio...');
      await _audioSession!.setActive(true);
      _logger.d('Sesión de audio activada');
      _logger.d('Sesión de audio activada');

      // Configurar manejo de interrupciones
      _logger.d('Configurando manejo de interrupciones...');
      _setupInterruptionHandling();
      _logger.d('Manejo de interrupciones configurado');
    } catch (e) {
      _logger.e('Error al configurar sesión de audio: $e');
      _logger.e('Error al configurar sesión de audio: $e');
      // Continuar incluso con error
    }
  }

  /// Configurar manejo de interrupciones
  void _setupInterruptionHandling() {
    _logger.d('Configurando manejo de interrupciones...');

    // Cancelar suscripciones previas si existen
    _logger.d('Cancelando suscripciones previas...');
    _interruptionSubscription?.cancel();
    _becomingNoisySubscription?.cancel();
    _logger.d('Suscripciones previas canceladas');

    // Suscribirse a interrupciones (llamadas telefónicas, otras apps, etc.)
    _logger.d('Configurando suscripción a interrupciones...');
    _interruptionSubscription = _audioSession!.interruptionEventStream.listen(
      _handleInterruption,
    );
    _logger.d('Suscripción a eventos de interrupción configurada');
    _logger.d('Suscripción a eventos de interrupción configurada');

    // Suscribirse a eventos de desconexión de auriculares
    _logger.d('Configurando suscripción a eventos de desconexión...');
    _becomingNoisySubscription = _audioSession!.becomingNoisyEventStream.listen(
      (_) {
        _logger.d('Detectada desconexión de auriculares');
        _logger.d('Detectada desconexión de auriculares');
        if (_recorder != null && _recorder!.isRecording) {
          _logger.d('Pausando grabación por desconexión de auriculares');
          _logger.d('Pausando grabación debido a desconexión de auriculares');
          _recorder!.pauseRecorder();
        }
      },
    );
    _logger.d('Suscripción a eventos de desconexión configurada');
    _logger.d('Suscripción a eventos de desconexión configurada');
  }

  /// Manejar interrupciones de audio
  void _handleInterruption(AudioInterruptionEvent event) {
    _logger.d('Interrupción de audio: ${event.begin}, tipo: ${event.type}');

    if (event.begin) {
      // Inicio de interrupción
      if (_recorder != null && _recorder!.isRecording) {
        _logger.d('Pausando grabación debido a interrupción de audio');
        _recorder!.pauseRecorder();
      }
    } else {
      // Fin de interrupción - no reanudamos automáticamente la grabación
      _logger.d('Interrupción de audio finalizada');
    }
  }

  /// Inicializar el grabador con reintentos
  Future<void> _initializeRecorder() async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetries) {
      attempts++;
      _logger.d('Intento $attempts de $_maxRetries para inicializar grabador');

      try {
        // Liberar recursos del grabador anterior si existe
        if (_recorder != null) {
          _logger.d('Liberando grabador anterior...');
          try {
            await _recorder!.closeRecorder();
            _logger.d('Grabador anterior liberado');
          } catch (e) {
            _logger.w('Error al liberar grabador anterior: $e');
          }
          _recorder = null;
        }

        // En iOS, configurar sesión de audio específicamente para grabación
        if (Platform.isIOS && _audioSession != null) {
          _logger.d('Configurando sesión de audio para iOS...');
          try {
            final isActive = await _audioSession!.setActive(true);
            if (!isActive) {
              _logger.w('No se pudo activar la sesión de audio');
              _logger.w(
                'No se pudo activar la sesión de audio antes de crear grabador',
              );
              // Intentar forzar la activación
              await Future.delayed(const Duration(milliseconds: 500));
              await _audioSession!.setActive(
                true,
                avAudioSessionSetActiveOptions:
                    AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
              );
              _logger.d('Sesión de audio forzada exitosamente');
            } else {
              _logger.d('Sesión de audio activada para iOS');
            }
          } catch (e) {
            _logger.e('Error al activar sesión de audio para grabador: $e');
            _logger.w('Error al activar sesión de audio para grabador: $e');
          }
        }

        // Crear nueva instancia del grabador con nivel de log bajo
        _logger.d('Creando nueva instancia de FlutterSoundRecorder...');
        _recorder = FlutterSoundRecorder(logLevel: Level.nothing);
        _logger.d('Instancia de FlutterSoundRecorder creada');

        // En iOS, hacer una pausa antes de abrir el grabador
        if (Platform.isIOS) {
          _logger.d('Pausa antes de abrir grabador en iOS...');
          await Future.delayed(const Duration(milliseconds: 300));
          _logger.d('Pausa completada');
        }

        // Abrir el grabador
        _logger.d('Abriendo grabador...');
        await _recorder!.openRecorder();
        _logger.d('Grabador abierto correctamente');
        _logger.d('Grabador abierto correctamente');

        // En iOS, verificar explícitamente que el grabador está listo
        if (Platform.isIOS) {
          _logger.d('Verificando que el grabador esté listo en iOS...');
          try {
            // Verificar que el grabador está listo haciendo una prueba sencilla
            _logger.d('Verificando estado del grabador...');
            _logger.d(
              'Verificando que el grabador esté realmente listo en iOS',
            );
            final isRecorderReady =
                _recorder != null && !_recorder!.isRecording;

            if (!isRecorderReady) {
              _logger.e('El grabador no está listo para usar');
              _logger.e('El grabador no está listo para usar');
              throw Exception('El grabador no está listo para usar');
            }

            // Esperar un momento adicional para estabilizar el grabador en iOS
            _logger.d('Esperando estabilización del grabador...');
            await Future.delayed(const Duration(milliseconds: 300));
            _logger.d('Grabador estabilizado correctamente');
          } catch (e) {
            _logger.e('Error al verificar el estado del grabador: $e');
            _logger.e('Error al verificar el estado del grabador: $e');
            throw e;
          }
        }

        // Si llegamos aquí, la inicialización fue exitosa
        _logger.d('Grabador inicializado exitosamente en intento $attempts');
        return;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        _logger.e('Error en intento $attempts: $e');
        _logger.e('Error en intento $attempts de inicialización: $e');

        if (attempts < _maxRetries) {
          _logger.d('Esperando antes del siguiente intento...');
          await Future.delayed(_retryDelay);
        }
      }
    }

    // Si llegamos aquí, todos los intentos fallaron
    _logger.e('Fallo en todos los intentos de inicialización');
    _logger.e('Fallo en todos los intentos de inicialización del grabador');
    throw lastException ??
        Exception('Error desconocido al inicializar grabador');
  }

  /// Comenzar a grabar audio
  Future<String?> startRecording(int durationInSeconds) async {
    _logger.d('Iniciando grabación de audio por $durationInSeconds segundos');

    if (_isDisposing) {
      _logger.e(
        'No se puede iniciar grabación durante la liberación de recursos',
      );
      _logger.e(
        'No se puede iniciar grabación durante la liberación de recursos',
      );
      return null;
    }

    if (!_isInitialized) {
      _logger.w(
        'El servicio de audio no está inicializado, inicializando ahora',
      );
      _logger.e('El servicio de audio no está inicializado');
      try {
        await initialize();
        _logger.d('Servicio de audio inicializado exitosamente');
      } catch (e) {
        _logger.e('Error al inicializar antes de grabar: $e');
        _logger.e('Error al inicializar antes de grabar: $e');
        return null;
      }
    }

    try {
      // Crear nombre de archivo único con prefijo descriptivo
      final DateTime now = DateTime.now();
      final String fileName = 'alert_audio_${now.millisecondsSinceEpoch}.aac';

      // Para iOS, asegurar que usamos el directorio de documentos que es más persistente
      String filePath;
      if (Platform.isIOS) {
        final Directory documentsDir = await getApplicationDocumentsDirectory();
        filePath = '${documentsDir.path}/$fileName';

        try {
          _logger.d('iOS: Configurando sesión de audio para grabación...');
          // Preparar la sesión de audio a través del canal nativo
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );

          // Primero detener cualquier engine actual
          try {
            await channel.invokeMethod('stopAudioEngine');
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            _logger.w('Error al detener motor de audio: $e');
          }

          // Usar el método específico para preparar grabación
          try {
            await channel.invokeMethod('prepareForRecording');
            await Future.delayed(const Duration(milliseconds: 800));
            _logger.d('Sesión de audio preparada para grabación');
          } catch (e) {
            _logger.w('Error al preparar sesión para grabación: $e');
            // Intentar fallback
            try {
              await channel.invokeMethod('configureAudioSession');
              await Future.delayed(const Duration(milliseconds: 500));
              _logger.d('Sesión de audio configurada con método alternativo');
            } catch (e2) {
              _logger.w('Error en método alternativo: $e2');
              // Continuar con flutter_sound directamente
            }
          }
        } catch (e) {
          _logger.w('Error al configurar sesión de audio en iOS: $e');
          // Continuar incluso con error, flutter_sound intentará configurar la sesión
        }
      } else {
        // Para Android, usar storage externo que es más persistente
        final Directory appDir = await getApplicationDocumentsDirectory();
        filePath = '${appDir.path}/$fileName';
      }

      _logger.d('Iniciando grabación en: $filePath');
      _logger.d('Iniciando grabación en: $filePath');

      // Verificar que el grabador está listo
      if (_recorder == null || _recorder!.isStopped == false) {
        _logger.w('Grabador no está listo, intentando reinicializar');
        _logger.w('Grabador no está listo, intentando reinicializar');
        await _initializeRecorder();
        await Future.delayed(const Duration(milliseconds: 500));
        _logger.d('Grabador reinicializado');
      }

      // ✅ VERIFICACIÓN DE ACCESO: Solo verificar que puede usar la funcionalidad
      // final bool hasPremium = IAPService.instance.hasPremium;
      // final bool isInTrial = IAPService.instance.isInTrial;
      // _logger.info(_tag, 'Estado Premium detectado: $hasPremium');
      // _logger.info(_tag, 'Estado Trial detectado: $isInTrial');

      // final bool hasAccess = hasPremium || isInTrial;
      // _logger.info(
      //   _tag,
      //   'Acceso calculado: $hasAccess (premium: $hasPremium, trial: $isInTrial)',
      // );

      // ⚠️ VERIFICACIÓN CRÍTICA: Asegurar que el usuario tiene acceso
      // if (!hasAccess) {
      //   _logger.error(
      //     _tag,
      //     '❌ ACCESO DENEGADO - No tiene premium ni trial',
      //   );
      //   _logger.error(
      //     _tag,
      //     '❌ hasPremium: $hasPremium, isInTrial: $isInTrial',
      //   );
      //   throw Exception(
      //     'Acceso denegado: se requiere suscripción premium o estar en período de prueba',
      //   );
      // }

      // _logger.success(
      //   _tag,
      //   '✅ ACCESO PERMITIDO - Continuando con grabación',
      // );

      // Configurar el codificador y bitrate apropiados para AAC
      const sampleRate = 44100;
      const numChannels = 1; // Mono para mejor calidad de voz
      const bitRate = 96000; // Mayor bitrate para mejor calidad

      _logger.d(
        'Configuración de audio - SampleRate: $sampleRate, Channels: $numChannels, BitRate: $bitRate',
      );

      // Iniciar grabación con parámetros optimizados según suscripción
      _logger.d('Iniciando grabador con codec AAC y parámetros configurados');
      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
        audioSource: AudioSource.microphone,
        sampleRate: sampleRate,
        numChannels: numChannels,
        bitRate: bitRate,
      );
      _logger.d('Grabador iniciado exitosamente');

      _logger.d('Grabando audio durante $durationInSeconds segundos');
      _logger.d('Grabando audio durante $durationInSeconds segundos');

      // Esperar a que termine la grabación después del tiempo especificado
      _logger.d(
        'Esperando $durationInSeconds segundos para completar grabación',
      );
      await Future.delayed(Duration(seconds: durationInSeconds));

      if (_recorder!.isRecording) {
        _logger.d('Grabación en curso, deteniendo grabación');
        if (Platform.isIOS) {
          _logger.d('Grabando audio en segundo plano para iOS...');
          _logger.d('Grabando audio en segundo plano para iOS...');
        }
        // Detener la grabación
        String? path = await _recorder!.stopRecorder();
        _logger.d('Grabación completada en: $path');
        _logger.d('Grabación completada: $path');

        // Verificar que el archivo existe y tiene tamaño adecuado
        final File audioFile = File(filePath);
        if (!await audioFile.exists()) {
          _logger.e('⛔ El archivo de audio no existe: $filePath');
          _logger.e('⛔ El archivo de audio no existe: $filePath');
          return null;
        }

        final int fileSize = await audioFile.length();
        _logger.d('Tamaño del archivo de audio: $fileSize bytes');
        _logger.d('Tamaño del archivo de audio: $fileSize bytes');

        if (fileSize < 1000) {
          // Menos de 1KB probablemente indica un error
          _logger.e('⛔ El archivo de audio es muy pequeño: $fileSize bytes');
          _logger.e('⛔ El archivo de audio es muy pequeño: $fileSize bytes');
          return null;
        }

        _logger.d('Archivo de audio válido generado exitosamente');
        return filePath;
      } else {
        _logger.e('⛔ La grabación se detuvo prematuramente');
        _logger.e('⛔ La grabación se detuvo prematuramente');
        return null;
      }
    } catch (e) {
      _logger.e('⛔ Error crítico al grabar audio: $e');
      _logger.e('⛔ Error al grabar audio: $e');
      return null;
    }
  }

  /// Liberar recursos internos sin desactivar completamente
  Future<void> _releaseResources() async {
    _logger.d('Liberando recursos internos');

    // Cancelar suscripciones
    if (_interruptionSubscription != null) {
      await _interruptionSubscription!.cancel();
      _interruptionSubscription = null;
    }

    if (_becomingNoisySubscription != null) {
      await _becomingNoisySubscription!.cancel();
      _becomingNoisySubscription = null;
    }

    // Liberar grabador si existe
    if (_recorder != null) {
      try {
        if (_recorder!.isRecording) {
          await _recorder!.stopRecorder();
        }
        await _recorder!.closeRecorder();
      } catch (e) {
        _logger.w('Error al liberar grabador: $e');
      }
      _recorder = null;
    }
  }

  /// Liberar todos los recursos
  Future<void> dispose() async {
    _logger.d('Liberando recursos de audio');
    _isDisposing = true;

    try {
      // Liberar recursos internos
      await _releaseResources();

      // En iOS, desactivar la sesión de audio completa y correctamente
      if (Platform.isIOS) {
        try {
          await Future.delayed(const Duration(milliseconds: 300));

          // Intentar la limpieza completa a través del canal nativo
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );

          // Intentar cada llamada por separado, capturando errores individualmente
          try {
            // Primero detener el motor de audio
            await channel.invokeMethod('stopAudioEngine');
            _logger.d('Motor de audio detenido desde Flutter');
          } catch (e) {
            _logger.w('Error al detener motor de audio: $e');
            // Continuar con el siguiente paso
          }

          await Future.delayed(const Duration(milliseconds: 300));

          try {
            // Luego llamar al método específico de limpieza completa
            final bool? cleanupResult = await channel.invokeMethod<bool>(
              'cleanupAudioResources',
            );

            if (cleanupResult == true) {
              _logger.d('Recursos de audio limpiados completamente en nativo');
            } else {
              _logger.w(
                'La limpieza nativa no fue exitosa, intentando método alternativo',
              );

              try {
                // Intentar desactivar la sesión como alternativa
                await channel.invokeMethod('deactivateAudioSession');
                _logger.d('Sesión de audio desactivada manualmente');
              } catch (deactivateError) {
                _logger.w('Error al desactivar sesión: $deactivateError');
                // Intentar un último enfoque con audio_session
              }
            }
          } catch (cleanupError) {
            _logger.w('Error en limpieza de recursos: $cleanupError');
            // Continuar con métodos alternativos
          }

          // Intentar a través de audio_session como último recurso
          if (_audioSession != null) {
            try {
              await _audioSession!.setActive(false);
              _logger.d(
                'Sesión de audio desactivada a través de audio_session',
              );
            } catch (sessionError) {
              _logger.w('Error con audio_session: $sessionError');
              // No hay más opciones, continuar con la liberación de recursos
            }
          }
        } catch (e) {
          _logger.e('Error al limpiar recursos de audio: $e');
          // Continuar con la liberación de referencias
        }
      }

      // Eliminar todas las referencias para asegurar que el GC las limpie
      _isInitialized = false;
      _audioSession = null;
      _tempPath = null;

      _logger.d('Recursos de audio liberados completamente');
    } catch (e) {
      _logger.e('Error fatal durante dispose: $e');
      // Asegurar que no quede en estado de disposición
    } finally {
      // Asegurar que siempre se reinicie el estado de disposición
      _isDisposing = false;
    }
  }
}
