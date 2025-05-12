import 'dart:io';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:developer' as developer;

import '../../data/models/emergency_contact.dart';

@pragma('vm:entry-point')
class TelegramService {
  // Logger
  final _logger = Logger();

  // API client
  late final Dio _dio;

  // API base URL
  static const String _baseUrl = 'https://api.telegram.org/bot';

  // Token del bot
  String _token = '';

  // Control de reintentos
  static const int _maxRetries = 5; // Aumentado para iOS
  static const Duration _retryDelay = Duration(seconds: 2);

  // Timeouts más largos para iOS
  static const Duration _iosConnectTimeout = Duration(seconds: 60);
  static const Duration _iosReceiveTimeout = Duration(seconds: 60);
  static const Duration _iosSendTimeout = Duration(seconds: 60);

  // Timeouts estándar para otras plataformas
  static const Duration _standardConnectTimeout = Duration(seconds: 30);
  static const Duration _standardReceiveTimeout = Duration(seconds: 30);
  static const Duration _standardSendTimeout = Duration(seconds: 30);

  // Singleton
  static final TelegramService _instance = TelegramService._internal();

  factory TelegramService() => _instance;

  TelegramService._internal() {
    // Determinar timeouts según plataforma
    final Duration connectTimeout =
        Platform.isIOS ? _iosConnectTimeout : _standardConnectTimeout;
    final Duration receiveTimeout =
        Platform.isIOS ? _iosReceiveTimeout : _standardReceiveTimeout;
    final Duration sendTimeout =
        Platform.isIOS ? _iosSendTimeout : _standardSendTimeout;

    // Inicializar Dio con configuración mejorada
    _dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Interceptor para logging detallado
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: false,
        responseHeader: false,
      ),
    );

    // Interceptor personalizado para manejar reconexiones en iOS
    if (Platform.isIOS) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onError: (e, handler) async {
            if (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.sendTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionError) {
              developer.log(
                'iOS: Interceptando error de conexión, esperando antes de continuar',
                name: 'TelegramService',
              );

              // Esperar antes de continuar con el error
              await Future.delayed(const Duration(seconds: 1));
            }
            return handler.next(e);
          },
        ),
      );
    }

    print('TelegramService interno creado');
  }

  // Inicializar con token
  void initialize(String token) {
    if (token.isEmpty) {
      print('ADVERTENCIA: TelegramService inicializado con token vacío');
      _logger.w('TelegramService inicializado con token vacío');
      return;
    }

    _token = token;
    print('TelegramService inicializado con token: ${_maskToken(token)}');
    _logger.i('TelegramService inicializado con token');
  }

  // Mascara el token para mostrar solo parte en los logs
  String _maskToken(String token) {
    if (token.length <= 8) return '****';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  // Comprobar si está inicializado
  bool get isInitialized => _token.isNotEmpty;

  // Función helper para reintentos con espera exponencial
  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    String operationName = 'operación',
    int maxRetries = 0, // Si es 0, usa el valor predeterminado
  }) async {
    final int retries = maxRetries > 0 ? maxRetries : _maxRetries;
    int attempt = 0;

    // Para iOS, agregar un breve retraso inicial para asegurar que la red esté estable
    if (Platform.isIOS) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    while (true) {
      attempt++;
      try {
        final result = await operation();
        if (attempt > 1) {
          print('$operationName exitosa después de $attempt intentos');
        }
        return result;
      } catch (e) {
        final bool isLastAttempt = attempt >= retries;

        // Log detallado del error
        if (e is DioException) {
          print(
            'Error Dio en intento $attempt/$retries: ${e.type} - ${e.message}',
          );

          // Manejo especial para errores de red
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            print('Error de timeout - la red puede estar congestionada');
          } else if (e.type == DioExceptionType.connectionError) {
            print('Error de conexión - verificando red...');
          }
        } else {
          print('Error general en intento $attempt/$retries: $e');
        }

        if (isLastAttempt) {
          print('Se agotaron los reintentos para $operationName');
          throw e;
        }

        // Espera exponencial entre reintentos
        final waitTime = Duration(
          milliseconds: _retryDelay.inMilliseconds * (1 << (attempt - 1)),
        );
        print('Reintentando en ${waitTime.inMilliseconds}ms...');
        await Future.delayed(waitTime);
      }
    }
  }

  // Enviar mensaje a un chat con reintento
  Future<bool> sendMessage(
    String chatId,
    String text, {
    bool markdown = false,
  }) async {
    print('🔶 INICIO sendMessage - chatId: $chatId');

    if (!isInitialized) {
      print(
        '🔶 ERROR: TelegramService no inicializado al intentar enviar mensaje',
      );
      _logger.e('TelegramService no inicializado');
      return false;
    }

    // Asegurarse que markdown no cause problemas
    String processedText = text;
    if (markdown) {
      try {
        // Escapar caracteres especiales para MarkdownV2
        processedText = _escapeMarkdown(text);
      } catch (e) {
        print('🔶 Error al escapar markdown, enviando como texto plano: $e');
        markdown = false;
      }
    }

    // Para iOS, usar más reintentos
    final maxRetries = Platform.isIOS ? _maxRetries + 2 : _maxRetries;
    print('🔶 Reintentos configurados: $maxRetries');

    return _withRetry<bool>(
      () async {
        try {
          print('🔶 Enviando mensaje a chat $chatId');
          print('🔶 URL: $_baseUrl$_token/sendMessage');
          developer.log('Enviando mensaje a Telegram', name: 'TelegramService');
          print(
            '🔶 Texto del mensaje: ${processedText.length > 50 ? '${processedText.substring(0, 50)}...' : processedText}',
          );

          // Imprimir estado de la red
          if (Platform.isIOS) {
            developer.log(
              'Verificando conexión antes de enviar mensaje',
              name: 'TelegramService',
            );
          }

          // Construir datos para el body
          final Map<String, dynamic> bodyData = {
            'chat_id': chatId,
            'text': processedText,
          };

          if (markdown) {
            bodyData['parse_mode'] = 'MarkdownV2';
          }

          print('🔶 Body de la solicitud: $bodyData');

          final response = await _dio.post(
            '$_baseUrl$_token/sendMessage',
            data: bodyData,
          );

          print('🔶 Respuesta recibida - Código: ${response.statusCode}');

          if (response.statusCode == 200) {
            print('🔶 Mensaje enviado exitosamente a $chatId');
            print('🔶 Respuesta: ${response.data}');
            developer.log(
              'Mensaje enviado exitosamente',
              name: 'TelegramService',
            );
            _logger.i('Mensaje enviado a $chatId');
            return true;
          } else {
            print('🔶 ERROR al enviar mensaje: Código ${response.statusCode}');
            print('🔶 Respuesta: ${response.data}');
            developer.log(
              'Error al enviar mensaje: ${response.statusCode}',
              name: 'TelegramService',
              error: response.data,
            );
            _logger.e('Error al enviar mensaje: ${response.statusCode}');

            // Si el error es por el formato markdown, reintentar sin markdown
            if (markdown &&
                response.data.toString().contains('can\'t parse entities')) {
              print('🔶 Error de formato markdown, reintentando sin markdown');
              return await sendMessage(chatId, text, markdown: false);
            }

            return false;
          }
        } on DioException catch (e) {
          print('🔶 ERROR Dio al enviar mensaje: ${e.message}');
          print('🔶 Tipo de error Dio: ${e.type}');
          developer.log(
            'ERROR Dio al enviar mensaje',
            name: 'TelegramService',
            error: e,
          );

          if (e.response != null) {
            print('🔶 Código de error: ${e.response?.statusCode}');
            print('🔶 Respuesta de error: ${e.response?.data}');
          }

          // Verificar errores específicos de red
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            developer.log(
              'Error de timeout en la conexión',
              name: 'TelegramService',
            );

            // En iOS, esperar un poco más antes de reintentar
            if (Platform.isIOS) {
              print(
                '🔶 iOS: Esperando 2 segundos adicionales antes de reintentar',
              );
              await Future.delayed(const Duration(seconds: 2));
            }
          } else if (e.type == DioExceptionType.connectionError) {
            developer.log(
              'Error de conexión - posible problema de red',
              name: 'TelegramService',
            );

            // En iOS, esperar un poco más para dar tiempo a la reconexión
            if (Platform.isIOS) {
              print(
                '🔶 iOS: Esperando 3 segundos adicionales por problema de conexión',
              );
              await Future.delayed(const Duration(seconds: 3));
            }
          }

          _logger.e('Error Dio al enviar mensaje: ${e.message}');
          throw e; // Lanzar para que _withRetry reintente
        } catch (e) {
          print('🔶 ERROR general al enviar mensaje: $e');
          developer.log(
            'ERROR general al enviar mensaje',
            name: 'TelegramService',
            error: e,
          );
          _logger.e('Error al enviar mensaje: $e');
          throw e; // Lanzar para que _withRetry reintente
        }
      },
      operationName: 'envío de mensaje',
      maxRetries: maxRetries,
    ).catchError((e) {
      print('🔶 Todos los reintentos fallaron para enviar mensaje: $e');
      developer.log(
        'Todos los reintentos fallaron para enviar mensaje',
        name: 'TelegramService',
        error: e,
      );
      return false;
    });
  }

  // Escapar caracteres especiales para MarkdownV2
  String _escapeMarkdown(String text) {
    // Escapar caracteres especiales de MarkdownV2
    return text
        .replaceAll('_', '\\_')
        .replaceAll('*', '\\*')
        .replaceAll('[', '\\[')
        .replaceAll(']', '\\]')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('~', '\\~')
        .replaceAll('`', '\\`')
        .replaceAll('>', '\\>')
        .replaceAll('#', '\\#')
        .replaceAll('+', '\\+')
        .replaceAll('-', '\\-')
        .replaceAll('=', '\\=')
        .replaceAll('|', '\\|')
        .replaceAll('{', '\\{')
        .replaceAll('}', '\\}')
        .replaceAll('.', '\\.')
        .replaceAll('!', '\\!');
  }

  // Enviar ubicación con reintento
  Future<bool> sendLocation(String chatId, Position position) async {
    if (!isInitialized) {
      print(
        'ERROR: TelegramService no inicializado al intentar enviar ubicación',
      );
      _logger.e('TelegramService no inicializado');
      return false;
    }

    return _withRetry<bool>(() async {
      try {
        print('Enviando ubicación a chat $chatId');
        print(
          'Coordenadas: Lat ${position.latitude}, Lng ${position.longitude}',
        );

        final response = await _dio.post(
          '$_baseUrl$_token/sendLocation',
          data: {
            'chat_id': chatId,
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );

        if (response.statusCode == 200) {
          print('Ubicación enviada exitosamente a $chatId');
          _logger.i('Ubicación enviada a $chatId');
          return true;
        } else {
          print('ERROR al enviar ubicación: Código ${response.statusCode}');
          print('Respuesta: ${response.data}');
          _logger.e('Error al enviar ubicación: ${response.statusCode}');
          throw Exception('Error HTTP ${response.statusCode}');
        }
      } on DioException catch (e) {
        print('ERROR Dio al enviar ubicación: ${e.message}');
        if (e.response != null) {
          print('Código de error: ${e.response?.statusCode}');
          print('Respuesta de error: ${e.response?.data}');
        }
        _logger.e('Error Dio al enviar ubicación: ${e.message}');
        throw e; // Lanzar para que _withRetry reintente
      } catch (e) {
        print('ERROR general al enviar ubicación: $e');
        _logger.e('Error al enviar ubicación: $e');
        throw e; // Lanzar para que _withRetry reintente
      }
    }, operationName: 'envío de ubicación').catchError((e) {
      print('Todos los reintentos fallaron para enviar ubicación: $e');
      return false;
    });
  }

  // Enviar audio con reintento
  Future<bool> sendAudio(String chatId, String filePath) async {
    if (!isInitialized) {
      print('ERROR: TelegramService no inicializado al intentar enviar audio');
      _logger.e('TelegramService no inicializado');
      return false;
    }

    // Verificar que el archivo existe antes de intentar
    final file = File(filePath);
    if (!await file.exists()) {
      print('ERROR: El archivo de audio no existe en $filePath');
      _logger.e('El archivo no existe: $filePath');
      return false;
    }

    print('Tamaño del archivo: ${await file.length()} bytes');

    return _withRetry<bool>(() async {
      try {
        print('Enviando audio a chat $chatId');
        print('Ruta del archivo: $filePath');

        // Preparar datos
        final formData = FormData.fromMap({
          'chat_id': chatId,
          'title': 'Grabación de emergencia',
          'audio': await MultipartFile.fromFile(
            filePath,
            filename: 'audio.aac',
          ),
        });

        final response = await _dio.post(
          '$_baseUrl$_token/sendAudio',
          data: formData,
        );

        if (response.statusCode == 200) {
          print('Audio enviado exitosamente a $chatId');
          _logger.i('Audio enviado a $chatId');
          return true;
        } else {
          print('ERROR al enviar audio: Código ${response.statusCode}');
          print('Respuesta: ${response.data}');
          _logger.e('Error al enviar audio: ${response.statusCode}');
          throw Exception('Error HTTP ${response.statusCode}');
        }
      } on DioException catch (e) {
        print('ERROR Dio al enviar audio: ${e.message}');
        if (e.response != null) {
          print('Código de error: ${e.response?.statusCode}');
          print('Respuesta de error: ${e.response?.data}');
        }
        _logger.e('Error Dio al enviar audio: ${e.message}');
        throw e; // Lanzar para que _withRetry reintente
      } catch (e) {
        print('ERROR general al enviar audio: $e');
        _logger.e('Error al enviar audio: $e');
        throw e; // Lanzar para que _withRetry reintente
      }
    }, operationName: 'envío de audio').catchError((e) {
      print('Todos los reintentos fallaron para enviar audio: $e');
      return false;
    });
  }

  // Enviar mensaje a todos los contactos de emergencia
  Future<bool> sendMessageToAllContacts(
    List<EmergencyContact> contacts,
    String text, {
    bool markdown = false,
  }) async {
    print('⚠️ INICIO sendMessageToAllContacts ⚠️');
    print('⚠️ Número de contactos: ${contacts.length}');

    if (contacts.isEmpty) {
      print('⚠️ ADVERTENCIA CRÍTICA: Lista de contactos vacía');
      _logger.w('Lista de contactos vacía al enviar mensaje');
      return false;
    }

    print('Enviando mensaje a ${contacts.length} contactos');
    bool allSuccess = true;

    // Depuración de token
    print(
      '⚠️ Estado de inicialización: ${isInitialized ? 'INICIALIZADO' : 'NO INICIALIZADO'}',
    );
    print('⚠️ Token enmascarado: ${_maskToken(_token)}');

    // Mostrar primeros caracteres del mensaje
    print(
      '⚠️ Mensaje a enviar (primeros 50 caracteres): ${text.length > 50 ? text.substring(0, 50) + '...' : text}',
    );

    // Enviar a cada contacto secuencialmente
    int contactIndex = 0;
    for (final contact in contacts) {
      contactIndex++;
      print(
        '⚠️ Procesando contacto $contactIndex/${contacts.length}: ${contact.name} (${contact.chatId})',
      );

      try {
        print(
          '⚠️ Intentando enviar mensaje a ${contact.name} (${contact.chatId})',
        );
        final success = await sendMessage(
          contact.chatId,
          text,
          markdown: markdown,
        );

        if (success) {
          print('⚠️ Mensaje enviado exitosamente a ${contact.name}');
        } else {
          print(
            '⚠️ Fallo al enviar mensaje a ${contact.name} (${contact.chatId})',
          );
          allSuccess = false;
        }

        // Pequeña pausa entre mensajes para no saturar la API
        print('⚠️ Esperando 500ms antes del siguiente envío');
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('⚠️ ERROR CRÍTICO al enviar mensaje a ${contact.name}: $e');
        _logger.e('Error al enviar mensaje a ${contact.name}: $e');
        allSuccess = false;
      }
    }

    print(
      '⚠️ FIN sendMessageToAllContacts: ${allSuccess ? 'TODOS ENVIADOS' : 'ALGUNOS FALLARON'}',
    );
    return allSuccess;
  }

  // Enviar ubicación a todos los contactos de emergencia
  Future<bool> sendLocationToAllContacts(
    List<EmergencyContact> contacts,
    Position position,
  ) async {
    if (contacts.isEmpty) {
      print('ADVERTENCIA: Lista de contactos vacía');
      _logger.w('Lista de contactos vacía al enviar ubicación');
      return false;
    }

    print('Enviando ubicación a ${contacts.length} contactos');
    bool allSuccess = true;

    // Enviar a cada contacto secuencialmente
    for (final contact in contacts) {
      try {
        final success = await sendLocation(contact.chatId, position);
        if (!success) {
          print(
            'Fallo al enviar ubicación a ${contact.name} (${contact.chatId})',
          );
          allSuccess = false;
        }
        // Pequeña pausa entre mensajes para no saturar la API
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error al enviar ubicación a ${contact.name}: $e');
        allSuccess = false;
      }
    }

    return allSuccess;
  }

  // Enviar audio a todos los contactos de emergencia
  Future<bool> sendAudioToAllContacts(
    List<EmergencyContact> contacts,
    String filePath,
  ) async {
    if (contacts.isEmpty) {
      print('ADVERTENCIA: Lista de contactos vacía');
      _logger.w('Lista de contactos vacía al enviar audio');
      return false;
    }

    print('Enviando audio a ${contacts.length} contactos');
    bool allSuccess = true;

    // Enviar a cada contacto secuencialmente
    for (final contact in contacts) {
      try {
        final success = await sendAudio(contact.chatId, filePath);
        if (!success) {
          print('Fallo al enviar audio a ${contact.name} (${contact.chatId})');
          allSuccess = false;
        }
        // Pequeña pausa entre mensajes para no saturar la API
        await Future.delayed(const Duration(milliseconds: 1000));
      } catch (e) {
        print('Error al enviar audio a ${contact.name}: $e');
        allSuccess = false;
      }
    }

    return allSuccess;
  }

  // Verificar si el token es válido
  Future<bool> verifyToken() async {
    if (!isInitialized) {
      print('ERROR: TelegramService no inicializado al verificar token');
      _logger.e('TelegramService no inicializado');
      return false;
    }

    try {
      print('Verificando token de Telegram: ${_maskToken(_token)}');

      final response = await _dio.get('$_baseUrl$_token/getMe');

      if (response.statusCode == 200 && response.data['ok'] == true) {
        print('Token verificado exitosamente: ${response.data}');
        _logger.i('Token verificado exitosamente');
        return true;
      } else {
        print('ERROR al verificar token: ${response.data}');
        _logger.e('Error al verificar token: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      print('ERROR al verificar token: $e');
      if (e.response != null) {
        print('Respuesta: ${e.response?.data}');
      }
      _logger.e('Error al verificar token: $e');
      return false;
    } catch (e) {
      print('ERROR general al verificar token: $e');
      _logger.e('Error al verificar token: $e');
      return false;
    }
  }
}
