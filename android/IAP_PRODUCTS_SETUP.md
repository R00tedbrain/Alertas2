# Configuración de Productos IAP - Google Play Store

## Requisitos previos
- Cuenta de desarrollador de Google Play activa
- Aplicación creada en Google Play Console
- Clave de firma configurada y APK subido

## Configuración de Productos en Google Play Console

### 1. Acceder a Google Play Console
1. Ir a [Google Play Console](https://play.google.com/console/)
2. Seleccionar tu aplicación
3. Ir a "Monetización" > "Productos dentro de la aplicación"

### 2. Crear Producto Mensual
1. Hacer clic en "Crear producto"
2. Seleccionar "Suscripción"
3. Configurar:
   - **Product ID**: `premium_monthly`
   - **Name**: `AlertaTelegram Premium Monthly`
   - **Description**: `Elimina los anuncios y accede a funciones premium`
   - **Billing period**: `Monthly`
   - **Price**: `€2.99`

### 3. Crear Producto Anual
1. Crear otro producto de suscripción
2. Configurar:
   - **Product ID**: `premium_yearly`
   - **Name**: `AlertaTelegram Premium Yearly`
   - **Description**: `Elimina los anuncios y accede a funciones premium por un año completo`
   - **Billing period**: `Yearly`
   - **Price**: `€19.99`

### 4. Configurar Detalles de Suscripción
Para cada producto:

#### Información básica
- **Status**: Activo
- **Grace period**: 7 días (recomendado)
- **Account hold**: 30 días (recomendado)

#### Precios por país
- **España**: €2.99 / €19.99
- **Estados Unidos**: $2.99 / $19.99
- **Otros países**: Configurar según tier automático

#### Ofertas introductorias (opcional)
- **Prueba gratuita**: 7 días
- **Precio introductorio**: 50% descuento primer mes

### 5. Configurar Grupo de Suscripciones
1. Ir a "Suscripciones" > "Administrar grupo base"
2. Crear grupo: `AlertaTelegram Premium Group`
3. Agregar ambos productos al grupo
4. Configurar:
   - **Upgrade**: Anual puede actualizar desde mensual
   - **Downgrade**: Mensual puede degradar desde anual
   - **Prorate**: Enabled para cambios inmediatos

### 6. Configurar Términos y Condiciones
En la sección de cada producto:
- **Privacy Policy**: `https://tu-dominio.com/privacy-policy`
- **Terms of Service**: `https://tu-dominio.com/terms-of-service`

### 7. Configurar Testing
1. Ir a "Testing" > "License testing"
2. Agregar emails de cuentas de prueba
3. Configurar:
   - **Test purchases**: Enabled
   - **Test account response**: Purchased

### 8. Configurar Real-time Developer Notifications
1. Ir a "Monetización" > "Notificaciones"
2. Configurar:
   - **Notification endpoint**: `https://tu-servidor.com/webhook/google-play`
   - **Cloud Pub/Sub topic**: (opcional para mayor escala)

## Configuración en Android Studio

### 1. Permissions
En `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### 2. Dependencias
Ya incluidas en `pubspec.yaml`:
```yaml
dependencies:
  in_app_purchase: ^3.1.13
```

### 3. Configuración ProGuard (si se usa)
En `android/app/proguard-rules.pro`:
```
-keep class com.android.vending.billing.**
```

## IDs de Productos Definidos

### Productos configurados en el código:
```dart
// En lib/core/services/iap_service.dart
static const String _monthlyProductId = 'premium_monthly';
static const String _yearlyProductId = 'premium_yearly';
```

### Mapping de precios:
- **premium_monthly**: €2.99/mes
- **premium_yearly**: €19.99/año (equivale a €1.67/mes, ahorro 44%)

## Testing

### 1. Testing con Cuentas de Prueba
- Usar cuentas agregadas en "License testing"
- Los productos aparecen como "Test purchase" en la UI
- No se cobran las compras de prueba

### 2. Internal Testing
- Subir APK a "Internal testing"
- Probar con usuarios reales (pero usando sandbox)
- Verificar todos los flujos de compra

### 3. Play Console Testing
- Usar "Test purchases" en la consola
- Verificar que los productos aparecen correctamente
- Probar cancelaciones y renovaciones

## Configuración de Webhooks (Opcional)

### 1. Real-time Developer Notifications
Para manejar eventos en tiempo real:
```json
{
  "version": "1.0",
  "packageName": "com.emergencia.alerta_telegram",
  "eventTimeMillis": "1234567890123",
  "subscriptionNotification": {
    "version": "1.0",
    "notificationType": 2,
    "purchaseToken": "...",
    "subscriptionId": "premium_monthly"
  }
}
```

### 2. Validation Endpoint
Para validar compras en el servidor:
```
GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptions/{subscriptionId}/tokens/{token}
```

## Políticas Importantes

### 1. Cumplimiento con Google Play Policies
- Los productos deben ser consumidos dentro de 3 días
- Implementar "Restore Purchases" correctamente
- No mostrar precios externos

### 2. Restricciones
- No mencionar otras plataformas de pago
- No ofrecer precios diferentes fuera de Google Play
- Cumplir con las políticas de suscripciones

### 3. Localización
- Precios se ajustan automáticamente por región
- Descripción debe estar en idiomas principales
- Términos y condiciones deben estar localizados

## Troubleshooting Común

### Problema: "Item not found"
**Solución**: 
- Verificar Product IDs exactos
- Confirmar que productos están "Activos"
- Verificar que el APK está firmado correctamente

### Problema: "Authentication required"
**Solución**:
- Verificar que la app está firmada
- Usar cuenta de Google Play agregada a testing
- Verificar permisos BILLING

### Problema: "Purchase not available"
**Solución**:
- Verificar que el producto está disponible en el país
- Comprobar que la cuenta no tiene compras pendientes
- Verificar configuración de grupo de suscripciones

## Validación de Compras

### 1. Client-side Validation
```dart
// Verificar purchase token
bool isValidPurchase(PurchaseDetails purchaseDetails) {
  return purchaseDetails.status == PurchaseStatus.purchased &&
         purchaseDetails.purchaseID != null &&
         purchaseDetails.purchaseID!.isNotEmpty;
}
```

### 2. Server-side Validation (Recomendado)
```bash
# Usar Google Play Developer API
curl -X GET \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptions/{subscriptionId}/tokens/{token}" \
  -H "Authorization: Bearer {access_token}"
```

## Checklist Final

- [ ] Productos creados en Google Play Console
- [ ] IDs de productos coinciden con el código
- [ ] Precios configurados correctamente
- [ ] Grupo de suscripciones configurado
- [ ] Términos y condiciones subidos
- [ ] Testing accounts configuradas
- [ ] Real-time notifications configuradas (opcional)
- [ ] Permisos BILLING añadidos
- [ ] APK firmado subido
- [ ] Internal testing completado
- [ ] Políticas de Google Play revisadas

## Comandos Útiles

### Verificar configuración:
```bash
# Verificar permisos en AndroidManifest.xml
grep -r "BILLING" android/app/src/main/

# Verificar productos en código
grep -r "premium_monthly\|premium_yearly" lib/
```

### Debug de compras:
```dart
// Logs para debug
print('Available products: ${InAppPurchase.instance.}');
print('Purchase status: ${purchaseDetails.status}');
print('Purchase ID: ${purchaseDetails.purchaseID}');
```

## Recursos Adicionales

- [Google Play Billing Library](https://developer.android.com/google/play/billing)
- [Play Console Help](https://support.google.com/googleplay/android-developer/)
- [In-App Purchase Testing Guide](https://developer.android.com/google/play/billing/test) 