# Configuración de Prueba Gratuita - Apple App Store

## Requisitos según Apple Guidelines 3.1.1

Apple permite específicamente pruebas gratuitas usando **Non-Consumable IAP at Price Tier 0** con convención de nombres específica.

### 1. Configuración en App Store Connect

#### Crear Producto de Prueba Gratuita
1. Ir a App Store Connect > Tu App > In-App Purchases
2. Crear nuevo producto: **Non-Consumable**
3. Configurar:
   - **Product ID**: `7_day_trial` (EXACTAMENTE esta convención)
   - **Reference Name**: `AlertaTelegram 7-Day Trial`
   - **Price**: **Tier 0 (FREE)** ⚠️ CRÍTICO
   - **Cleared for Sale**: ✅ Enabled

#### Información Localizada
**Español:**
- **Display Name**: `Prueba Gratuita de 7 Días`
- **Description**: `Acceso completo a funciones premium durante 7 días. Después del período de prueba, las funciones premium requerirán suscripción.`

**Inglés:**
- **Display Name**: `7-Day Free Trial`
- **Description**: `Full access to premium features for 7 days. After trial period, premium features require subscription.`

### 2. Requisitos Obligatorios (Apple Guidelines)

#### Antes de Iniciar la Prueba
La app DEBE mostrar claramente:
- ✅ **Duración**: "7 días gratuitos"
- ✅ **Qué expira**: "Funciones premium (Audio HD, GPS preciso)"
- ✅ **Costo posterior**: "Después €2.99/mes o €19.99/año"
- ✅ **Funciones limitadas**: "Funciones básicas permanecen gratuitas"

#### Información Requerida
```
🎯 PRUEBA GRATUITA DE 7 DÍAS
✅ Acceso completo a funciones premium
✅ Audio HD stereo 44.1kHz @ 192kbps
✅ GPS de máxima precisión
✅ Sin compromiso

📅 Después de 7 días:
• Funciones básicas: SIEMPRE GRATUITAS
• Funciones premium: €2.99/mes o €19.99/año
• Cancela cuando quieras
```

### 3. Restricciones Importantes

#### ❌ Lo que NO está permitido:
- Cambiar la app a un modelo completamente de pago
- Remover funcionalidades básicas existentes
- Forzar la suscripción después de 7 días
- Usar timers locales sin IAP

#### ✅ Lo que SÍ está permitido:
- Ofrecer funciones premium por 7 días gratis
- Limitar solo las funciones premium después de 7 días
- Mantener funcionalidades básicas gratuitas
- Usar Non-Consumable IAP gratuito para el trial

### 4. Configuración Técnica

#### IDs de Productos Actualizados
```dart
// Agregar a IAPService
static const String _trialProductId = '7_day_trial';
static const String _monthlyProductId = 'premium_monthly';
static const String _yearlyProductId = 'premium_yearly';
```

#### Flujo de Compra Obligatorio
1. Usuario solicita prueba gratuita
2. App llama a `purchaseProduct('7_day_trial')`
3. App Store procesa compra GRATUITA
4. App registra fecha de inicio del trial
5. App habilita funciones premium por 7 días
6. Después de 7 días, solo funciones básicas

### 5. Validación y Cumplimiento

#### Validaciones Requeridas
- El producto debe aparecer como Non-Consumable FREE
- Debe usar el nombre exacto "7_day_trial"
- Debe procesar a través del App Store (no timers locales)
- Debe mostrar información clara antes de la compra

#### Testing en Sandbox
- Crear cuentas de prueba en App Store Connect
- Probar que la compra se procesa como $0.00
- Verificar que el período de prueba funciona correctamente
- Confirmar que la app no queda "rota" después del trial

### 6. Aspectos Legales

#### Cumplimiento con Guidelines
- ✅ **Guideline 3.1.1**: Usar Non-Consumable IAP Price Tier 0
- ✅ **Guideline 2.2**: No es una "demo app", es funcionalidad completa
- ✅ **Guideline 2.3.1**: Descripción clara de funcionalidades
- ✅ **Guideline 3.1.2**: Información clara sobre suscripciones

#### Políticas de Privacidad
Actualizar política de privacidad para incluir:
- Información sobre pruebas gratuitas
- Datos recopilados durante el trial
- Proceso de suscripción después del trial

### 7. Implementación Recomendada

#### UI/UX Requerida
```
┌─────────────────────────────────────┐
│         🎯 PRUEBA GRATUITA          │
│                                     │
│  ✅ 7 días de acceso completo        │
│  ✅ Audio HD premium                 │
│  ✅ GPS de máxima precisión          │
│  ✅ Sin compromiso                   │
│                                     │
│  📅 Después de 7 días:               │
│  • Funciones básicas: GRATIS        │
│  • Premium: €2.99/mes               │
│                                     │
│  [INICIAR PRUEBA GRATUITA]          │
│                                     │
│  Al tocar continúas, procesaremos   │
│  tu compra gratuita a través del    │
│  App Store. Cancela cuando quieras. │
└─────────────────────────────────────┘
```

### 8. Monitoreo y Métricas

#### KPIs Importantes
- Tasa de conversión de trial a suscripción
- Retención durante el período de prueba
- Tiempo promedio de uso durante trial
- Funciones más usadas en trial

#### Análisis Recomendado
- Seguimiento de usuarios que terminan trial
- Análisis de abandono durante trial
- Efectividad de ofertas post-trial
- Impacto en descargas de la app

### 9. Checklist Final

- [ ] Producto "7_day_trial" creado en App Store Connect
- [ ] Precio configurado como FREE (Tier 0)
- [ ] Descripciones claras en español/inglés
- [ ] Información obligatoria mostrada antes de compra
- [ ] Validación de período de prueba implementada
- [ ] Funciones básicas permanecen gratuitas
- [ ] Testing en sandbox completado
- [ ] Política de privacidad actualizada
- [ ] Términos de servicio actualizados
- [ ] Métricas de conversión configuradas

Este enfoque cumple 100% con las normativas de Apple y proporciona una experiencia de usuario transparente y legal. 