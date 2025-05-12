import 'package:flutter/foundation.dart';

/// Configuración global de la aplicación.
class AppConfig {
  /// Indica si estamos en modo depuración
  static bool get isDebug => kDebugMode;

  /// Indica si estamos en modo web
  static bool get isWeb => kIsWeb;

  /// Habilitar logs detallados
  static bool get enableDetailedLogs => isDebug;

  /// Habilitar modo seguro (para que la app siga funcionando aunque algunos componentes fallen)
  static const bool enableSafeMode = true;
}
