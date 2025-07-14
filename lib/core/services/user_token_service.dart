import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

/// Servicio para gestionar tokens de usuario que se conectan al backend
class UserTokenService {
  static const String _tokenKey = 'alertatelegram_user_token';
  static const String _testTokenKey = 'alertatelegram_test_mode';

  // Token de prueba pre-configurado en el backend
  static const String testToken = 'test_premium_user_2024';

  // Singleton
  static final UserTokenService _instance = UserTokenService._internal();
  factory UserTokenService() => _instance;
  UserTokenService._internal();

  /// Obtener token del usuario actual
  Future<String?> getUserToken() async {
    final prefs = await SharedPreferences.getInstance();

    // Verificar si está en modo de prueba
    final isTestMode =
        prefs.getBool(_testTokenKey) ?? true; // Por defecto modo prueba

    if (isTestMode) {
      return testToken;
    }

    // En modo producción, obtener token real guardado
    return prefs.getString(_tokenKey);
  }

  /// Establecer token de usuario
  Future<void> setUserToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_testTokenKey, false); // Desactivar modo prueba
  }

  /// Activar modo de prueba
  Future<void> enableTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testTokenKey, true);
  }

  /// Desactivar modo de prueba
  Future<void> disableTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testTokenKey, false);
  }

  /// Verificar si está en modo de prueba
  Future<bool> isTestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_testTokenKey) ?? true;
  }

  /// Generar un token único para un nuevo usuario
  String generateUserToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    final combined = 'alertatelegram_${timestamp}_$random';

    // Crear hash para hacer el token más seguro
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return 'alertatelegram_${digest.toString().substring(0, 16)}_$random';
  }

  /// Limpiar token guardado
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.setBool(_testTokenKey, true); // Volver a modo prueba
  }

  /// Obtener información del token actual
  Future<Map<String, dynamic>> getTokenInfo() async {
    final token = await getUserToken();
    final isTest = await isTestMode();

    if (token == null) {
      return {
        'hasToken': false,
        'isTestMode': isTest,
        'token': null,
        'status': 'No hay token configurado',
      };
    }

    return {
      'hasToken': true,
      'isTestMode': isTest,
      'token':
          isTest ? 'test_premium_user_2024' : '${token.substring(0, 8)}***',
      'status': isTest ? 'Usando token de prueba' : 'Token de usuario real',
    };
  }

  /// Validar formato de token
  bool isValidToken(String token) {
    if (token.isEmpty) return false;

    // Token de prueba siempre es válido
    if (token == testToken) return true;

    // Validar formato de token real: alertatelegram_[hash]_[random]
    final regex = RegExp(r'^alertatelegram_[a-f0-9]{16}_\d{6}$');
    return regex.hasMatch(token);
  }
}
