import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../../data/models/app_config.dart';
import '../../data/models/emergency_contact.dart';
import '../constants/app_constants.dart';

class ConfigService {
  late SharedPreferences _prefs;
  late AppConfig _config;

  // Singleton
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() => _instance;

  ConfigService._internal();

  // Logger
  final _logger = Logger();

  // Inicializar
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
  }

  // Cargar configuración
  Future<void> _loadConfig() async {
    try {
      // Intentar cargar desde SharedPreferences
      final String? configJson = _prefs.getString(
        AppConstants.prefTelegramToken,
      );

      if (configJson != null && configJson.isNotEmpty) {
        _config = AppConfig.fromJson(json.decode(configJson));
        return;
      }

      // Si no existe, cargar desde el archivo de configuración predeterminado
      final String defaultConfigString = await rootBundle.loadString(
        AppConstants.configFilePath,
      );
      _config = AppConfig.fromJson(json.decode(defaultConfigString));

      // Guardar en SharedPreferences
      await saveConfig();
    } catch (e) {
      // En caso de error, usar configuración predeterminada
      _config = AppConfig.defaultConfig();
      print('Error al cargar configuración: $e');
    }
  }

  // Guardar configuración
  Future<void> saveConfig() async {
    await _prefs.setString(
      AppConstants.prefTelegramToken,
      json.encode(_config.toJson()),
    );
  }

  // Getters
  AppConfig get config => _config;
  String get telegramBotToken => _config.telegramBotToken;
  List<EmergencyContact> get emergencyContacts => _config.emergencyContacts;
  AlertSettings get alertSettings => _config.alertSettings;

  // Setters
  Future<void> setTelegramBotToken(String token) async {
    _config = _config.copyWith(telegramBotToken: token);
    await saveConfig();
  }

  Future<void> addEmergencyContact(EmergencyContact contact) async {
    final updatedContacts = List<EmergencyContact>.from(
      _config.emergencyContacts,
    );

    // Verificar si ya existe
    final existingIndex = updatedContacts.indexWhere(
      (c) => c.chatId == contact.chatId,
    );

    if (existingIndex >= 0) {
      updatedContacts[existingIndex] = contact;
    } else {
      updatedContacts.add(contact);
    }

    _config = _config.copyWith(emergencyContacts: updatedContacts);
    await saveConfig();
  }

  Future<void> removeEmergencyContact(String chatId) async {
    final updatedContacts =
        _config.emergencyContacts
            .where((contact) => contact.chatId != chatId)
            .toList();

    _config = _config.copyWith(emergencyContacts: updatedContacts);
    await saveConfig();
  }

  Future<void> updateAlertSettings(AlertSettings settings) async {
    _config = _config.copyWith(alertSettings: settings);
    await saveConfig();
  }
}
