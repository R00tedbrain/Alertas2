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
      _logger.d(
        'El servicio está en proceso de liberación, no se puede inicializar',
      );
      return;
    }

    // Limpiar instancias previas si existen
    await _releaseResources();

    try {
      _logger.d('Inicializando servicio de audio');

      // Verificar permisos de micrófono - Esencial para iOS
      await _checkMicrophonePermission();

      // Obtener directorio temporal para grabaciones
      final directory = await getTemporaryDirectory();
      _tempPath = directory.path;
      _logger.d('Directorio temporal: $_tempPath');

      // En iOS, verificar que el directorio existe y es accesible
      if (Platform.isIOS) {
        final dir = Directory(_tempPath!);
        if (!await dir.exists()) {
          _logger.e('El directorio temporal no existe: $_tempPath');
          try {
            await dir.create(recursive: true);
            _logger.d('Directorio temporal creado');
          } catch (e) {
            _logger.e('Error al crear directorio temporal: $e');
            throw Exception('No se pudo crear el directorio temporal: $e');
          }
        }

        // Verificar permisos de escritura intentando crear un archivo de prueba
        try {
          final testFile = File('$_tempPath/test_audio_permissions.tmp');
          await testFile.writeAsString('test');
          await testFile.delete();
          _logger.d('Permisos de escritura verificados en directorio temporal');
        } catch (e) {
          _logger.e('Error al verificar permisos de escritura: $e');
          // Intentar usar un directorio alternativo
          try {
            final docsDir = await getApplicationDocumentsDirectory();
            _tempPath = docsDir.path;
            _logger.d(
              'Usando directorio de documentos como alternativa: $_tempPath',
            );
          } catch (e2) {
            _logger.e('Error al obtener directorio alternativo: $e2');
            throw Exception(
              'No se pudo acceder a un directorio de escritura: $e, $e2',
            );
          }
        }
      }

      // Configurar la sesión de audio antes de crear el grabador
      await _setupAudioSession();

      // Crear e inicializar el grabador con reintentos
      await _initializeRecorder();

      _isInitialized = true;
      _logger.d('Servicio de audio inicializado con éxito');
    } catch (e) {
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
      _audioSession = await AudioSession.instance;

      // Usar una configuración muy básica
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

      _logger.d('Sesión de audio configurada con parámetros básicos');

      // Activar la sesión
      await _audioSession!.setActive(true);
      _logger.d('Sesión de audio activada');

      // Configurar manejo de interrupciones
      _setupInterruptionHandling();
    } catch (e) {
      _logger.e('Error al configurar sesión de audio: $e');
      // Continuar incluso con error
    }
  }

  /// Configurar manejo de interrupciones
  void _setupInterruptionHandling() {
    // Cancelar suscripciones previas si existen
    _interruptionSubscription?.cancel();
    _becomingNoisySubscription?.cancel();

    // Suscribirse a interrupciones (llamadas telefónicas, otras apps, etc.)
    _interruptionSubscription = _audioSession!.interruptionEventStream.listen(
      _handleInterruption,
    );
    _logger.d('Suscripción a eventos de interrupción configurada');

    // Suscribirse a eventos de desconexión de auriculares
    _becomingNoisySubscription = _audioSession!.becomingNoisyEventStream.listen(
      (_) {
        _logger.d('Detectada desconexión de auriculares');
        if (_recorder != null && _recorder!.isRecording) {
          _logger.d('Pausando grabación debido a desconexión de auriculares');
          _recorder!.pauseRecorder();
        }
      },
    );
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

    while (attempts < _maxRetries) {
      try {
        // Si no es el primer intento, esperar antes de reintentar
        if (attempts > 0) {
          _logger.d(
            'Reintentando inicialización del grabador (intento ${attempts + 1}/$_maxRetries)',
          );
          // Aumentar el tiempo de espera para iOS
          if (Platform.isIOS) {
            await Future.delayed(
              Duration(milliseconds: _retryDelay.inMilliseconds * 2),
            );
          } else {
            await Future.delayed(_retryDelay);
          }

          // Recrear el grabador para el reintento
          if (_recorder != null) {
            try {
              if (_recorder!.isRecording) {
                await _recorder!.stopRecorder();
              }
              await _recorder!.closeRecorder();
            } catch (closeError) {
              _logger.w('Error al cerrar grabador para reintento: $closeError');
            }
            _recorder = null;

            // En iOS, esperar más tiempo después de cerrar el grabador
            if (Platform.isIOS) {
              await Future.delayed(const Duration(seconds: 1));
            } else {
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }
        }

        // Verificar que la sesión de audio está activa antes de crear el grabador
        if (Platform.isIOS && _audioSession != null) {
          try {
            final isActive = await _audioSession!.setActive(true);
            if (!isActive) {
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
            }
          } catch (e) {
            _logger.w('Error al activar sesión de audio para grabador: $e');
          }
        }

        // Crear nueva instancia del grabador con nivel de log bajo
        _recorder = FlutterSoundRecorder(logLevel: Level.nothing);

        // En iOS, hacer una pausa antes de abrir el grabador
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Abrir el grabador
        await _recorder!.openRecorder();
        _logger.d('Grabador abierto correctamente');

        // En iOS, verificar explícitamente que el grabador está listo
        if (Platform.isIOS) {
          try {
            // Verificar que el grabador está listo haciendo una prueba sencilla
            _logger.d(
              'Verificando que el grabador esté realmente listo en iOS',
            );
            final isRecorderReady =
                _recorder != null && !_recorder!.isRecording;

            if (!isRecorderReady) {
              _logger.e('El grabador no está listo para usar');
              throw Exception('El grabador no está listo para usar');
            }

            // Esperar un momento adicional para estabilizar el grabador en iOS
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            _logger.e('Error al verificar el estado del grabador: $e');
            throw e;
          }
        }

        // Si llegamos aquí, la inicialización fue exitosa
        return;
      } catch (e) {
        _logger.e(
          'Error al inicializar grabador (intento ${attempts + 1}): $e',
        );
        attempts++;

        if (attempts >= _maxRetries) {
          // En iOS, intentar un enfoque alternativo en el último intento
          if (Platform.isIOS && attempts == _maxRetries) {
            _logger.d(
              'Intentando enfoque alternativo para iOS como último recurso',
            );
            try {
              // Desactivar completamente la sesión de audio y volver a activarla
              if (_audioSession != null) {
                await _audioSession!.setActive(false);
                await Future.delayed(const Duration(seconds: 2));
                await _audioSession!.setActive(true);
              }

              // Recrear el grabador con opciones mínimas
              _recorder = FlutterSoundRecorder(logLevel: Level.nothing);
              await Future.delayed(const Duration(seconds: 1));
              await _recorder!.openRecorder();

              _logger.d('Grabador inicializado con enfoque alternativo');
              return;
            } catch (finalError) {
              _logger.e('Error en intento final alternativo: $finalError');
            }
          }

          throw Exception(
            'No se pudo inicializar el grabador después de $_maxRetries intentos: $e',
          );
        }
      }
    }
  }

  /// Comenzar a grabar audio
  Future<String?> startRecording(int durationInSeconds) async {
    if (_isDisposing) {
      _logger.e(
        'No se puede iniciar grabación durante la liberación de recursos',
      );
      return null;
    }

    if (!_isInitialized) {
      _logger.e('El servicio de audio no está inicializado');
      try {
        await initialize();
      } catch (e) {
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

      // Verificar que el grabador está listo
      if (_recorder == null || _recorder!.isStopped == false) {
        _logger.w('Grabador no está listo, intentando reinicializar');
        await _initializeRecorder();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Configurar el codificador y bitrate apropiados para AAC
      const sampleRate = 44100;
      const numChannels = 1; // Mono para mejor calidad de voz
      const bitRate = 96000; // Mayor bitrate para mejor calidad

      // Iniciar grabación con parámetros optimizados
      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
        audioSource: AudioSource.microphone,
        sampleRate: sampleRate,
        numChannels: numChannels,
        bitRate: bitRate,
      );

      _logger.d('Grabando audio durante $durationInSeconds segundos');

      // Esperar a que termine la grabación después del tiempo especificado
      await Future.delayed(Duration(seconds: durationInSeconds));

      if (_recorder!.isRecording) {
        if (Platform.isIOS) {
          _logger.d('Grabando audio en segundo plano para iOS...');
        }
        // Detener la grabación
        String? path = await _recorder!.stopRecorder();
        _logger.d('Grabación completada: $path');

        // Verificar que el archivo existe y tiene tamaño adecuado
        final File audioFile = File(filePath);
        if (!await audioFile.exists()) {
          _logger.e('⛔ El archivo de audio no existe: $filePath');
          return null;
        }

        final int fileSize = await audioFile.length();
        _logger.d('Tamaño del archivo de audio: $fileSize bytes');

        if (fileSize < 1000) {
          // Menos de 1KB probablemente indica un error
          _logger.e('⛔ El archivo de audio es muy pequeño: $fileSize bytes');
          return null;
        }

        return filePath;
      } else {
        _logger.e('⛔ La grabación se detuvo prematuramente');
        return null;
      }
    } catch (e) {
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

    // Liberar recursos internos
    await _releaseResources();

    // En iOS, desactivar la sesión de audio explícitamente
    if (Platform.isIOS && _audioSession != null) {
      try {
        await Future.delayed(const Duration(milliseconds: 300));

        // Intentar desactivar a través del canal nativo primero
        try {
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );
          final bool? deactivationResult = await channel.invokeMethod<bool>(
            'deactivateAudioSession',
          );

          if (deactivationResult == true) {
            _logger.d('Sesión de audio desactivada a través del canal nativo');
          } else {
            _logger.w(
              'No se pudo desactivar a través del canal nativo, usando audio_session',
            );
            await _audioSession!.setActive(false);
            _logger.d('Sesión de audio desactivada a través de audio_session');
          }
        } catch (channelError) {
          _logger.w(
            'Error al desactivar a través del canal nativo: $channelError',
          );
          // Intentar a través de audio_session
          await _audioSession!.setActive(false);
          _logger.d('Sesión de audio desactivada a través de audio_session');
        }
      } catch (e) {
        _logger.e('Error al desactivar sesión de audio: $e');
      }
    }

    _isInitialized = false;
    _audioSession = null;
    _tempPath = null;
    _isDisposing = false;

    _logger.d('Recursos de audio liberados completamente');
  }
}
