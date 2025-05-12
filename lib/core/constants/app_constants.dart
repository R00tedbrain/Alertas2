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
}
