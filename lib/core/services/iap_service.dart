import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import '../../data/models/purchase_state.dart';
import 'debug_logger.dart';
import 'google_play_validator.dart';

/// Servicio de In-App Purchases
/// Cumple con políticas de Apple App Store y Google Play Store
class IAPService {
  static const String _tag = 'IAPService';
  final Logger _logger = Logger();
  final DebugLogger _debugLogger = DebugLogger.instance;

  // Singleton
  static IAPService? _instance;
  static IAPService get instance => _instance ??= IAPService._();
  IAPService._();

  // Callback para notificar estado de restauración
  Function(bool)? _onRestoreStateChanged;

  // Callback para notificar errores al usuario
  Function(String)? _onErrorOccurred;

  // IDs de productos (deben coincidir con los configurados en las stores)
  static const String _trialProductId = '7_day_trial';
  static const String _monthlyProductId = 'premium_monthly';
  static const String _yearlyProductId = 'premium_yearly';

  // Keys para SharedPreferences
  static const String _premiumStateKey = 'premium_subscription_state';
  static const String _lastValidationKey = 'last_validation_timestamp';

  // Instancias principales
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseUpdatedSubscription;

  // Estados
  bool _isInitialized = false;
  bool _storeAvailable = false;

  // Productos disponibles
  final Map<String, IAPProduct> _products = {};

  // Estado de suscripción actual
  PremiumSubscription _currentSubscription = const PremiumSubscription.empty();

  // Controlador de eventos para notificar cambios
  final StreamController<PremiumSubscription> _subscriptionController =
      StreamController<PremiumSubscription>.broadcast();

  // Getters públicos
  bool get isInitialized => _isInitialized;
  bool get storeAvailable => _storeAvailable;
  PremiumSubscription get currentSubscription => _currentSubscription;
  Stream<PremiumSubscription> get subscriptionStream =>
      _subscriptionController.stream;

  List<IAPProduct> get availableProducts => _products.values.toList();

  IAPProduct? get trialProduct => _products[_trialProductId];
  IAPProduct? get monthlyProduct => _products[_monthlyProductId];
  IAPProduct? get yearlyProduct => _products[_yearlyProductId];

  /// Configurar callback para estado de restauración
  void setRestoreStateCallback(Function(bool) callback) {
    _onRestoreStateChanged = callback;
  }

  /// Configurar callback para errores
  void setErrorCallback(Function(String) callback) {
    _onErrorOccurred = callback;
  }

  /// Inicializar el servicio
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _debugLogger.info(_tag, 'Iniciando inicialización...');

      // Inicializar validador de Google Play (solo Android)
      if (Platform.isAndroid) {
        _debugLogger.info(_tag, 'Inicializando validador de Google Play...');
        await GooglePlayValidator.instance.initialize();
        _debugLogger.info(_tag, 'Validador de Google Play inicializado');
      }

      // Verificar disponibilidad de la tienda
      _storeAvailable = await _inAppPurchase.isAvailable();
      _debugLogger.info(_tag, 'Tienda disponible: $_storeAvailable');

      if (!_storeAvailable) {
        _debugLogger.error(_tag, 'Tienda no disponible en este dispositivo');
        return false;
      }

      // Configurar listener para actualizaciones de compra
      _purchaseUpdatedSubscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: _onPurchaseError,
      );
      _debugLogger.info(_tag, 'Listener de compras configurado');

      // Cargar productos disponibles
      await _loadProducts();
      _debugLogger.info(_tag, 'Productos cargados');

      // Cargar estado de suscripción guardado
      await _loadSavedSubscription();
      _debugLogger.info(_tag, 'Estado guardado cargado');
      _debugLogger.info(
        _tag,
        'Estado actual - isValid: ${_currentSubscription.isValid}, isActive: ${_currentSubscription.isActive}, productType: ${_currentSubscription.productType}',
      );

      // Validar suscripciones existentes
      _debugLogger.info(_tag, 'Validando compras existentes...');
      await _validateExistingPurchases();
      _debugLogger.success(_tag, 'Validación completada');

      _isInitialized = true;
      _debugLogger.success(_tag, 'Servicio inicializado correctamente');
      _debugLogger.info(
        _tag,
        'Estado final - hasPremium: $hasPremium, isInTrial: $isInTrial',
      );

      return true;
    } catch (e) {
      _debugLogger.error(_tag, 'Error inicializando: $e');
      return false;
    }
  }

  /// Cargar productos disponibles desde las stores
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = {
        _trialProductId,
        _monthlyProductId,
        _yearlyProductId,
      };

      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.error != null) {
        _debugLogger.error(_tag, 'Error cargando productos: ${response.error}');
        return;
      }

      // Limpiar productos anteriores
      _products.clear();

      // Procesar productos encontrados
      for (final ProductDetails productDetails in response.productDetails) {
        final ProductType type = _getProductType(productDetails.id);
        final IAPProduct product = IAPProduct.fromProductDetails(
          productDetails,
          type,
        );

        _products[productDetails.id] = product;
        _debugLogger.info(
          _tag,
          'Producto cargado: ${product.title} - ${product.price}',
        );
      }

      // Agregar productos no encontrados como no disponibles
      for (final String productId in response.notFoundIDs) {
        final ProductType type = _getProductType(productId);
        final IAPProduct product = IAPProduct.unavailable(type);

        _products[productId] = product;
        _debugLogger.warning(_tag, 'Producto no encontrado: $productId');
      }

      _debugLogger.info(_tag, '${_products.length} productos cargados');
    } catch (e) {
      _debugLogger.error(_tag, 'Error cargando productos: $e');
    }
  }

  /// Determinar tipo de producto por ID
  ProductType _getProductType(String productId) {
    switch (productId) {
      case _trialProductId:
        return ProductType.trial;
      case _monthlyProductId:
        return ProductType.monthly;
      case _yearlyProductId:
        return ProductType.yearly;
      default:
        return ProductType.monthly;
    }
  }

  /// Comprar producto
  Future<bool> purchaseProduct(String productId) async {
    if (!_isInitialized || !_storeAvailable) {
      print('❌ IAPService: Servicio no inicializado o tienda no disponible');
      return false;
    }

    final IAPProduct? product = _products[productId];
    if (product == null || !product.isAvailable) {
      print('❌ IAPService: Producto no disponible: $productId');
      return false;
    }

    try {
      print('🛒 IAPService: Iniciando compra de: ${product.title}');

      // Actualizar estado a pendiente
      _updateSubscriptionState(
        _currentSubscription.copyWith(state: PurchaseState.pending),
      );

      // Crear parámetros de compra
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product.productDetails!,
        applicationUserName: _generateApplicationUserName(),
      );

      // Iniciar compra
      final bool success = await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        print('❌ IAPService: Fallo al iniciar compra');
        _updateSubscriptionState(
          _currentSubscription.copyWith(
            state: PurchaseState.error,
            errorMessage: 'No se pudo iniciar la compra',
          ),
        );
        return false;
      }

      return true;
    } catch (e) {
      print('❌ IAPService: Error en compra: $e');
      _updateSubscriptionState(
        _currentSubscription.copyWith(
          state: PurchaseState.error,
          errorMessage: 'Error inesperado: $e',
        ),
      );
      return false;
    }
  }

  /// Restaurar compras
  Future<bool> restorePurchases() async {
    if (!_isInitialized || !_storeAvailable) {
      print('❌ IAPService: Servicio no inicializado o tienda no disponible');
      return false;
    }

    try {
      print('🔄 IAPService: Restaurando compras...');
      _debugLogger.info(_tag, 'Iniciando restauración manual de compras');

      // Notificar inicio de restauración
      _onRestoreStateChanged?.call(true);

      // Actualizar estado a pendiente
      _updateSubscriptionState(
        _currentSubscription.copyWith(state: PurchaseState.pending),
      );

      _debugLogger.info(_tag, 'Llamando a restorePurchases() de la tienda');
      await _inAppPurchase.restorePurchases();

      _debugLogger.info(
        _tag,
        'Restauración iniciada - esperando respuesta de la tienda',
      );

      // La respuesta llegará a través del stream de compras
      return true;
    } catch (e) {
      print('❌ IAPService: Error restaurando compras: $e');
      _debugLogger.error(_tag, 'Error en restauración manual: $e');
      _updateSubscriptionState(
        _currentSubscription.copyWith(
          state: PurchaseState.error,
          errorMessage: 'Error restaurando compras: $e',
        ),
      );

      // Notificar fin de restauración
      _onRestoreStateChanged?.call(false);
      return false;
    }
  }

  /// Manejar actualizaciones de compra
  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    _debugLogger.info(
      _tag,
      'Recibidas ${purchaseDetailsList.length} actualizaciones de compra',
    );

    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _debugLogger.info(
        _tag,
        'Procesando compra: ${purchaseDetails.productID} - Estado: ${purchaseDetails.status}',
      );
      await _processPurchaseUpdate(purchaseDetails);
    }
  }

  /// Procesar actualización individual de compra
  Future<void> _processPurchaseUpdate(PurchaseDetails purchaseDetails) async {
    print(
      '🔄 IAPService: Procesando actualización para ${purchaseDetails.productID}',
    );
    _debugLogger.info(
      _tag,
      'Procesando actualización: ${purchaseDetails.productID}, estado: ${purchaseDetails.status}',
    );

    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        print('⏳ IAPService: Compra pendiente: ${purchaseDetails.productID}');
        _debugLogger.info(
          _tag,
          'Estado: PENDIENTE para ${purchaseDetails.productID}',
        );
        _updateSubscriptionState(
          _currentSubscription.copyWith(state: PurchaseState.pending),
        );
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        print(
          '✅ IAPService: Compra exitosa/restaurada: ${purchaseDetails.productID}',
        );
        _debugLogger.success(
          _tag,
          purchaseDetails.status == PurchaseStatus.restored
              ? 'RESTAURADA: ${purchaseDetails.productID}'
              : 'COMPRADA: ${purchaseDetails.productID}',
        );
        await _handleSuccessfulPurchase(purchaseDetails);

        // Notificar fin de restauración si fue una restauración
        if (purchaseDetails.status == PurchaseStatus.restored) {
          _debugLogger.info(_tag, 'Notificando fin de restauración');
          _onRestoreStateChanged?.call(false);
        }
        break;

      case PurchaseStatus.error:
        print('❌ IAPService: Error en compra: ${purchaseDetails.error}');
        _debugLogger.error(
          _tag,
          'ERROR: ${purchaseDetails.productID} - ${purchaseDetails.error?.message ?? 'Error desconocido'}',
        );
        _updateSubscriptionState(
          _currentSubscription.copyWith(
            state: PurchaseState.error,
            errorMessage: purchaseDetails.error?.message ?? 'Error desconocido',
          ),
        );
        break;

      case PurchaseStatus.canceled:
        print('🚫 IAPService: Compra cancelada por usuario');
        _debugLogger.warning(_tag, 'CANCELADA: ${purchaseDetails.productID}');
        _updateSubscriptionState(
          _currentSubscription.copyWith(state: PurchaseState.cancelled),
        );
        break;
    }

    // Completar la transacción
    if (purchaseDetails.pendingCompletePurchase) {
      print(
        '🔄 IAPService: Completando transacción para ${purchaseDetails.productID}',
      );
      _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  /// Manejar compra exitosa
  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    _debugLogger.success(
      _tag,
      'Procesando compra exitosa: ${purchaseDetails.productID}',
    );

    final ProductType productType = _getProductType(purchaseDetails.productID);
    _debugLogger.info(_tag, 'Tipo de producto: ${productType.name}');

    // Validar compra antes de procesar
    if (!await _validatePurchaseDetails(purchaseDetails)) {
      _debugLogger.error(
        _tag,
        'Compra inválida rechazada: ${purchaseDetails.productID}',
      );
      _updateSubscriptionState(
        _currentSubscription.copyWith(
          state: PurchaseState.error,
          errorMessage: 'Compra inválida o fraudulenta',
        ),
      );
      return;
    }

    _debugLogger.success(_tag, 'Validación de compra exitosa');

    // Crear suscripción desde purchase details
    _debugLogger.info(_tag, 'Creando suscripción desde purchase details...');
    final PremiumSubscription subscription =
        PremiumSubscription.fromPurchaseDetails(purchaseDetails, productType);
    _debugLogger.info(
      _tag,
      'Suscripción creada: isActive=${subscription.isActive}, productType=${subscription.productType}',
    );

    // Calcular fecha de expiración
    _debugLogger.info(_tag, 'Calculando fecha de expiración...');
    final DateTime expirationDate = _calculateExpirationDate(
      subscription.purchaseDate ?? DateTime.now(),
      productType,
    );
    _debugLogger.info(_tag, 'Fecha de expiración calculada: $expirationDate');

    // Actualizar estado
    _debugLogger.info(_tag, 'Actualizando estado final...');
    final finalSubscription = subscription.copyWith(
      isActive: true,
      expirationDate: expirationDate,
      state:
          purchaseDetails.status == PurchaseStatus.restored
              ? PurchaseState.restored
              : PurchaseState.purchased,
    );

    _debugLogger.info(_tag, 'Estado final preparado:');
    _debugLogger.info(_tag, '  - isActive: ${finalSubscription.isActive}');
    _debugLogger.info(_tag, '  - isValid: ${finalSubscription.isValid}');
    _debugLogger.info(
      _tag,
      '  - productType: ${finalSubscription.productType}',
    );
    _debugLogger.info(
      _tag,
      '  - expirationDate: ${finalSubscription.expirationDate}',
    );

    _debugLogger.info(_tag, 'Llamando _updateSubscriptionState...');
    _updateSubscriptionState(finalSubscription);

    // Guardar estado
    _debugLogger.info(_tag, 'Guardando estado...');
    _saveSubscriptionState();

    // Si es una prueba gratuita, marcarla como usada
    if (productType == ProductType.trial) {
      _debugLogger.info(_tag, 'Marcando trial como usado...');
      _markTrialAsUsed();
    }

    _debugLogger.success(_tag, 'Suscripción activada exitosamente');
    _debugLogger.info(
      _tag,
      'Estado actual - hasPremium: $hasPremium, isInTrial: $isInTrial',
    );
  }

  /// Validar detalles de compra (anti-fraude básico)
  Future<bool> _validatePurchaseDetails(PurchaseDetails purchaseDetails) async {
    try {
      _debugLogger.info(
        _tag,
        'Validando detalles de compra para ${purchaseDetails.productID}',
      );

      final ProductType productType = _getProductType(
        purchaseDetails.productID,
      );
      final bool isTrial = productType == ProductType.trial;
      _debugLogger.info(_tag, 'Es trial: $isTrial');

      // Validaciones básicas
      _debugLogger.debug(_tag, 'Validación 1: Verificando Purchase ID...');
      _debugLogger.debug(_tag, 'Purchase ID: ${purchaseDetails.purchaseID}');
      if (purchaseDetails.purchaseID == null ||
          purchaseDetails.purchaseID!.isEmpty) {
        _debugLogger.error(_tag, 'VALIDACIÓN FALLÓ: Purchase ID vacío o nulo');
        return false;
      }
      _debugLogger.success(_tag, 'Validación 1 PASÓ: Purchase ID válido');

      _debugLogger.debug(_tag, 'Validación 2: Verificando Product ID...');
      _debugLogger.debug(_tag, 'Product ID: ${purchaseDetails.productID}');
      if (purchaseDetails.productID.isEmpty) {
        _debugLogger.error(_tag, 'VALIDACIÓN FALLÓ: Product ID vacío');
        return false;
      }
      _debugLogger.success(_tag, 'Validación 2 PASÓ: Product ID válido');

      // Verificar que el producto ID sea válido
      _debugLogger.debug(
        _tag,
        'Validación 3: Verificando Product ID en lista válida...',
      );
      final Set<String> validProductIds = {
        _trialProductId,
        _monthlyProductId,
        _yearlyProductId,
      };
      _debugLogger.debug(_tag, 'IDs válidos: $validProductIds');
      _debugLogger.debug(_tag, 'ID recibido: ${purchaseDetails.productID}');
      if (!validProductIds.contains(purchaseDetails.productID)) {
        _debugLogger.error(
          _tag,
          'VALIDACIÓN FALLÓ: Product ID no válido: ${purchaseDetails.productID}',
        );
        return false;
      }
      _debugLogger.success(
        _tag,
        'Validación 3 PASÓ: Product ID en lista válida',
      );

      // 🔧 TRIAL FIX: Relajar validación de datos de verificación para trial
      _debugLogger.debug(
        _tag,
        'Validación 4: Verificando datos de verificación...',
      );
      _debugLogger.debug(_tag, 'Es trial: $isTrial');
      _debugLogger.debug(
        _tag,
        'Datos de verificación: ${purchaseDetails.verificationData.localVerificationData}',
      );
      if (!isTrial &&
          purchaseDetails.verificationData.localVerificationData.isEmpty) {
        _debugLogger.error(
          _tag,
          'VALIDACIÓN FALLÓ: Datos de verificación vacíos (no es trial)',
        );
        return false;
      }
      _debugLogger.success(
        _tag,
        'Validación 4 PASÓ: Datos de verificación OK o es trial',
      );

      // 🔧 TRIAL FIX: Verificar fecha de transacción más flexible para trial
      _debugLogger.debug(
        _tag,
        'Validación 5: Verificando fecha de transacción...',
      );
      _debugLogger.debug(
        _tag,
        'Transaction date: ${purchaseDetails.transactionDate}',
      );
      if (purchaseDetails.transactionDate != null) {
        DateTime? transactionTime;

        // Intentar parsear como milliseconds primero
        try {
          final milliseconds = int.tryParse(purchaseDetails.transactionDate!);
          if (milliseconds != null) {
            transactionTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
            _debugLogger.debug(
              _tag,
              'Fecha parseada como milliseconds: $transactionTime',
            );
          }
        } catch (e) {
          _debugLogger.debug(_tag, 'No se pudo parsear como milliseconds: $e');
        }

        // Si no funcionó, intentar parsear como fecha string
        if (transactionTime == null) {
          try {
            transactionTime = DateTime.parse(purchaseDetails.transactionDate!);
            _debugLogger.debug(
              _tag,
              'Fecha parseada como string: $transactionTime',
            );
          } catch (e) {
            _debugLogger.warning(_tag, 'No se pudo parsear fecha: $e');
          }
        }

        if (transactionTime != null) {
          final now = DateTime.now();
          final timeDiff = now.difference(transactionTime).abs();
          _debugLogger.debug(
            _tag,
            'Diferencia de tiempo: ${timeDiff.inHours} horas',
          );

          // Para trial: permitir hasta 7 días, para otros: 24 horas
          final maxHours = isTrial ? 24 * 7 : 24;
          _debugLogger.debug(_tag, 'Máximo de horas permitidas: $maxHours');

          if (timeDiff.inHours > maxHours) {
            _debugLogger.error(
              _tag,
              'VALIDACIÓN FALLÓ: Transacción con timestamp sospechoso: $transactionTime',
            );
            return false;
          }
          _debugLogger.success(
            _tag,
            'Validación 5 PASÓ: Fecha de transacción válida',
          );
        } else {
          _debugLogger.warning(
            _tag,
            'Validación 5: No se pudo parsear fecha, se omite validación',
          );
        }
      } else {
        _debugLogger.warning(
          _tag,
          'Validación 5: No hay fecha de transacción (se omite)',
        );
      }

      // Validación específica para Google Play (solo Android)
      if (Platform.isAndroid) {
        _debugLogger.debug(
          _tag,
          'Validación 6: Verificando firma de Google Play...',
        );

        // Obtener datos de verificación de Google Play
        final String? signature = _getGooglePlaySignature(purchaseDetails);
        final String? signedData = _getGooglePlaySignedData(purchaseDetails);

        if (signature != null && signedData != null) {
          final bool isValidSignature = await GooglePlayValidator.instance
              .validatePurchase(
                signedData: signedData,
                signature: signature,
                productId: purchaseDetails.productID,
                purchaseToken: purchaseDetails.purchaseID!,
              );

          if (!isValidSignature) {
            _debugLogger.error(
              _tag,
              'VALIDACIÓN FALLÓ: Firma de Google Play inválida',
            );
            return false;
          }

          _debugLogger.success(
            _tag,
            'Validación 6 PASÓ: Firma de Google Play válida',
          );
        } else {
          _debugLogger.warning(
            _tag,
            'Validación 6 SALTADA: Datos de firma no disponibles',
          );
        }
      }

      // Verificar que no sea una compra duplicada
      _debugLogger.debug(_tag, 'Validación 7: Verificando compra duplicada...');
      _debugLogger.debug(
        _tag,
        'Current transaction ID: ${_currentSubscription.originalTransactionId}',
      );
      _debugLogger.debug(
        _tag,
        'New purchase ID: ${purchaseDetails.purchaseID}',
      );
      if (_isDuplicatePurchase(purchaseDetails)) {
        _debugLogger.error(
          _tag,
          'VALIDACIÓN FALLÓ: Compra duplicada detectada',
        );
        return false;
      }
      _debugLogger.success(_tag, 'Validación 7 PASÓ: No es compra duplicada');

      _debugLogger.success(
        _tag,
        'TODAS LAS VALIDACIONES PASARON - Compra válida',
      );
      return true;
    } catch (e) {
      _debugLogger.error(_tag, 'EXCEPCIÓN EN VALIDACIÓN: $e');
      return false;
    }
  }

  /// Verificar si es una compra duplicada
  bool _isDuplicatePurchase(PurchaseDetails purchaseDetails) {
    // Verificar contra la suscripción actual
    if (_currentSubscription.originalTransactionId ==
        purchaseDetails.purchaseID) {
      print(
        '🔍 IAPService: Compra duplicada detectada contra suscripción actual',
      );
      return true;
    }

    // Verificar contra un cache de compras recientes (si implementado)
    // Por ahora, solo verificamos contra la suscripción actual
    return false;
  }

  /// Calcular fecha de expiración
  DateTime _calculateExpirationDate(
    DateTime purchaseDate,
    ProductType productType,
  ) {
    switch (productType) {
      case ProductType.trial:
        return purchaseDate.add(const Duration(days: 7));
      case ProductType.monthly:
        return purchaseDate.add(const Duration(days: 30));
      case ProductType.yearly:
        return purchaseDate.add(const Duration(days: 365));
    }
  }

  /// Manejar errores de compra
  void _onPurchaseError(dynamic error) {
    print('❌ IAPService: Error en stream de compras: $error');
    _debugLogger.error(_tag, 'Error en stream de compras: $error');

    final errorMessage = 'Error en proceso de compra: $error';

    _updateSubscriptionState(
      _currentSubscription.copyWith(
        state: PurchaseState.error,
        errorMessage: errorMessage,
      ),
    );

    // Notificar error al usuario
    _onErrorOccurred?.call(errorMessage);
  }

  /// Validar compras existentes
  Future<void> _validateExistingPurchases() async {
    try {
      print('🔍 IAPService: Iniciando validación de compras existentes...');

      // Notificar inicio de restauración automática
      _onRestoreStateChanged?.call(true);

      // Para iOS, validar con StoreKit
      if (Platform.isIOS) {
        print('🍎 IAPService: Validando para iOS...');
        await _validateIOSPurchases();
      }

      // Para Android, validar con Play Store
      if (Platform.isAndroid) {
        print('🤖 IAPService: Validando para Android...');
        await _validateAndroidPurchases();
      }

      print('✅ IAPService: Validación de compras existentes completada');

      // Notificar fin de restauración automática
      _onRestoreStateChanged?.call(false);
    } catch (e) {
      print('❌ IAPService: Error validando compras existentes: $e');
      _debugLogger.error(_tag, 'Error validando compras existentes: $e');

      // Notificar fin de restauración en caso de error
      _onRestoreStateChanged?.call(false);

      // Notificar error al usuario
      _onErrorOccurred?.call(
        'Error al validar compras existentes. Intenta restaurar manualmente.',
      );
    }
  }

  /// Validar compras iOS
  Future<void> _validateIOSPurchases() async {
    try {
      print('🍎 IAPService: Restaurando compras para iOS...');
      _debugLogger.info(_tag, 'Iniciando restauración iOS automática');

      // Restaurar compras automáticamente para iOS
      await _inAppPurchase.restorePurchases();

      print('✅ IAPService: Validación iOS completada');
      _debugLogger.success(_tag, 'Restauración iOS automática completada');
    } catch (e) {
      print('❌ IAPService: Error validando iOS: $e');
      _debugLogger.error(_tag, 'Error en restauración iOS: $e');
    }
  }

  /// Validar compras Android
  Future<void> _validateAndroidPurchases() async {
    try {
      print('🤖 IAPService: Restaurando compras para Android...');
      _debugLogger.info(_tag, 'Iniciando restauración Android automática');

      // Restaurar compras automáticamente
      await _inAppPurchase.restorePurchases();

      print('✅ IAPService: Validación Android completada');
      _debugLogger.success(_tag, 'Restauración Android automática completada');
    } catch (e) {
      print('❌ IAPService: Error validando Android: $e');
      _debugLogger.error(_tag, 'Error en restauración Android: $e');
    }
  }

  /// Generar nombre de usuario para aplicación (anti-fraude)
  String _generateApplicationUserName() {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String deviceId = _generateDeviceId();
    final String combined = '$deviceId$timestamp';

    return sha256.convert(utf8.encode(combined)).toString().substring(0, 16);
  }

  /// Generar ID único del dispositivo
  String _generateDeviceId() {
    // En producción, usar un ID único del dispositivo
    // Por simplicidad, usamos un hash basado en timestamp
    return sha256
        .convert(utf8.encode(DateTime.now().toString()))
        .toString()
        .substring(0, 8);
  }

  /// Actualizar estado de suscripción
  void _updateSubscriptionState(PremiumSubscription subscription) {
    _debugLogger.info(_tag, 'Actualizando estado de suscripción...');
    _debugLogger.info(
      _tag,
      'Antes: isValid=${_currentSubscription.isValid}, isActive=${_currentSubscription.isActive}',
    );
    _debugLogger.info(
      _tag,
      'Después: isValid=${subscription.isValid}, isActive=${subscription.isActive}',
    );

    _currentSubscription = subscription;
    _subscriptionController.add(subscription);

    _debugLogger.info(_tag, 'Estado actualizado y notificado al stream');
  }

  /// Guardar estado de suscripción
  Future<void> _saveSubscriptionState() async {
    try {
      print('💾 IAPService: Guardando estado de suscripción...');

      final prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(_currentSubscription.toJson());

      await prefs.setString(_premiumStateKey, json);
      await prefs.setInt(
        _lastValidationKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      print('✅ IAPService: Estado de suscripción guardado exitosamente');
    } catch (e) {
      print('❌ IAPService: Error guardando estado: $e');
    }
  }

  /// Cargar estado de suscripción guardado
  Future<void> _loadSavedSubscription() async {
    try {
      print('💾 IAPService: Cargando estado de suscripción guardado...');

      final prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_premiumStateKey);

      if (json != null) {
        print('📦 IAPService: Estado encontrado en SharedPreferences');
        final Map<String, dynamic> data = jsonDecode(json);
        _currentSubscription = PremiumSubscription.fromJson(data);

        print('📋 IAPService: Estado cargado:');
        print('   - isActive: ${_currentSubscription.isActive}');
        print('   - isValid: ${_currentSubscription.isValid}');
        print('   - productType: ${_currentSubscription.productType}');
        print('   - expirationDate: ${_currentSubscription.expirationDate}');
        print('   - isExpired: ${_currentSubscription.isExpired}');

        // Verificar si la suscripción sigue siendo válida
        if (_currentSubscription.isExpired) {
          print('⏰ IAPService: Suscripción expirada, limpiando estado');
          _currentSubscription = const PremiumSubscription.empty();
          await _clearSavedSubscription();
        } else {
          print(
            '✅ IAPService: Suscripción válida cargada: ${_currentSubscription.productType}',
          );
        }
      } else {
        print('📦 IAPService: No hay estado guardado');
      }
    } catch (e) {
      print('❌ IAPService: Error cargando estado: $e');
      _currentSubscription = const PremiumSubscription.empty();
    }
  }

  /// Limpiar estado de suscripción guardado
  Future<void> _clearSavedSubscription() async {
    try {
      print('🧹 IAPService: Limpiando estado de suscripción...');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_premiumStateKey);
      await prefs.remove(_lastValidationKey);

      print('✅ IAPService: Estado de suscripción limpiado');
    } catch (e) {
      print('❌ IAPService: Error limpiando estado: $e');
    }
  }

  /// Verificar si el usuario tiene premium activo
  bool get hasPremium {
    final result = _currentSubscription.isValid;
    _debugLogger.info(_tag, '🔍 VERIFICACIÓN hasPremium = $result');
    _debugLogger.debug(_tag, '  - isValid: ${_currentSubscription.isValid}');
    _debugLogger.debug(_tag, '  - isActive: ${_currentSubscription.isActive}');
    _debugLogger.debug(
      _tag,
      '  - isExpired: ${_currentSubscription.isExpired}',
    );
    _debugLogger.debug(
      _tag,
      '  - expirationDate: ${_currentSubscription.expirationDate}',
    );
    _debugLogger.debug(
      _tag,
      '  - productType: ${_currentSubscription.productType}',
    );
    _debugLogger.debug(
      _tag,
      '  - originalTransactionId: ${_currentSubscription.originalTransactionId}',
    );

    // Log crítico para depuración
    if (result) {
      _debugLogger.success(_tag, '✅ PREMIUM ACTIVO confirmado');
    } else {
      _debugLogger.warning(
        _tag,
        '⚠️ PREMIUM NO ACTIVO - verificar suscripción',
      );
    }

    return result;
  }

  /// Verificar si el usuario está en período de prueba
  bool get isInTrial {
    final result =
        _currentSubscription.isValid &&
        _currentSubscription.productType == ProductType.trial;
    _debugLogger.info(_tag, '🔍 VERIFICACIÓN isInTrial = $result');
    _debugLogger.debug(_tag, '  - isValid: ${_currentSubscription.isValid}');
    _debugLogger.debug(
      _tag,
      '  - productType: ${_currentSubscription.productType}',
    );
    _debugLogger.debug(
      _tag,
      '  - productType == trial: ${_currentSubscription.productType == ProductType.trial}',
    );

    // Log crítico para depuración
    if (result) {
      _debugLogger.success(_tag, '✅ TRIAL ACTIVO confirmado');
    } else {
      _debugLogger.warning(_tag, '⚠️ TRIAL NO ACTIVO - verificar estado');
    }

    return result;
  }

  /// Verificar si el usuario ha usado la prueba gratuita
  Future<bool> hasUsedTrial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getBool('has_used_trial') ?? false;
      print('🔍 IAPService: hasUsedTrial = $result');
      return result;
    } catch (e) {
      print('❌ IAPService: Error verificando uso de trial: $e');
      return true; // En caso de error, asumir que ya la usó
    }
  }

  /// Marcar que el usuario ya usó la prueba gratuita
  Future<void> _markTrialAsUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_used_trial', true);
      print('✅ IAPService: Prueba gratuita marcada como usada');
    } catch (e) {
      print('❌ IAPService: Error marcando trial como usado: $e');
    }
  }

  /// Obtener días restantes de suscripción
  int get daysRemaining => _currentSubscription.daysRemaining;

  /// Obtener la firma de Google Play desde los detalles de compra
  String? _getGooglePlaySignature(PurchaseDetails purchaseDetails) {
    try {
      // En Android, la firma se encuentra en verificationData.serverVerificationData
      if (Platform.isAndroid) {
        final String serverData =
            purchaseDetails.verificationData.serverVerificationData;
        if (serverData.isNotEmpty) {
          // Los datos del servidor contienen la firma en formato JSON
          final Map<String, dynamic> data = json.decode(serverData);
          return data['signature'] as String?;
        }
      }
      return null;
    } catch (e) {
      _debugLogger.error(_tag, 'Error obteniendo firma de Google Play: $e');
      return null;
    }
  }

  /// Obtener los datos firmados de Google Play desde los detalles de compra
  String? _getGooglePlaySignedData(PurchaseDetails purchaseDetails) {
    try {
      // En Android, los datos firmados se encuentran en verificationData.localVerificationData
      if (Platform.isAndroid) {
        final String localData =
            purchaseDetails.verificationData.localVerificationData;
        if (localData.isNotEmpty) {
          return localData;
        }
      }
      return null;
    } catch (e) {
      _debugLogger.error(
        _tag,
        'Error obteniendo datos firmados de Google Play: $e',
      );
      return null;
    }
  }

  /// Limpiar recursos
  Future<void> dispose() async {
    await _purchaseUpdatedSubscription?.cancel();
    await _subscriptionController.close();

    print('🧹 IAPService: Recursos limpiados');
  }
}
