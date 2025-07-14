import 'dart:io';

class AppConstants {
  // Configuración de la aplicación
  static const String appName = 'Alerta Telegram';
  static const String appVersion = '1.0.0';

  // Rutas de archivos
  static const String configFilePath = 'assets/config/config.json';

  // Claves para SharedPreferences
  static const String prefTelegramToken = 'telegram_bot_token';
  static const String prefEmergencyContacts = 'emergency_contacts';
  static const String prefIsFirstRun = 'is_first_run';

  // Configuración del servicio en segundo plano
  static const String backgroundServiceId = 'com.emergencia.alerta';
  static const String backgroundServiceName = 'Servicio de Alerta';
  static const String backgroundServiceDescription =
      'Enviando información de emergencia';

  // Notificaciones
  static const int emergencyNotificationId = 1;
  static const String emergencyChannelId = 'emergency_channel';
  static const String emergencyChannelName = 'Canal de Emergencia';
  static const String emergencyChannelDescription =
      'Notificaciones de emergencia activa';

  // Mensajes de Telegram
  static const String startAlertMessage =
      '🚨 *ALERTA DE EMERGENCIA* 🚨\nSe ha detectado un problema. Enviando actualizaciones...';
  static const String locationUpdateMessage = '📍 *Actualización de ubicación*';
  static const String audioRecordingMessage = '🔊 *Grabación de audio*';
  static const String stopAlertMessage =
      '✅ *Alerta finalizada*\nLa situación ha sido resuelta.';

  // Permisos
  static const List<String> requiredPermissions = [
    'location',
    'microphone',
    'backgroundLocation',
    'notification',
  ];

  // Constantes de plataforma
  static const String appleTermsUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const String privacyPolicyUrl =
      'https://r00tedbrain.github.io/privacy-alertatelegram/';
  static const String termsOfServiceUrl =
      'https://tu-dominio.com/terms-of-service';

  // Información de subscripciones
  static const String monthlyProductId = 'premium_monthly';
  static const String yearlyProductId = 'premium_yearly';
  static const String monthlyPrice = '€2.99';
  static const String yearlyPrice = '€19.99';
  static const String monthlyTitle = 'AlertaTelegram Premium Mensual';
  static const String yearlyTitle = 'AlertaTelegram Premium Anual';
  static const String monthlyDuration = '1 mes';
  static const String yearlyDuration = '1 año';

  // Funciones utility
  static bool get isIOS {
    try {
      return Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  static bool get isAndroid {
    try {
      return Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  static String get platformStoreName => isIOS ? 'App Store' : 'Google Play';
}
