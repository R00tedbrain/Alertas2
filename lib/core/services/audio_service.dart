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
      _logger.d('Configurando sesión de audio para iOS');

      // Obtener la instancia singleton de AudioSession
      _audioSession = await AudioSession.instance;

      // En iOS, usar el canal nativo para configurar la sesión de audio
      if (Platform.isIOS) {
        try {
          // Intentar configurar la sesión de audio a través del canal nativo
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );
          final bool? result = await channel.invokeMethod<bool>(
            'configureAudioSession',
          );

          if (result == true) {
            _logger.d('Sesión de audio configurada a través del canal nativo');
            // Esperar un momento para que la configuración surta efecto
            await Future.delayed(const Duration(milliseconds: 300));
          } else {
            _logger.w(
              'No se pudo configurar la sesión de audio a través del canal nativo',
            );
            // Continuar con el enfoque basado en audio_session
          }
        } catch (e) {
          _logger.w('Error al configurar sesión a través del canal nativo: $e');
          // Continuar con el enfoque basado en audio_session
        }
      }

      // Configurar la sesión con parámetros optimizados para grabación
      await _audioSession!.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      _logger.d('Sesión de audio configurada');

      // Activar la sesión de audio ahora
      if (Platform.isIOS) {
        try {
          // Intentar activar a través del canal nativo primero
          const MethodChannel channel = MethodChannel(
            'com.alerta.telegram/background_tasks',
          );
          final bool? activationResult = await channel.invokeMethod<bool>(
            'activateAudioSession',
          );

          if (activationResult == true) {
            _logger.d('Sesión de audio activada a través del canal nativo');
          } else {
            _logger.w(
              'No se pudo activar a través del canal nativo, usando audio_session',
            );
            await Future.delayed(const Duration(milliseconds: 200));
            final result = await _audioSession!.setActive(true);
            if (result) {
              _logger.d(
                'Sesión de audio activada correctamente a través de audio_session',
              );
            } else {
              _logger.w(
                'No se pudo activar la sesión de audio a través de audio_session',
              );
            }
          }
        } catch (e) {
          _logger.w('Error al activar a través del canal nativo: $e');
          // Intentar activar a través de audio_session
          await Future.delayed(const Duration(milliseconds: 200));
          final result = await _audioSession!.setActive(true);
          if (result) {
            _logger.d(
              'Sesión de audio activada correctamente a través de audio_session',
            );
          } else {
            _logger.w(
              'No se pudo activar la sesión de audio a través de audio_session',
            );
          }
        }
      } else {
        // Para Android, usar audio_session directamente
        await Future.delayed(const Duration(milliseconds: 200));
        final result = await _audioSession!.setActive(true);
        if (result) {
          _logger.d('Sesión de audio activada correctamente');
        } else {
          _logger.w('No se pudo activar la sesión de audio');
        }
      }

      // Configurar manejo de interrupciones
      _setupInterruptionHandling();
    } catch (e) {
      _logger.e('Error al configurar sesión de audio: $e');
      throw e;
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
          await Future.delayed(_retryDelay);

          // Recrear el grabador para el reintento
          _recorder?.closeRecorder().catchError(
            (e) => _logger.w('Error al cerrar grabador: $e'),
          );
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Crear nueva instancia del grabador con nivel de log bajo
        _recorder = FlutterSoundRecorder(logLevel: Level.nothing);

        // Abrir el grabador
        await _recorder!.openRecorder();
        _logger.d('Grabador abierto correctamente');

        // Si llegamos aquí, la inicialización fue exitosa
        return;
      } catch (e) {
        _logger.e(
          'Error al inicializar grabador (intento ${attempts + 1}): $e',
        );
        attempts++;

        if (attempts >= _maxRetries) {
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
      // En iOS, asegurarse de que la sesión de audio está activa
      if (Platform.isIOS) {
        try {
          if (_audioSession != null) {
            await _audioSession!.setActive(true);
          }
        } catch (e) {
          _logger.w('Error al activar sesión de audio: $e');
        }
      }

      // Crear nombre de archivo único
      final DateTime now = DateTime.now();
      final String fileName = 'audio_${now.millisecondsSinceEpoch}.aac';
      final String filePath = '$_tempPath/$fileName';

      _logger.d('Iniciando grabación en: $filePath');

      // Ajustar duración para iOS si es necesario
      final adjustedDuration =
          Platform.isIOS && durationInSeconds > 20
              ? 20 // máximo 20 segundos en iOS para evitar problemas
              : durationInSeconds;

      // Iniciar grabación
      await _recorder!.startRecorder(toFile: filePath, codec: Codec.aacADTS);

      // Esperar tiempo de grabación
      await Future.delayed(Duration(seconds: adjustedDuration));

      // Detener grabación
      final path = await _recorder!.stopRecorder();
      _logger.d('Grabación completada: $path');

      return path;
    } catch (e) {
      _logger.e('Error al grabar audio: $e');

      // Intentar recuperarse del error
      try {
        if (_recorder != null && _recorder!.isRecording) {
          await _recorder!.stopRecorder();
        }
      } catch (stopError) {
        _logger.e('Error adicional al detener grabación: $stopError');
      }

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
