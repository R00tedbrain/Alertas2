import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'dart:io' show Platform;

class PermissionService {
  // Logger
  final _logger = Logger();

  // Singleton
  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() => _instance;

  PermissionService._internal();

  // Verificar y solicitar todos los permisos necesarios
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final Map<Permission, PermissionStatus> permissionsStatus = {};

    // Ubicación
    permissionsStatus[Permission.location] =
        await Permission.location.request();

    // Ubicación en segundo plano (requiere primero aceptar ubicación normal)
    if (permissionsStatus[Permission.location]!.isGranted) {
      permissionsStatus[Permission.locationAlways] =
          await requestBackgroundLocationPermission();
    }

    // Micrófono - usamos nuestro método mejorado
    permissionsStatus[Permission.microphone] =
        await requestMicrophonePermission();

    // Notificaciones
    permissionsStatus[Permission.notification] =
        await Permission.notification.request();

    return permissionsStatus;
  }

  // Método mejorado para solicitar ubicación en segundo plano
  Future<PermissionStatus> requestBackgroundLocationPermission() async {
    try {
      var status = await Permission.locationAlways.status;
      print('Estado actual del permiso de ubicación en segundo plano: $status');

      // Si ya está concedido, no necesitamos solicitarlo de nuevo
      if (status.isGranted) {
        print('Permiso de ubicación en segundo plano ya concedido');
        return status;
      }

      // En iOS, debemos solicitar primero el permiso mientras se usa
      if (Platform.isIOS) {
        final whileInUseStatus = await Permission.locationWhenInUse.request();
        print('Estado de permiso mientras se usa: $whileInUseStatus');

        if (!whileInUseStatus.isGranted) {
          print(
            'No se puede solicitar ubicación en segundo plano sin permiso mientras se usa',
          );
          return whileInUseStatus;
        }

        // Solicitar el permiso 'siempre'
        print('Solicitando permiso de ubicación en segundo plano en iOS...');
        // En iOS, mostrar un diálogo explicativo primero es recomendado
        print(
          'Es recomendable que el usuario ya haya visto una explicación clara de por qué la app necesita acceso en segundo plano',
        );
      }

      // Solicitar permiso en segundo plano
      status = await Permission.locationAlways.request();
      print('Resultado de solicitud de ubicación en segundo plano: $status');

      return status;
    } catch (e) {
      print('Error al solicitar permiso de ubicación en segundo plano: $e');
      _logger.e('Error al solicitar permiso de ubicación en segundo plano: $e');
      // En caso de error, devolvemos el estado actual
      return await Permission.locationAlways.status;
    }
  }

  // Método especializado para solicitar permiso de micrófono
  Future<PermissionStatus> requestMicrophonePermission() async {
    try {
      // Primero verificamos el estado actual
      var status = await Permission.microphone.status;
      _logger.d('Estado actual del permiso de micrófono: $status');

      // Si ya está concedido, no necesitamos solicitarlo de nuevo
      if (status.isGranted) {
        _logger.d('Permiso de micrófono ya concedido');
        return status;
      }

      // Si está permanentemente denegado, redirigimos a configuraciones
      if (status.isPermanentlyDenied) {
        _logger.w(
          'Permiso de micrófono permanentemente denegado. Abriendo configuración...',
        );
        await openAppSettings();
        // Verificamos nuevamente después de que el usuario regrese de configuraciones
        return await Permission.microphone.status;
      }

      // Solicitamos el permiso
      _logger.d('Solicitando permiso de micrófono...');
      status = await Permission.microphone.request();
      _logger.d('Resultado de la solicitud de micrófono: $status');

      return status;
    } catch (e) {
      _logger.e('Error al solicitar permiso de micrófono: $e');
      // En caso de error, devolvemos el estado actual
      return await Permission.microphone.status;
    }
  }

  // Método especializado para solicitar permiso de ubicación
  Future<PermissionStatus> requestLocationPermission() async {
    try {
      // Primero verificamos el estado actual
      var status = await Permission.location.status;
      _logger.d('Estado actual del permiso de ubicación: $status');

      // Si ya está concedido, no necesitamos solicitarlo de nuevo
      if (status.isGranted) {
        _logger.d('Permiso de ubicación ya concedido');
        return status;
      }

      // Si está permanentemente denegado, redirigimos a configuraciones
      if (status.isPermanentlyDenied) {
        _logger.w(
          'Permiso de ubicación permanentemente denegado. Abriendo configuración...',
        );
        await openAppSettings();
        // Verificamos nuevamente después de que el usuario regrese de configuraciones
        return await Permission.location.status;
      }

      // Solicitamos el permiso
      _logger.d('Solicitando permiso de ubicación...');
      status = await Permission.location.request();
      _logger.d('Resultado de la solicitud de ubicación: $status');

      return status;
    } catch (e) {
      _logger.e('Error al solicitar permiso de ubicación: $e');
      // En caso de error, devolvemos el estado actual
      return await Permission.location.status;
    }
  }

  // Verificar si todos los permisos están concedidos
  Future<bool> areAllPermissionsGranted() async {
    // Verificar ubicación
    final locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) return false;

    // Verificar ubicación en segundo plano
    final locationAlwaysStatus = await Permission.locationAlways.status;
    if (!locationAlwaysStatus.isGranted) return false;

    // Verificar micrófono
    final microphoneStatus = await Permission.microphone.status;
    if (!microphoneStatus.isGranted) return false;

    // Verificar notificaciones
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) return false;

    return true;
  }

  // Verificar permisos individuales
  Future<bool> isLocationPermissionGranted() async {
    return await Permission.location.isGranted;
  }

  Future<bool> isBackgroundLocationPermissionGranted() async {
    return await Permission.locationAlways.isGranted;
  }

  Future<bool> isMicrophonePermissionGranted() async {
    final status = await Permission.microphone.status;
    _logger.d('Estado actual del permiso de micrófono: $status');
    return status.isGranted;
  }

  Future<bool> isNotificationPermissionGranted() async {
    return await Permission.notification.isGranted;
  }

  // Abrir configuración de la aplicación
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      _logger.e('Error al abrir configuración: $e');
      return false;
    }
  }
}
