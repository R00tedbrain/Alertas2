import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../data/models/emergency_contact.dart';
import 'user_token_service.dart';

/// Servicio centralizado de WhatsApp que se conecta a la API de AlertaTelegram
/// Los usuarios NO necesitan configurar nada técnico - solo números de teléfono
class WhatsAppCentralizedService {
  static const String _baseUrl = 'http://localhost:4000'; // Backend local
  static const String _endpoint = '/whatsapp/send-alert';

  final Dio _dio;
  final Logger _logger = Logger();

  // Singleton
  static final WhatsAppCentralizedService _instance =
      WhatsAppCentralizedService._internal();
  factory WhatsAppCentralizedService() => _instance;

  WhatsAppCentralizedService._internal() : _dio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'AlertaTelegram-App/1.0',
      },
    );
  }

  /// Enviar alerta a través del servicio centralizado
  Future<bool> sendAlert({
    required List<EmergencyContact> whatsAppContacts,
    required String message,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Obtener token del usuario
      final userToken = await UserTokenService().getUserToken();
      if (userToken == null) {
        _logger.e('No hay token de usuario configurado');
        return false;
      }

      // Filtrar solo contactos con WhatsApp habilitado
      final validContacts =
          whatsAppContacts
              .where(
                (contact) =>
                    contact.whatsappEnabled &&
                    contact.whatsappNumber != null &&
                    contact.whatsappNumber!.isNotEmpty,
              )
              .toList();

      if (validContacts.isEmpty) {
        _logger.w('No hay contactos válidos de WhatsApp para enviar');
        return false;
      }

      // Preparar datos para la API
      final requestData = {
        'message': message,
        'location': {'latitude': latitude, 'longitude': longitude},
        'contacts':
            validContacts
                .map(
                  (contact) => {
                    'name': contact.name,
                    'phoneNumber': contact.whatsappNumber,
                  },
                )
                .toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      _logger.i('Enviando alerta WhatsApp a ${validContacts.length} contactos');

      // Enviar a la API centralizada con token en header
      final response = await _dio.post(
        _endpoint,
        data: requestData,
        options: Options(
          headers: {
            'X-User-Token': userToken, // Token en header, no en body
          },
        ),
      );

      if (response.statusCode == 200) {
        _logger.i('Alerta WhatsApp enviada exitosamente');
        return true;
      } else {
        _logger.e('Error en la API: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (e is DioException) {
        _logger.e('Error de red al enviar WhatsApp: ${e.message}');

        // Manejar errores específicos
        if (e.response?.statusCode == 401) {
          _logger.e('Token de usuario inválido o expirado');
        } else if (e.response?.statusCode == 402) {
          _logger.e('Límite de mensajes WhatsApp excedido');
        } else if (e.response?.statusCode == 403) {
          _logger.e('Usuario no tiene premium activo');
        }
      } else {
        _logger.e('Error inesperado: $e');
      }
      return false;
    }
  }

  /// Validar número de WhatsApp
  bool isValidWhatsAppNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;

    // Formato internacional: +[código país][número]
    final regex = RegExp(r'^\+[1-9]\d{1,14}$');
    return regex.hasMatch(phoneNumber);
  }

  /// Obtener información del servicio
  Map<String, dynamic> getServiceInfo() {
    return {
      'name': 'WhatsApp Premium',
      'description': 'Servicio centralizado de AlertaTelegram',
      'maxContacts': 3,
      'requiresPremium': true,
      'features': [
        'Envío automático de alertas',
        'Sin configuración técnica',
        'Integración con Telegram',
        'Soporte 24/7',
      ],
    };
  }
}
