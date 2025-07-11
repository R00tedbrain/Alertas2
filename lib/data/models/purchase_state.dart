import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/services/debug_logger.dart';

/// Estados posibles de una compra
enum PurchaseState {
  /// No hay compra activa
  none,

  /// Compra en proceso
  pending,

  /// Compra exitosa
  purchased,

  /// Compra falló
  error,

  /// Compra cancelada por el usuario
  cancelled,

  /// Compra restaurada
  restored,
}

/// Tipos de productos disponibles
enum ProductType {
  /// Prueba gratuita de 7 días
  trial,

  /// Suscripción mensual
  monthly,

  /// Suscripción anual
  yearly,
}

/// Modelo para el estado de suscripción premium
class PremiumSubscription {
  final bool isActive;
  final ProductType? productType;
  final DateTime? purchaseDate;
  final DateTime? expirationDate;
  final String? originalTransactionId;
  final String? productId;
  final PurchaseState state;
  final String? errorMessage;

  const PremiumSubscription({
    required this.isActive,
    this.productType,
    this.purchaseDate,
    this.expirationDate,
    this.originalTransactionId,
    this.productId,
    this.state = PurchaseState.none,
    this.errorMessage,
  });

  /// Suscripción vacía (sin premium)
  const PremiumSubscription.empty()
    : isActive = false,
      productType = null,
      purchaseDate = null,
      expirationDate = null,
      originalTransactionId = null,
      productId = null,
      state = PurchaseState.none,
      errorMessage = null;

  /// Suscripción con error
  const PremiumSubscription.error(String message)
    : isActive = false,
      productType = null,
      purchaseDate = null,
      expirationDate = null,
      originalTransactionId = null,
      productId = null,
      state = PurchaseState.error,
      errorMessage = message;

  /// Crear desde PurchaseDetails
  factory PremiumSubscription.fromPurchaseDetails(
    PurchaseDetails purchaseDetails,
    ProductType productType,
  ) {
    final DebugLogger debugLogger = DebugLogger.instance;
    const String tag = 'PremiumSubscription';

    debugLogger.info(
      tag,
      'Iniciando creación de suscripción desde PurchaseDetails',
    );
    debugLogger.info(tag, 'Product ID: ${purchaseDetails.productID}');
    debugLogger.info(tag, 'Product Type: ${productType.name}');
    debugLogger.info(tag, 'Purchase Status: ${purchaseDetails.status}');
    debugLogger.info(
      tag,
      'Transaction Date: ${purchaseDetails.transactionDate}',
    );
    debugLogger.info(tag, 'Purchase ID: ${purchaseDetails.purchaseID}');

    DateTime? purchaseDate;

    // Manejar fecha de transacción de manera robusta
    if (purchaseDetails.transactionDate != null) {
      debugLogger.info(tag, 'Procesando fecha de transacción...');
      try {
        // Intentar parsear como milliseconds primero
        final milliseconds = int.tryParse(purchaseDetails.transactionDate!);
        if (milliseconds != null) {
          purchaseDate = DateTime.fromMillisecondsSinceEpoch(milliseconds);
          debugLogger.info(
            tag,
            'Fecha parseada como milliseconds: $purchaseDate',
          );
        } else {
          // Si no es un número, intentar parsear como fecha string
          purchaseDate = DateTime.parse(purchaseDetails.transactionDate!);
          debugLogger.info(tag, 'Fecha parseada como string: $purchaseDate');
        }
      } catch (e) {
        // Si todo falla, usar la fecha actual
        purchaseDate = DateTime.now();
        debugLogger.warning(
          tag,
          'Error parseando fecha, usando fecha actual: $e',
        );
      }
    } else {
      // Si no hay fecha, usar la fecha actual
      purchaseDate = DateTime.now();
      debugLogger.info(tag, 'No hay fecha de transacción, usando fecha actual');
    }

    debugLogger.info(tag, 'Fecha final de compra: $purchaseDate');

    // Determinar si está activa
    final bool isActive = purchaseDetails.status == PurchaseStatus.purchased;
    debugLogger.info(tag, 'Compra activa: $isActive');

    // Mapear estado
    final PurchaseState state = _mapPurchaseStatus(purchaseDetails.status);
    debugLogger.info(tag, 'Estado mapeado: $state');

    final subscription = PremiumSubscription(
      isActive: isActive,
      productType: productType,
      purchaseDate: purchaseDate,
      originalTransactionId: purchaseDetails.purchaseID,
      productId: purchaseDetails.productID,
      state: state,
    );

    debugLogger.success(tag, 'Suscripción creada exitosamente');
    debugLogger.info(tag, 'Detalles de la suscripción:');
    debugLogger.info(tag, '  - isActive: ${subscription.isActive}');
    debugLogger.info(tag, '  - productType: ${subscription.productType}');
    debugLogger.info(tag, '  - purchaseDate: ${subscription.purchaseDate}');
    debugLogger.info(
      tag,
      '  - originalTransactionId: ${subscription.originalTransactionId}',
    );
    debugLogger.info(tag, '  - productId: ${subscription.productId}');
    debugLogger.info(tag, '  - state: ${subscription.state}');

    return subscription;
  }

  /// Mapear estado de compra
  static PurchaseState _mapPurchaseStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.pending:
        return PurchaseState.pending;
      case PurchaseStatus.purchased:
        return PurchaseState.purchased;
      case PurchaseStatus.error:
        return PurchaseState.error;
      case PurchaseStatus.canceled:
        return PurchaseState.cancelled;
      case PurchaseStatus.restored:
        return PurchaseState.restored;
    }
  }

  /// Copiar con nuevos valores
  PremiumSubscription copyWith({
    bool? isActive,
    ProductType? productType,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    String? originalTransactionId,
    String? productId,
    PurchaseState? state,
    String? errorMessage,
  }) {
    return PremiumSubscription(
      isActive: isActive ?? this.isActive,
      productType: productType ?? this.productType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      productId: productId ?? this.productId,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Verificar si la suscripción ha expirado
  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Verificar si es válida y activa
  bool get isValid => isActive && !isExpired;

  /// Días restantes de suscripción
  int get daysRemaining {
    if (expirationDate == null) return 0;
    final difference = expirationDate!.difference(DateTime.now());
    return difference.inDays.clamp(0, double.infinity).toInt();
  }

  /// Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'productType': productType?.name,
      'purchaseDate': purchaseDate?.millisecondsSinceEpoch,
      'expirationDate': expirationDate?.millisecondsSinceEpoch,
      'originalTransactionId': originalTransactionId,
      'productId': productId,
      'state': state.name,
      'errorMessage': errorMessage,
    };
  }

  /// Crear desde JSON
  factory PremiumSubscription.fromJson(Map<String, dynamic> json) {
    return PremiumSubscription(
      isActive: json['isActive'] ?? false,
      productType:
          json['productType'] != null
              ? ProductType.values.firstWhere(
                (e) => e.name == json['productType'],
                orElse: () => ProductType.monthly,
              )
              : null,
      purchaseDate:
          json['purchaseDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['purchaseDate'])
              : null,
      expirationDate:
          json['expirationDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['expirationDate'])
              : null,
      originalTransactionId: json['originalTransactionId'],
      productId: json['productId'],
      state: PurchaseState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => PurchaseState.none,
      ),
      errorMessage: json['errorMessage'],
    );
  }

  @override
  String toString() {
    return 'PremiumSubscription(isActive: $isActive, productType: $productType, state: $state)';
  }
}

/// Información de producto IAP
class IAPProduct {
  final String id;
  final String title;
  final String description;
  final String price;
  final String currencyCode;
  final ProductType type;
  final bool isAvailable;
  final ProductDetails? productDetails;

  const IAPProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.type,
    this.isAvailable = true,
    this.productDetails,
  });

  /// Crear desde ProductDetails
  factory IAPProduct.fromProductDetails(
    ProductDetails productDetails,
    ProductType type,
  ) {
    return IAPProduct(
      id: productDetails.id,
      title: productDetails.title,
      description: productDetails.description,
      price: productDetails.price,
      currencyCode: productDetails.currencyCode,
      type: type,
      isAvailable: true,
      productDetails: productDetails,
    );
  }

  /// Producto no disponible
  factory IAPProduct.unavailable(ProductType type) {
    return IAPProduct(
      id: type == ProductType.monthly ? 'premium_monthly' : 'premium_yearly',
      title: type == ProductType.monthly ? 'Premium Mensual' : 'Premium Anual',
      description: 'Producto no disponible',
      price: type == ProductType.monthly ? '€2.99' : '€19.99',
      currencyCode: 'EUR',
      type: type,
      isAvailable: false,
    );
  }

  @override
  String toString() {
    return 'IAPProduct(id: $id, title: $title, price: $price, available: $isAvailable)';
  }
}
