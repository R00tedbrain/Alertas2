import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import '../../domain/providers/providers.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/background_service.dart';
import '../../core/services/iap_service.dart';
import '../../core/services/telegram_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/debug_logger.dart';
import '../screens/settings_screen.dart';

class AlertButton extends ConsumerWidget {
  const AlertButton({super.key});

  static const String _tag = 'AlertButton';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertStatus = ref.watch(alertStatusProvider);
    final isActive = alertStatus.isActive;

    // Logging detallado del estado
    final debugLogger = DebugLogger.instance;
    debugLogger.debug(_tag, 'Verificando estado de acceso...');
    final iapService = IAPService.instance;
    debugLogger.debug(_tag, 'hasPremium: ${iapService.hasPremium}');
    debugLogger.debug(_tag, 'isInTrial: ${iapService.isInTrial}');

    final hasAccess = iapService.hasPremium || iapService.isInTrial;
    debugLogger.info(_tag, 'Acceso final calculado: $hasAccess');

    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isActive
                    ? Colors.red.withOpacity(0.3)
                    : Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Colors.red : Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () async {
          if (isActive) {
            // Detener alerta
            _showConfirmationDialog(context, ref);
          } else {
            // Iniciar alerta
            _startAlert(context, ref);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.alarm_off : Icons.alarm_on, size: 40),
            const SizedBox(height: 8),
            Text(
              isActive ? 'DETENER ALERTA' : 'PROBLEMA DETECTADO',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _startAlert(BuildContext context, WidgetRef ref) async {
    final debugLogger = DebugLogger.instance;
    debugLogger.info(_tag, 'Iniciando proceso de alerta...');

    // 🔥 VERIFICAR PREMIUM O TRIAL ANTES DE CONTINUAR
    final iapService = IAPService.instance;
    final hasPremium = iapService.hasPremium;
    final isInTrial = iapService.isInTrial;

    debugLogger.debug(_tag, 'Verificando acceso...');
    debugLogger.debug(_tag, 'hasPremium: $hasPremium');
    debugLogger.debug(_tag, 'isInTrial: $isInTrial');

    // ✅ Permitir si tiene premium O está en trial
    final canUseAlert = hasPremium || isInTrial;
    debugLogger.info(_tag, 'Acceso calculado: $canUseAlert');

    if (!canUseAlert) {
      debugLogger.warning(_tag, 'Acceso denegado, mostrando diálogo premium');
      _showPremiumRequiredDialog(context, ref);
      return;
    }

    debugLogger.success(_tag, 'Acceso permitido, continuando...');

    // Verificar específicamente el permiso de micrófono primero
    final permissionService = ref.read(permissionServiceProvider);
    final micStatus = await permissionService.requestMicrophonePermission();

    if (!micStatus.isGranted) {
      _showMicrophonePermissionDialog(context, ref, micStatus);
      return;
    }

    // Verificar el resto de los permisos
    final permissions = await ref.read(permissionsProvider.future);

    if (permissions['allGranted'] != true) {
      _showPermissionsDialog(context, ref);
      return;
    }

    final alertNotifier = ref.read(alertStatusProvider.notifier);
    final success = await alertNotifier.startAlert();

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al iniciar la alerta'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMicrophonePermissionDialog(
    BuildContext context,
    WidgetRef ref,
    PermissionStatus status,
  ) {
    final permissionService = ref.read(permissionServiceProvider);
    String message = '';

    if (status.isPermanentlyDenied) {
      message =
          'Esta aplicación necesita acceso al micrófono para grabar audio durante una emergencia.\n\nPuedes habilitarlo en: Configuración > Privacidad y Seguridad > Micrófono > AlertaTelegram';
    } else if (status.isDenied) {
      message =
          'Esta aplicación necesita acceso al micrófono para grabar audio durante una emergencia.\n\nPuedes habilitarlo en: Configuración > Privacidad y Seguridad > Micrófono > AlertaTelegram';
    } else {
      message =
          'No se puede acceder al micrófono. Por favor, verifica los permisos en la configuración de la aplicación.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Acceso al Micrófono Requerido'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_off, color: Colors.blue, size: 48),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Más tarde'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Siempre dirigir a configuración, respetando la decisión del usuario
                  permissionService.openSettings();
                },
                child: const Text('Abrir Configuración'),
              ),
            ],
          ),
    );
  }

  void _showPermissionsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permisos Necesarios'),
            content: const Text(
              'Esta aplicación necesita permisos de ubicación, micrófono y notificaciones para funcionar correctamente durante una emergencia.\n\nPuedes habilitarlos en: Configuración > Privacidad y Seguridad > [Permiso específico] > AlertaTelegram',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Más tarde'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Dirigir a configuración respetando la decisión del usuario
                  final permissionService = ref.read(permissionServiceProvider);
                  permissionService.openSettings();
                },
                child: const Text('Abrir Configuración'),
              ),
            ],
          ),
    );
  }

  void _showConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Detener alerta'),
            content: const Text(
              '¿Estás seguro de que deseas detener la alerta? '
              'Esto detendrá el envío de ubicación y audio a tus contactos de emergencia.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final alertNotifier = ref.read(alertStatusProvider.notifier);
                  final success = await alertNotifier.stopAlert();

                  if (!success) {
                    _showForceStopDialog(context, ref);
                  } else {
                    // Programar una verificación después de un tiempo
                    // para asegurar que la alerta realmente se ha detenido
                    Future.delayed(const Duration(seconds: 8), () {
                      final isStillActive =
                          ref.read(alertStatusProvider).isActive;
                      if (isStillActive) {
                        _showForceStopDialog(context, ref);
                      }
                    });
                  }
                },
                child: const Text(
                  'Detener',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  // Diálogo para manejar un fallo en la detención de la alerta
  void _showForceStopDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Problema al detener alerta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'No se pudo detener la alerta correctamente. '
                  'Los mensajes podrían seguir enviándose. '
                  'Por favor, seleccione una acción:',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Esperar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Intentar detener otra vez con el servicio directamente
                  final backgroundService = ref.read(backgroundServiceProvider);
                  backgroundService.stopAlert();

                  // Forzar el estado a inactivo en el provider
                  final alertNotifier = ref.read(alertStatusProvider.notifier);
                  alertNotifier.forceStopAlert();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alerta forzada a detenerse'),
                      backgroundColor: Colors.orange,
                    ),
                  );

                  // Mostrar un segundo diálogo después de un breve retraso
                  // para verificar si la detención fue exitosa
                  Future.delayed(Duration(seconds: 3), () {
                    final isStillActive =
                        ref.read(alertStatusProvider).isActive;
                    if (isStillActive) {
                      _showEmergencyOptionsDialog(context, ref);
                    }
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Forzar detención'),
              ),
              if (Platform.isIOS)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEmergencyOptionsDialog(context, ref);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Opciones de emergencia'),
                ),
            ],
          ),
    );
  }

  // Diálogo con opciones extremas para casos donde la detención normal falla
  void _showEmergencyOptionsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Opciones de emergencia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'La aplicación sigue enviando mensajes. '
                  'Estas son opciones más agresivas:',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  // Detención forzada extrema
                  final alertNotifier = ref.read(alertStatusProvider.notifier);
                  alertNotifier.forceStopAlert().then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Detención forzada extrema activada'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Forzar detención extrema'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  // Forzar detención y mostrar instrucciones para cerrar la app
                  final alertNotifier = ref.read(alertStatusProvider.notifier);
                  alertNotifier.forceStopAlert().then((_) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Cierre manual requerido'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.exit_to_app,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Por favor, cierre completamente la aplicación ahora:\n\n'
                                  '1. Deslice hacia arriba desde la parte inferior\n'
                                  '2. Deslice la app hacia arriba para cerrarla\n'
                                  '3. Vuelva a abrir la aplicación\n\n'
                                  'Esto es necesario para detener completamente los envíos.',
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Instrucciones de cierre'),
              ),
            ],
          ),
    );
  }

  /// Diálogo para informar que se necesita premium después de los 7 días
  void _showPremiumRequiredDialog(BuildContext context, WidgetRef ref) {
    final debugLogger = DebugLogger.instance;
    debugLogger.info(_tag, 'Mostrando diálogo premium');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.diamond, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                const Text('Premium Requerido'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu período de prueba gratuita de 7 días ha terminado.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Para seguir usando la función de alerta de emergencia, necesitas suscribirte a Premium.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Premium incluye:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem('🚨 Alertas de emergencia ilimitadas'),
                      _buildFeatureItem('📍 GPS de alta precisión'),
                      _buildFeatureItem('🎙️ Audio de alta calidad'),
                      _buildFeatureItem('📸 Captura de fotos automática'),
                      _buildFeatureItem('🔒 Soporte prioritario'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Después'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navegar a la pantalla de compras
                  Navigator.pushNamed(context, '/remove_ads');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ver Planes Premium'),
              ),
            ],
          ),
    );
  }

  /// Widget auxiliar para mostrar características de premium
  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.blue)),
          Expanded(child: Text(feature, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
