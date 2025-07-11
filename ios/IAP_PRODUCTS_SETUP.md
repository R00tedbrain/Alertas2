# Configuración de Productos IAP - iOS App Store

## Requisitos previos
- Cuenta de desarrollador de Apple activa
- Aplicación creada en App Store Connect
- Certificados y perfiles de aprovisionamiento configurados

## Configuración de Productos en App Store Connect

### 1. Acceder a App Store Connect
1. Ir a [App Store Connect](https://appstoreconnect.apple.com/)
2. Seleccionar tu aplicación
3. Ir a la sección "In-App Purchases"

### 2. Crear Producto Mensual
1. Hacer clic en "+" para crear un nuevo producto
2. Seleccionar "Auto-Renewable Subscription"
3. Configurar:
   - **Product ID**: `premium_monthly`
   - **Reference Name**: `AlertaTelegram Premium Monthly`
   - **Subscription Group**: `AlertaTelegram Premium Group`
   - **Subscription Duration**: `1 month`
   - **Price**: `€2.99` (Tier 3)

### 3. Crear Producto Anual
1. Crear otro producto en el mismo grupo de suscripción
2. Configurar:
   - **Product ID**: `premium_yearly`
   - **Reference Name**: `AlertaTelegram Premium Yearly`
   - **Subscription Group**: `AlertaTelegram Premium Group`
   - **Subscription Duration**: `1 year`
   - **Price**: `€19.99` (Tier 25)

### 4. Configurar Metadatos
Para cada producto, completar:

#### Información localizada (Español)
- **Display Name**: "Premium Mensual" / "Premium Anual"
- **Description**: "Elimina los anuncios y accede a funciones premium"

#### Información localizada (Inglés)
- **Display Name**: "Monthly Premium" / "Yearly Premium"
- **Description**: "Remove ads and access premium features"

### 5. Configurar Precios
- **Territorio**: Seleccionar países donde estará disponible
- **Precio**: Configurar precio automático basado en el tier seleccionado
- **Ofertas introductorias**: Opcional (ej: 1 semana gratis)

### 6. Configurar Términos y Condiciones
- **Privacy Policy URL**: `https://tu-dominio.com/privacy-policy`
- **Terms of Service URL**: `https://tu-dominio.com/terms-of-service`

### 7. Configurar Sandbox Testing
1. Ir a "Users and Access" > "Sandbox Testers"
2. Crear cuentas de prueba específicas para IAP
3. Usar estas cuentas para probar en simulador/dispositivo

### 8. Configurar Familia de Productos
En el grupo de suscripción, configurar:
- **Upgrade/Downgrade**: Permitir cambios entre mensual y anual
- **Orden de productos**: Anual como recomendado

### 9. Configurar Webhooks (Opcional)
Para validación del servidor:
- **Notification URL**: `https://tu-servidor.com/webhook/apple-iap`
- **Shared Secret**: Generar secreto compartido

## Configuración en Xcode

### 1. Capabilities
En tu proyecto Xcode:
1. Seleccionar target de la app
2. Ir a "Signing & Capabilities"
3. Añadir "In-App Purchase" capability

### 2. Info.plist
Agregar claves si es necesario:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>apple.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
    </dict>
</dict>
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

### 1. Sandbox Testing
- Usar cuentas de sandbox creadas en App Store Connect
- Los productos deben estar en estado "Ready for Review"
- Probar compras, cancelaciones y restauraciones

### 2. TestFlight
- Distribuir beta con IAP habilitado
- Probar con usuarios reales (pero usando sandbox)
- Verificar todos los flujos de compra

### 3. Validación de Recibos
- Usar URL de sandbox: `https://sandbox.itunes.apple.com/verifyReceipt`
- URL de producción: `https://buy.itunes.apple.com/verifyReceipt`

## Políticas Importantes

### 1. Cumplimiento con App Store Review Guidelines
- Los productos deben agregar valor real a la app
- No mostrar precios externos (solo usar los de App Store)
- Implementar "Restore Purchases" correctamente

### 2. Restricciones
- No mencionar otras plataformas de pago
- No ofrecer precios diferentes fuera del App Store
- Cumplir con las políticas de suscripciones

### 3. Localización
- Precios se ajustan automáticamente por región
- Descripción debe estar en idiomas principales
- Términos y condiciones deben estar localizados

## Troubleshooting Común

### Problema: "No products available"
**Solución**: 
- Verificar Product IDs exactos
- Confirmar que productos están "Ready for Review"
- Verificar Bundle ID coincide con App Store Connect

### Problema: "Sandbox tester invalid"
**Solución**:
- Crear nueva cuenta sandbox
- Salir de App Store en dispositivo
- Usar solo la cuenta sandbox para pruebas

### Problema: "Receipt validation failed"
**Solución**:
- Verificar URL de sandbox vs producción
- Comprobar shared secret
- Validar formato de recibo

## Checklist Final

- [ ] Productos creados en App Store Connect
- [ ] IDs de productos coinciden con el código
- [ ] Precios configurados correctamente
- [ ] Metadatos completados en todos los idiomas
- [ ] Sandbox testing completado
- [ ] Capability añadida en Xcode
- [ ] Términos y condiciones subidos
- [ ] Política de privacidad actualizada
- [ ] TestFlight testing completado
- [ ] Revisión de App Store Guidelines 