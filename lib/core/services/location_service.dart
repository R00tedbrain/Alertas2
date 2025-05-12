import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:io' show Platform;

@pragma('vm:entry-point')
class LocationService {
  // Logger
  final _logger = Logger();

  // Singleton
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal() {
    print('LocationService interno creado');
  }

  // Obtener ubicación actual con manejo mejorado para iOS
  Future<Position?> getCurrentLocation() async {
    try {
      // Comprobar si los servicios de ubicación están habilitados
      print('Verificando si los servicios de ubicación están habilitados...');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('ERROR: Los servicios de ubicación están desactivados');
        _logger.e('Los servicios de ubicación están desactivados');

        // Intento de recuperación para iOS
        if (Platform.isIOS) {
          print('Intentando abrir configuración de ubicación en iOS...');
          await Geolocator.openLocationSettings();
          // Esperamos un poco para dar tiempo al usuario
          await Future.delayed(const Duration(seconds: 2));
          // Verificamos nuevamente
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            print(
              'Servicios de ubicación siguen desactivados después del intento',
            );
            return null;
          }
        } else {
          return null;
        }
      }
      print('Servicios de ubicación habilitados: $serviceEnabled');

      // Verificar permisos
      print('Verificando permisos de ubicación...');
      LocationPermission permission = await Geolocator.checkPermission();
      print('Estado actual del permiso de ubicación: $permission');

      if (permission == LocationPermission.denied) {
        print('Permiso de ubicación denegado, solicitando permiso...');
        permission = await Geolocator.requestPermission();
        print('Nuevo estado del permiso después de solicitar: $permission');

        if (permission == LocationPermission.denied) {
          print('ERROR: Permisos de ubicación rechazados por el usuario');
          _logger.e('Permisos de ubicación rechazados');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('ERROR: Permisos de ubicación rechazados permanentemente');
        _logger.e('Permisos de ubicación rechazados permanentemente');

        // Intento de abrir configuración para iOS
        if (Platform.isIOS) {
          print('Abriendo configuración para revisar permisos en iOS...');
          await Geolocator.openAppSettings();
        }
        return null;
      }

      // Verificar el permiso en segundo plano para iOS
      // iOS requiere permiso 'always' para funcionar en segundo plano
      if (permission == LocationPermission.whileInUse && Platform.isIOS) {
        print('ADVERTENCIA: Permiso de ubicación solo mientras se usa la app');
        print('En iOS, intentando solicitar permiso "always"...');

        // En iOS primero hay que tener "whenInUse" para luego solicitar "always"
        await _requestBackgroundLocationPermission();

        // Verificamos si se concedió el permiso "always"
        permission = await Geolocator.checkPermission();
        print(
          'Nuevo estado del permiso después de solicitar always: $permission',
        );
      }

      // Obtener la ubicación actual con manejo específico para iOS
      print('Intentando obtener la posición actual con alta precisión...');

      try {
        // Para iOS, se añade un manejo específico para los errores kCLErrorDomain
        if (Platform.isIOS) {
          // En iOS, primero intentamos con precisión baja para evitar timeout
          print('iOS detectado: intentando primero con precisión baja...');
          try {
            final initialPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 5),
            );

            print('Posición inicial obtenida con baja precisión:');
            print('  - Latitud: ${initialPosition.latitude}');
            print('  - Longitud: ${initialPosition.longitude}');

            // Ahora intentamos con alta precisión
            try {
              final highAccuracyPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 10),
              );

              print('Posición refinada con alta precisión:');
              print('  - Latitud: ${highAccuracyPosition.latitude}');
              print('  - Longitud: ${highAccuracyPosition.longitude}');

              return highAccuracyPosition;
            } catch (e) {
              // Si falla la alta precisión, usamos la posición inicial
              print('No se pudo obtener posición de alta precisión: $e');
              print('Usando la posición de baja precisión...');
              return initialPosition;
            }
          } catch (e) {
            print('Error al obtener posición inicial en iOS: $e');
            // Si falla completamente, manejamos el error más abajo
          }
        }

        // Comportamiento estándar (para Android u otros casos)
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        print('Posición obtenida correctamente:');
        print('  - Latitud: ${position.latitude}');
        print('  - Longitud: ${position.longitude}');
        print('  - Precisión: ${position.accuracy} metros');
        print('  - Altitud: ${position.altitude} metros');

        return position;
      } on TimeoutException catch (e) {
        print('ERROR: Timeout al obtener la ubicación: $e');
        _logger.e('Timeout al obtener la ubicación');
        return null;
      } on LocationServiceDisabledException catch (e) {
        print(
          'ERROR: Servicio de ubicación deshabilitado durante la solicitud: $e',
        );
        _logger.e('Servicio de ubicación deshabilitado durante la solicitud');
        return null;
      }
    } catch (e) {
      print('ERROR al obtener la ubicación: $e');

      // Verificar si es un error específico de iOS
      if (e.toString().contains('kCLErrorDomain')) {
        print('Error de CoreLocation en iOS: $e');

        // kCLErrorDomain error 1 es típicamente un problema de autorización
        if (e.toString().contains('error 1')) {
          print('Error de autorización de ubicación en iOS');
          print('Intentando solicitar permisos específicos para iOS...');

          // Para error 1, necesitamos solicitar permisos correctamente en iOS
          await _requestSpecificIOSLocationPermissions();

          // Reintentar después de solicitar permisos
          print(
            'Reintentando obtener ubicación después de solicitar permisos...',
          );

          // Esperamos un poco para dar tiempo al sistema
          await Future.delayed(const Duration(seconds: 1));

          try {
            final retryPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 5),
            );
            print('Ubicación obtenida en el reintento:');
            print('  - Latitud: ${retryPosition.latitude}');
            print('  - Longitud: ${retryPosition.longitude}');
            return retryPosition;
          } catch (retryError) {
            print('Error en el reintento de ubicación: $retryError');
          }
        }

        // Intentar abrir la configuración como último recurso
        print('Intentando abrir la configuración del dispositivo...');
        await Geolocator.openLocationSettings();
      }

      _logger.e('Error al obtener la ubicación: $e');
      return null;
    }
  }

  // Método específico para solicitar permisos de ubicación en iOS
  Future<void> _requestSpecificIOSLocationPermissions() async {
    if (Platform.isIOS) {
      print('Solicitando permisos específicos para iOS...');

      // Primero, verificamos el estado actual
      LocationPermission currentStatus = await Geolocator.checkPermission();
      print('Estado actual del permiso: $currentStatus');

      // iOS requiere primero 'whenInUse' antes de poder solicitar 'always'
      if (currentStatus != LocationPermission.whileInUse &&
          currentStatus != LocationPermission.always) {
        print('Solicitando permiso mientras se usa (whenInUse)...');
        final whileInUseStatus = await Geolocator.requestPermission();
        print('Resultado de solicitud whenInUse: $whileInUseStatus');

        // Si el usuario deniega este permiso, no podemos continuar
        if (whileInUseStatus == LocationPermission.denied ||
            whileInUseStatus == LocationPermission.deniedForever) {
          print(
            'El usuario denegó el permiso whenInUse, no se puede continuar',
          );
          return;
        }
      }

      // Si ya tenemos 'whileInUse', podemos solicitar 'always'
      if (currentStatus == LocationPermission.whileInUse) {
        print('Solicitando permiso de segundo plano (always)...');
        print('NOTA: iOS mostrará un diálogo al usuario para este permiso');

        try {
          // En iOS, esto mostrará el diálogo de ubicación en segundo plano
          await Geolocator.requestPermission();

          // Verificamos el resultado
          final newStatus = await Geolocator.checkPermission();
          print(
            'Nuevo estado del permiso después de solicitar always: $newStatus',
          );
        } catch (e) {
          print('Error al solicitar permiso always: $e');
        }
      }
    }
  }

  // Método mejorado para solicitar permisos de ubicación en segundo plano
  Future<LocationPermission> _requestBackgroundLocationPermission() async {
    if (!Platform.isIOS) return await Geolocator.requestPermission();

    print('Solicitando permisos de ubicación en segundo plano para iOS...');

    // Primero verificamos el estado actual
    LocationPermission currentStatus = await Geolocator.checkPermission();
    print('Estado actual: $currentStatus');

    // En iOS, primero hay que tener "whenInUse" para luego solicitar "always"
    if (currentStatus != LocationPermission.whileInUse &&
        currentStatus != LocationPermission.always) {
      print('Solicitando permiso whenInUse primero...');
      final whileInUseResult = await Geolocator.requestPermission();
      print('Resultado whenInUse: $whileInUseResult');

      if (whileInUseResult != LocationPermission.whileInUse &&
          whileInUseResult != LocationPermission.always) {
        return whileInUseResult;
      }
    }

    // Si ya tenemos whenInUse, podemos solicitar always
    if (currentStatus == LocationPermission.whileInUse) {
      print('Solicitando permiso always...');
      await Geolocator.requestPermission();
    }

    // Verificamos el resultado final
    return await Geolocator.checkPermission();
  }

  // Suscribirse a cambios de ubicación
  Stream<Position> getLocationStream() {
    print('Iniciando stream de ubicación...');

    // Primero verificamos los permisos antes de iniciar el stream
    _checkAndRequestLocationPermission();

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  // Verificar y solicitar permisos de ubicación
  Future<LocationPermission> _checkAndRequestLocationPermission() async {
    print('Verificando permisos de ubicación para stream...');

    // Verificar si los servicios están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Servicios de ubicación deshabilitados, intentando habilitar...');
      try {
        await Geolocator.openLocationSettings();
        // Verificar nuevamente después de abrir configuración
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        print(
          'Servicios de ubicación después de abrir configuración: $serviceEnabled',
        );
      } catch (e) {
        print('Error al abrir configuración de ubicación: $e');
      }
    }

    // Verificar permiso actual
    LocationPermission permission = await Geolocator.checkPermission();
    print('Permiso actual: $permission');

    // Solicitar si es necesario
    if (permission == LocationPermission.denied) {
      print('Solicitando permiso de ubicación...');
      permission = await Geolocator.requestPermission();
      print('Nuevo estado de permiso: $permission');
    }

    return permission;
  }

  // Formatear ubicación para mensaje
  String formatLocationMessage(Position position) {
    return 'Latitud: ${position.latitude}, Longitud: ${position.longitude}\n'
        'Precisión: ${position.accuracy} metros\n'
        'Altitud: ${position.altitude} metros\n'
        'Velocidad: ${position.speed} m/s\n'
        'Hora: ${DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch ?? 0)}';
  }

  // Obtener enlace de Google Maps
  String getGoogleMapsLink(Position position) {
    return 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
  }
}
