import 'emergency_contact.dart';

class AppConfig {
  final String telegramBotToken;
  final List<EmergencyContact> emergencyContacts;
  final AlertSettings alertSettings;

  AppConfig({
    required this.telegramBotToken,
    required this.emergencyContacts,
    required this.alertSettings,
  });

  // Desde JSON
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      telegramBotToken: json['telegram_bot_token'] as String,
      emergencyContacts:
          (json['emergency_contacts'] as List)
              .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList(),
      alertSettings: AlertSettings.fromJson(
        json['alert_settings'] as Map<String, dynamic>,
      ),
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {
      'telegram_bot_token': telegramBotToken,
      'emergency_contacts': emergencyContacts.map((e) => e.toJson()).toList(),
      'alert_settings': alertSettings.toJson(),
    };
  }

  // Valores predeterminados
  factory AppConfig.defaultConfig() {
    return AppConfig(
      telegramBotToken: '',
      emergencyContacts: [],
      alertSettings: AlertSettings.defaultSettings(),
    );
  }

  // Copiar con
  AppConfig copyWith({
    String? telegramBotToken,
    List<EmergencyContact>? emergencyContacts,
    AlertSettings? alertSettings,
  }) {
    return AppConfig(
      telegramBotToken: telegramBotToken ?? this.telegramBotToken,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      alertSettings: alertSettings ?? this.alertSettings,
    );
  }
}

class AlertSettings {
  final int locationUpdateIntervalSeconds;
  final int audioRecordingDurationSeconds;
  final int audioRecordingIntervalSeconds;

  AlertSettings({
    required this.locationUpdateIntervalSeconds,
    required this.audioRecordingDurationSeconds,
    required this.audioRecordingIntervalSeconds,
  });

  // Desde JSON
  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    return AlertSettings(
      locationUpdateIntervalSeconds:
          json['location_update_interval_seconds'] as int,
      audioRecordingDurationSeconds:
          json['audio_recording_duration_seconds'] as int,
      audioRecordingIntervalSeconds:
          json['audio_recording_interval_seconds'] as int,
    );
  }

  // A JSON
  Map<String, dynamic> toJson() {
    return {
      'location_update_interval_seconds': locationUpdateIntervalSeconds,
      'audio_recording_duration_seconds': audioRecordingDurationSeconds,
      'audio_recording_interval_seconds': audioRecordingIntervalSeconds,
    };
  }

  // Valores predeterminados
  factory AlertSettings.defaultSettings() {
    return AlertSettings(
      locationUpdateIntervalSeconds: 60,
      audioRecordingDurationSeconds: 30,
      audioRecordingIntervalSeconds: 30,
    );
  }

  // Copiar con
  AlertSettings copyWith({
    int? locationUpdateIntervalSeconds,
    int? audioRecordingDurationSeconds,
    int? audioRecordingIntervalSeconds,
  }) {
    return AlertSettings(
      locationUpdateIntervalSeconds:
          locationUpdateIntervalSeconds ?? this.locationUpdateIntervalSeconds,
      audioRecordingDurationSeconds:
          audioRecordingDurationSeconds ?? this.audioRecordingDurationSeconds,
      audioRecordingIntervalSeconds:
          audioRecordingIntervalSeconds ?? this.audioRecordingIntervalSeconds,
    );
  }
}
