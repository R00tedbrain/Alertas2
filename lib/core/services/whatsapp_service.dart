import 'dart:io';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:developer' as developer;

import '../../data/models/emergency_contact.dart';
import 'debug_logger.dart';

@pragma('vm:entry-point')
class WhatsAppService {
  // Logger
  final _logger = Logger();
  final _debugLogger = DebugLogger.instance;

  // API client
  late final Dio _dio;

  // WhatsApp API base URL
  static const String _baseUrl = 'https://graph.facebook.com/v23.0';

  // Configuración
  String _accessToken = '';
  String _phoneNumberId = '';
  String _businessAccountId = '';

  // Control de reintentos
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Timeouts
  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);
  static const Duration _sendTimeout = Duration(seconds: 30);

  // Singleton
  static final WhatsAppService _instance = WhatsAppService._internal();
  factory WhatsAppService() => _instance;

  WhatsAppService._internal() {
    // Inicializar Dio
    _dio = Dio(
      BaseOptions(
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Interceptor para logging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: false,
        responseHeader: false,
      ),
    );

    _debugLogger.info('WhatsAppService', 'Instancia creada');
  }

  // Inicializar con credenciales
  void initialize({
    required String accessToken,
    required String phoneNumberId,
    required String businessAccountId,
  }) {
    if (accessToken.isEmpty || phoneNumberId.isEmpty) {
      _debugLogger.error('WhatsAppService', 'Credenciales inválidas');
      return;
    }

    _accessToken = accessToken;
    _phoneNumberId = phoneNumberId;
    _businessAccountId = businessAccountId;

    _debugLogger.success('WhatsAppService', 'Inicializado correctamente');
  }

  // Comprobar si está inicializado
  bool get isInitialized =>
      _accessToken.isNotEmpty && _phoneNumberId.isNotEmpty;

  // Función helper para reintentos
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    String operationName = 'operación',
  }) async {
    int attempt = 0;

    while (true) {
      attempt++;
      try {
        final result = await operation();
        if (attempt > 1) {
          _debugLogger.success(
            'WhatsAppService',
            '$operationName exitosa después de $attempt intentos',
          );
        }
        return result;
      } catch (e) {
        final bool isLastAttempt = attempt >= _maxRetries;

        _debugLogger.error(
          'WhatsAppService',
          'Error en $operationName (intento $attempt/$_maxRetries): $e',
        );

        if (isLastAttempt) {
          _debugLogger.error(
            'WhatsAppService',
            'Se agotaron los reintentos para $operationName',
          );
          throw e;
        }

        // Espera exponencial entre reintentos
        final waitTime = Duration(
          milliseconds: _retryDelay.inMilliseconds * (1 << (attempt - 1)),
        );
        _debugLogger.info(
          'WhatsAppService',
          'Reintentando en ${waitTime.inMilliseconds}ms...',
        );
        await Future.delayed(waitTime);
      }
    }
  }

  // Enviar mensaje de texto
  Future<String?> sendMessage(
    String phoneNumber,
    String message, {
    String type = 'text',
  }) async {
    if (!isInitialized) {
      _debugLogger.error('WhatsAppService', 'Servicio no inicializado');
      return null;
    }

    return _withRetry<String?>(() async {
      try {
        _debugLogger.info('WhatsAppService', 'Enviando mensaje a $phoneNumber');

        final response = await _dio.post(
          '$_baseUrl/$_phoneNumberId/messages',
          options: Options(
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'messaging_product': 'whatsapp',
            'to': phoneNumber,
            'type': 'text',
            'text': {'body': message},
          },
        );

        if (response.statusCode == 200) {
          final messageId = response.data['messages']?[0]?['id'];
          _debugLogger.success(
            'WhatsAppService',
            'Mensaje enviado exitosamente. ID: $messageId',
          );
          return messageId;
        } else {
          _debugLogger.error(
            'WhatsAppService',
            'Error HTTP: ${response.statusCode} - ${response.data}',
          );
          throw Exception('Error HTTP ${response.statusCode}');
        }
      } on DioException catch (e) {
        _debugLogger.error('WhatsAppService', 'Error Dio: ${e.message}');
        if (e.response != null) {
          _debugLogger.error(
            'WhatsAppService',
            'Respuesta de error: ${e.response?.data}',
          );
        }
        throw e;
      }
    }, operationName: 'envío de mensaje').catchError((e) {
      _debugLogger.error(
        'WhatsAppService',
        'Todos los reintentos fallaron: $e',
      );
      return null;
    });
  }

  // Enviar mensaje con plantilla (template)
  Future<String?> sendTemplateMessage(
    String phoneNumber,
    String templateName, {
    String languageCode = 'es',
    List<String> parameters = const [],
  }) async {
    if (!isInitialized) {
      _debugLogger.error('WhatsAppService', 'Servicio no inicializado');
      return null;
    }

    return _withRetry<String?>(() async {
      try {
        _debugLogger.info(
          'WhatsAppService',
          'Enviando template "$templateName" a $phoneNumber',
        );

        // Construir componentes de la plantilla
        final List<Map<String, dynamic>> components = [];

        if (parameters.isNotEmpty) {
          components.add({
            'type': 'body',
            'parameters':
                parameters
                    .map((param) => {'type': 'text', 'text': param})
                    .toList(),
          });
        }

        final response = await _dio.post(
          '$_baseUrl/$_phoneNumberId/messages',
          options: Options(
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'messaging_product': 'whatsapp',
            'to': phoneNumber,
            'type': 'template',
            'template': {
              'name': templateName,
              'language': {'code': languageCode},
              if (components.isNotEmpty) 'components': components,
            },
          },
        );

        if (response.statusCode == 200) {
          final messageId = response.data['messages']?[0]?['id'];
          _debugLogger.success(
            'WhatsAppService',
            'Template enviado exitosamente. ID: $messageId',
          );
          return messageId;
        } else {
          _debugLogger.error(
            'WhatsAppService',
            'Error HTTP: ${response.statusCode} - ${response.data}',
          );
          throw Exception('Error HTTP ${response.statusCode}');
        }
      } on DioException catch (e) {
        _debugLogger.error(
          'WhatsAppService',
          'Error Dio enviando template: ${e.message}',
        );
        throw e;
      }
    }, operationName: 'envío de template').catchError((e) {
      _debugLogger.error(
        'WhatsAppService',
        'Todos los reintentos fallaron para template: $e',
      );
      return null;
    });
  }

  // Enviar ubicación
  Future<String?> sendLocation(
    String phoneNumber,
    Position position, {
    String? name,
    String? address,
  }) async {
    if (!isInitialized) {
      _debugLogger.error('WhatsAppService', 'Servicio no inicializado');
      return null;
    }

    return _withRetry<String?>(() async {
      try {
        _debugLogger.info(
          'WhatsAppService',
          'Enviando ubicación a $phoneNumber',
        );

        final response = await _dio.post(
          '$_baseUrl/$_phoneNumberId/messages',
          options: Options(
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'messaging_product': 'whatsapp',
            'to': phoneNumber,
            'type': 'location',
            'location': {
              'latitude': position.latitude,
              'longitude': position.longitude,
              if (name != null) 'name': name,
              if (address != null) 'address': address,
            },
          },
        );

        if (response.statusCode == 200) {
          final messageId = response.data['messages']?[0]?['id'];
          _debugLogger.success(
            'WhatsAppService',
            'Ubicación enviada exitosamente. ID: $messageId',
          );
          return messageId;
        } else {
          _debugLogger.error(
            'WhatsAppService',
            'Error HTTP: ${response.statusCode} - ${response.data}',
          );
          throw Exception('Error HTTP ${response.statusCode}');
        }
      } on DioException catch (e) {
        _debugLogger.error(
          'WhatsAppService',
          'Error Dio enviando ubicación: ${e.message}',
        );
        throw e;
      }
    }, operationName: 'envío de ubicación').catchError((e) {
      _debugLogger.error(
        'WhatsAppService',
        'Todos los reintentos fallaron para ubicación: $e',
      );
      return null;
    });
  }

  // Método helper para envío masivo usando números de WhatsApp
  Future<bool> sendMessageToWhatsAppContacts(
    List<EmergencyContact> contacts,
    String message, {
    String type = 'text',
  }) async {
    if (!isInitialized) {
      _debugLogger.error('WhatsAppService', 'Servicio no inicializado');
      return false;
    }

    // Filtrar solo contactos con WhatsApp habilitado
    final whatsappContacts = contacts.where((c) => c.hasValidWhatsApp).toList();

    if (whatsappContacts.isEmpty) {
      _debugLogger.warning(
        'WhatsAppService',
        'No hay contactos WhatsApp habilitados',
      );
      return false;
    }

    bool allSuccessful = true;
    int successCount = 0;

    for (final contact in whatsappContacts) {
      try {
        final phoneNumber = contact.whatsappNumber;

        if (phoneNumber == null || phoneNumber.isEmpty) {
          _debugLogger.error(
            'WhatsAppService',
            'Número WhatsApp no disponible para ${contact.name}',
          );
          allSuccessful = false;
          continue;
        }

        final result = await sendMessage(phoneNumber, message, type: type);

        if (result != null) {
          successCount++;
          _debugLogger.success(
            'WhatsAppService',
            'Mensaje enviado a ${contact.name} ($phoneNumber)',
          );
        } else {
          allSuccessful = false;
          _debugLogger.error(
            'WhatsAppService',
            'Error enviando mensaje a ${contact.name}',
          );
        }
      } catch (e) {
        allSuccessful = false;
        _debugLogger.error(
          'WhatsAppService',
          'Error procesando contacto ${contact.name}: $e',
        );
      }
    }

    _debugLogger.info(
      'WhatsAppService',
      'Envío masivo WhatsApp completado: $successCount/${whatsappContacts.length} exitosos',
    );
    return successCount > 0;
  }

  // Verificar configuración
  Future<bool> verifyConfiguration() async {
    if (!isInitialized) {
      _debugLogger.error('WhatsAppService', 'Servicio no inicializado');
      return false;
    }

    try {
      _debugLogger.info('WhatsAppService', 'Verificando configuración...');

      final response = await _dio.get(
        '$_baseUrl/$_phoneNumberId',
        options: Options(headers: {'Authorization': 'Bearer $_accessToken'}),
      );

      if (response.statusCode == 200) {
        _debugLogger.success(
          'WhatsAppService',
          'Configuración verificada exitosamente: ${response.data}',
        );
        return true;
      } else {
        _debugLogger.error(
          'WhatsAppService',
          'Error verificando configuración: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      _debugLogger.error(
        'WhatsAppService',
        'Error verificando configuración: $e',
      );
      return false;
    }
  }
}
