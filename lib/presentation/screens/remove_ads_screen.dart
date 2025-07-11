import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../../domain/providers/providers.dart';
import '../../data/models/purchase_state.dart';

class RemoveAdsScreen extends ConsumerStatefulWidget {
  const RemoveAdsScreen({super.key});

  @override
  ConsumerState<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends ConsumerState<RemoveAdsScreen> {
  bool _isProcessing = false;

  // 🔥 TEMPORAL - Solo para capturas de Apple
  // ⚠️ CAMBIAR A false DESPUÉS DE LAS CAPTURAS
  static const bool _showPricesForScreenshots = false;

  @override
  Widget build(BuildContext context) {
    // Escuchar estado de inicialización de IAP
    final iapInitialization = ref.watch(iapInitializationProvider);

    // Escuchar estado de suscripción premium
    final subscriptionAsync = ref.watch(premiumSubscriptionProvider);

    // Escuchar productos disponibles
    final monthlyProductAsync = ref.watch(monthlyProductProvider);
    final yearlyProductAsync = ref.watch(yearlyProductProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes Premium'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: iapInitialization.when(
        loading:
            () => const Center(
              child: SpinKitFadingCircle(color: Colors.blue, size: 50.0),
            ),
        error: (error, stack) => _buildErrorState(context, error.toString()),
        data: (initialized) {
          if (!initialized) {
            return _buildErrorState(
              context,
              'No se pudo inicializar el sistema de compras',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado de suscripción actual
                _buildSubscriptionStatus(subscriptionAsync),

                const SizedBox(height: 24),

                // Título principal
                Text(
                  'Planes Premium',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Desbloquea todas las funciones de emergencia',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Beneficios premium
                _buildBenefitsCard(context),

                const SizedBox(height: 24),

                // Opción de prueba gratuita
                _buildTrialOption(context),

                const SizedBox(height: 24),

                // Planes de suscripción
                _buildProductPlans(monthlyProductAsync, yearlyProductAsync),

                const SizedBox(height: 24),

                // Información adicional
                _buildInfoSection(context),

                const SizedBox(height: 24),

                // Sección de restaurar compras (REQUERIDO por Apple y Google)
                _buildRestorePurchasesSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBenefitsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade100, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'Versión Premium',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ..._buildBenefitsList([
            '🚨 Alertas de emergencia ilimitadas',
            '📍 GPS de alta precisión (LocationAccuracy.best)',
            '🎙️ Audio de alta calidad (44.1kHz estéreo)',
            '📸 Captura automática de fotos',
            '🔒 Soporte técnico prioritario',
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildBenefitsList(List<String> benefits) {
    return benefits
        .map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    benefit,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required String period,
    String? originalPrice,
    required List<String> features,
    required Color color,
    bool isPopular = false,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular ? color : Colors.grey.shade300,
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con badge popular
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'POPULAR',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Precio
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.nunito(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  period,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (originalPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    originalPrice,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Características
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      feature,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botón de compra
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Seleccionar',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• La suscripción se renovará automáticamente\n• Puedes cancelar en cualquier momento\n• El pago se cargará a tu cuenta de App Store/Play Store\n• Gestiona tu suscripción desde la configuración de tu dispositivo',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Construir estado de error
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error del Sistema de Compras',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  /// Construir estado de suscripción actual
  Widget _buildSubscriptionStatus(
    AsyncValue<PremiumSubscription> subscriptionAsync,
  ) {
    return subscriptionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (subscription) {
        if (!subscription.isActive) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Suscripción Premium Activa',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tipo: ${subscription.productType?.name.toUpperCase() ?? 'Desconocido'}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
              if (subscription.daysRemaining > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Días restantes: ${subscription.daysRemaining}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Construir opción de prueba gratuita
  Widget _buildTrialOption(BuildContext context) {
    final canUseTrial = ref.watch(canUseTrialProvider);

    return canUseTrial.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (canUse) {
        if (!canUse) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade100, Colors.green.shade50],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300, width: 2),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '🎯 PRUEBA GRATUITA',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '7 días de acceso completo',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/trial');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'EMPEZAR GRATIS',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sin compromiso • Cancela cuando quieras',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.green.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construir planes de productos
  Widget _buildProductPlans(
    AsyncValue<IAPProduct?> monthlyProductAsync,
    AsyncValue<IAPProduct?> yearlyProductAsync,
  ) {
    // 🔥 TEMPORAL - Mostrar precios para capturas
    if (_showPricesForScreenshots) {
      return Column(
        children: [
          // Plan mensual CON PRECIO TEMPORAL
          _buildPlanCard(
            context,
            title: 'Plan Mensual',
            price: '€2.99', // ← PRECIO TEMPORAL PARA CAPTURAS
            period: 'por mes',
            features: [
              'Alertas de emergencia ilimitadas',
              'GPS de alta precisión',
              'Audio de alta calidad',
              'Captura de fotos automática',
            ],
            color: Colors.blue,
            onTap:
                () => _showErrorMessage(
                  'Demo para capturas - Configurar productos en App Store Connect',
                ),
          ),

          const SizedBox(height: 16),

          // Plan anual CON PRECIO TEMPORAL
          _buildPlanCard(
            context,
            title: 'Plan Anual',
            price: '€19.99', // ← PRECIO TEMPORAL PARA CAPTURAS
            period: 'por año',
            originalPrice: '€35.88',
            features: [
              'Alertas de emergencia ilimitadas',
              'GPS de alta precisión',
              'Audio de alta calidad',
              'Captura de fotos automática',
              'Ahorra un 44%',
            ],
            color: Colors.green,
            isPopular: true,
            onTap:
                () => _showErrorMessage(
                  'Demo para capturas - Configurar productos en App Store Connect',
                ),
          ),
        ],
      );
    }

    // 📱 CÓDIGO ORIGINAL - Usará cuando _showPricesForScreenshots = false
    return Column(
      children: [
        // Plan mensual
        monthlyProductAsync.when(
          loading: () => _buildLoadingPlan('Plan Mensual'),
          error: (_, __) => _buildErrorPlan('Plan Mensual'),
          data: (product) {
            if (product == null) {
              return _buildErrorPlan('Plan Mensual');
            }

            return _buildPlanCard(
              context,
              title: 'Plan Mensual',
              price: product.price,
              period: 'por mes',
              features: [
                'Alertas de emergencia ilimitadas',
                'GPS de alta precisión',
                'Audio de alta calidad',
                'Captura de fotos automática',
              ],
              color: Colors.blue,
              onTap: () {
                if (product.isAvailable) {
                  _purchaseProduct(ProductType.monthly);
                } else {
                  _showErrorMessage('Producto no disponible');
                }
              },
            );
          },
        ),

        const SizedBox(height: 16),

        // Plan anual
        yearlyProductAsync.when(
          loading: () => _buildLoadingPlan('Plan Anual'),
          error: (_, __) => _buildErrorPlan('Plan Anual'),
          data: (product) {
            if (product == null) {
              return _buildErrorPlan('Plan Anual');
            }

            return _buildPlanCard(
              context,
              title: 'Plan Anual',
              price: product.price,
              period: 'por año',
              originalPrice: '€35.88',
              features: [
                'Alertas de emergencia ilimitadas',
                'GPS de alta precisión',
                'Audio de alta calidad',
                'Captura de fotos automática',
                'Ahorra un 44%',
              ],
              color: Colors.green,
              isPopular: true,
              onTap: () {
                if (product.isAvailable) {
                  _purchaseProduct(ProductType.yearly);
                } else {
                  _showErrorMessage('Producto no disponible');
                }
              },
            );
          },
        ),
      ],
    );
  }

  /// Construir plan de carga
  Widget _buildLoadingPlan(String title) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          const SpinKitThreeBounce(color: Colors.grey, size: 20.0),
        ],
      ),
    );
  }

  /// Construir plan de error
  Widget _buildErrorPlan(String title) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No disponible',
            style: GoogleFonts.nunito(fontSize: 14, color: Colors.red.shade600),
          ),
        ],
      ),
    );
  }

  /// Comprar producto
  Future<void> _purchaseProduct(ProductType productType) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final purchaseNotifier = ref.read(purchaseProvider.notifier);

      bool success = false;

      switch (productType) {
        case ProductType.trial:
          success = await purchaseNotifier.startTrial();
          break;
        case ProductType.monthly:
          success = await purchaseNotifier.purchaseMonthly();
          break;
        case ProductType.yearly:
          success = await purchaseNotifier.purchaseYearly();
          break;
      }

      if (success) {
        _showSuccessMessage('Compra iniciada correctamente');
      } else {
        _showErrorMessage('Error al iniciar la compra');
      }
    } catch (e) {
      _showErrorMessage('Error inesperado: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Restaurar compras
  Future<void> _restorePurchases(BuildContext context) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final purchaseNotifier = ref.read(purchaseProvider.notifier);
      final success = await purchaseNotifier.restorePurchases();

      if (success) {
        _showSuccessMessage('Restauración de compras iniciada');
      } else {
        _showErrorMessage('Error al restaurar compras');
      }
    } catch (e) {
      _showErrorMessage('Error inesperado: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Mostrar mensaje de éxito
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Mostrar mensaje de error
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Sección de restaurar compras (OBLIGATORIO para App Store y Google Play)
  Widget _buildRestorePurchasesSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.refresh, color: Colors.blue.shade600, size: 28),
          const SizedBox(height: 8),
          Text(
            '¿Ya compraste Premium?',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si ya tienes una suscripción activa o cambiaste de dispositivo, restaura tus compras aquí.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isProcessing ? null : () => _restorePurchases(context),
              icon:
                  _isProcessing
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(Icons.restore),
              label: Text(
                _isProcessing ? 'Restaurando...' : 'Restaurar Compras',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nota: Las compras se restauran automáticamente desde tu cuenta de App Store o Google Play.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
