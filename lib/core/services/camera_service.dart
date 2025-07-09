import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

/// Servicio para captura de fotos con cámara frontal y posterior
class CameraService {
  final Logger _logger = Logger();

  List<CameraDescription>? _cameras;
  CameraController? _frontCameraController;
  CameraController? _backCameraController;
  String? _tempPath;
  bool _isInitialized = false;
  bool _isDisposing = false;

  // Tiempo máximo para reintentos
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const int _maxRetries = 3;

  /// Inicializar el servicio de cámara
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.d('El servicio de cámara ya está inicializado');
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
      _logger.d('Inicializando servicio de cámara');

      // Verificar permisos de cámara (sin solicitar automáticamente)
      await _checkCameraPermission();

      // Obtener directorio temporal para imágenes
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
          final testFile = File('$_tempPath/test_camera_permissions.tmp');
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

      // Obtener cámaras disponibles
      await _initializeCameras();

      _isInitialized = true;
      _logger.d('Servicio de cámara inicializado con éxito');
    } catch (e) {
      _logger.e('Error al inicializar servicio de cámara: $e');

      // Intentar liberar recursos en caso de error
      await _releaseResources();
      throw Exception('No se pudo inicializar el servicio de cámara: $e');
    }
  }

  /// Verificar permiso de cámara
  Future<void> _checkCameraPermission() async {
    _logger.d('Verificando permiso de cámara');
    final status = await Permission.camera.status;

    if (status != PermissionStatus.granted) {
      _logger.e('Permiso de cámara no concedido: $status');
      if (status == PermissionStatus.permanentlyDenied) {
        throw CameraPermissionException(
          'El permiso de cámara está permanentemente denegado. Ve a Configuración > Alerta Telegram > Cámara para habilitarlo.',
        );
      } else {
        throw CameraPermissionException(
          'Se requiere permiso de cámara para tomar fotos. El permiso se debe solicitar al iniciar la app.',
        );
      }
    }

    _logger.d('Permiso de cámara concedido');
  }

  /// Inicializar cámaras disponibles
  Future<void> _initializeCameras() async {
    try {
      _logger.d('🔄 Obteniendo cámaras disponibles');
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No se encontraron cámaras disponibles');
      }

      _logger.d('📱 Cámaras encontradas: ${_cameras!.length}');

      // Encontrar cámara frontal y posterior
      CameraDescription? frontCamera;
      CameraDescription? backCamera;

      for (final camera in _cameras!) {
        _logger.d(
          '   📸 Cámara detectada: ${camera.name} (${camera.lensDirection})',
        );
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          _logger.d('✅ Cámara frontal encontrada: ${camera.name}');
        } else if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          _logger.d('✅ Cámara posterior encontrada: ${camera.name}');
        }
      }

      // Inicializar controladores de cámara
      if (frontCamera != null) {
        _logger.d('⏳ Inicializando controlador de cámara frontal');
        await _initializeCameraController(frontCamera, true);
      } else {
        _logger.w('⚠️ No se encontró cámara frontal');
      }

      if (backCamera != null) {
        _logger.d('⏳ Inicializando controlador de cámara posterior');
        await _initializeCameraController(backCamera, false);
      } else {
        _logger.w('⚠️ No se encontró cámara posterior');
      }

      if (_frontCameraController == null && _backCameraController == null) {
        throw Exception('No se pudo inicializar ninguna cámara');
      }

      _logger.d('✅ Controladores de cámara inicializados');
      _logger.d('📊 Estado final:');
      _logger.d(
        '   - Cámara frontal: ${_frontCameraController != null ? "✅ Inicializada" : "❌ No inicializada"}',
      );
      _logger.d(
        '   - Cámara posterior: ${_backCameraController != null ? "✅ Inicializada" : "❌ No inicializada"}',
      );
    } catch (e) {
      _logger.e('Error al inicializar cámaras: $e');
      rethrow;
    }
  }

  /// Inicializar controlador de cámara específico
  Future<void> _initializeCameraController(
    CameraDescription camera,
    bool isFront,
  ) async {
    final cameraType = isFront ? 'frontal' : 'posterior';

    try {
      _logger.d('🔄 Creando controlador de cámara $cameraType');

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false, // Sin audio para las fotos
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _logger.d('⏳ Inicializando controlador de cámara $cameraType');
      await controller.initialize();

      if (controller.value.isInitialized) {
        if (isFront) {
          _frontCameraController = controller;
          _logger.d(
            '✅ Controlador de cámara frontal inicializado correctamente',
          );
        } else {
          _backCameraController = controller;
          _logger.d(
            '✅ Controlador de cámara posterior inicializado correctamente',
          );
        }
      } else {
        _logger.e(
          '❌ Controlador de cámara $cameraType no se inicializó correctamente',
        );
      }
    } catch (e) {
      _logger.e('❌ Error al inicializar controlador de cámara $cameraType: $e');
      _logger.e('   Stack trace: ${StackTrace.current}');
      // No lanzar excepción, permitir que al menos una cámara funcione
    }
  }

  /// Tomar foto con cámara frontal
  Future<File?> takeFrontPhoto() async {
    return await _takePhoto(_frontCameraController, 'front');
  }

  /// Tomar foto con cámara posterior
  Future<File?> takeBackPhoto() async {
    return await _takePhoto(_backCameraController, 'back');
  }

  /// Tomar fotos con ambas cámaras
  Future<List<File>> takeBothPhotos() async {
    final List<File> photos = [];

    try {
      _logger.d('🔄 Iniciando captura de fotos con ambas cámaras');

      // Tomar foto frontal
      _logger.d('📸 Intentando tomar foto frontal');
      final frontPhoto = await takeFrontPhoto();
      if (frontPhoto != null) {
        photos.add(frontPhoto);
        _logger.d('✅ Foto frontal capturada exitosamente');
      } else {
        _logger.w('❌ No se pudo tomar foto frontal');
      }

      // Tomar foto posterior
      _logger.d('📸 Intentando tomar foto posterior');
      final backPhoto = await takeBackPhoto();
      if (backPhoto != null) {
        photos.add(backPhoto);
        _logger.d('✅ Foto posterior capturada exitosamente');
      } else {
        _logger.w('❌ No se pudo tomar foto posterior');
      }

      _logger.d('📊 Total de fotos tomadas: ${photos.length}');
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final photoType =
            photo.path.contains('front') ? 'frontal' : 'posterior';
        _logger.d('   📸 Foto $i: $photoType (${photo.path})');
      }

      return photos;
    } catch (e) {
      _logger.e('Error al tomar fotos: $e');
      return photos; // Devolver las fotos que se pudieron tomar
    }
  }

  /// Tomar foto con controlador específico
  Future<File?> _takePhoto(
    CameraController? controller,
    String cameraType,
  ) async {
    if (!_isInitialized) {
      _logger.e('El servicio de cámara no está inicializado');
      return null;
    }

    if (controller == null || !controller.value.isInitialized) {
      _logger.e('Controlador de cámara $cameraType no está disponible');
      return null;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'emergency_photo_${cameraType}_$timestamp.jpg';
      final filePath = '$_tempPath/$fileName';

      _logger.d('Tomando foto $cameraType: $filePath');

      final XFile photo = await controller.takePicture();
      final File photoFile = File(filePath);

      // Copiar la foto al directorio temporal
      await photo.saveTo(filePath);

      _logger.d('Foto $cameraType guardada: $filePath');
      return photoFile;
    } catch (e) {
      _logger.e('Error al tomar foto $cameraType: $e');
      return null;
    }
  }

  /// Liberar recursos
  Future<void> _releaseResources() async {
    _logger.d('Liberando recursos de cámara');
    _isDisposing = true;

    try {
      await _frontCameraController?.dispose();
      _frontCameraController = null;

      await _backCameraController?.dispose();
      _backCameraController = null;

      _logger.d('Recursos de cámara liberados');
    } catch (e) {
      _logger.e('Error al liberar recursos de cámara: $e');
    } finally {
      _isDisposing = false;
    }
  }

  /// Liberar el servicio
  Future<void> dispose() async {
    if (!_isInitialized) {
      _logger.d('El servicio de cámara no está inicializado');
      return;
    }

    await _releaseResources();
    _isInitialized = false;
    _logger.d('Servicio de cámara liberado');
  }

  /// Verificar si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Verificar si hay cámara frontal disponible
  bool get hasFrontCamera => _frontCameraController != null;

  /// Verificar si hay cámara posterior disponible
  bool get hasBackCamera => _backCameraController != null;
}

/// Excepción para errores de permisos de cámara
class CameraPermissionException implements Exception {
  final String message;
  CameraPermissionException(this.message);

  @override
  String toString() => 'CameraPermissionException: $message';
}
