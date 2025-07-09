# 🚨 AlertaTelegram

Sistema de alertas de emergencia que envía ubicación, audio y fotos a contactos de Telegram durante situaciones críticas.

## 📱 Características Principales

- **🎤 Grabaciones de Audio**: Envío automático cada 30 segundos en segundo plano
- **📍 Ubicación en Tiempo Real**: Actualización continua de posición GPS
- **📷 Fotos de Emergencia**: Captura de cámaras frontal y trasera cada 20 segundos
- **🤖 Integración Telegram**: Envío directo a través de bot personalizado
- **⚡ Funcionamiento en Background**: Continúa funcionando aunque la app esté cerrada

## ⚠️ Restricciones Importantes - iOS

En dispositivos iOS, debido a limitaciones del sistema:
- ✅ **Audio y ubicación** funcionan perfectamente en segundo plano
- ❌ **Las fotos solo se capturan cuando la app está abierta**
- 💡 **Recomendación**: Mantener la app abierta durante emergencias para obtener fotos

## 🛠️ Configuración Inicial

### 1. Crear Bot de Telegram
1. Busca `@BotFather` en Telegram
2. Envía `/newbot`
3. Sigue las instrucciones para crear tu bot
4. Guarda el **token** que te proporciona

### 2. Obtener Chat IDs
1. Envía un mensaje a tu bot
2. Usa `@userinfobot` para obtener tu Chat ID
3. Añade los Chat IDs en la configuración de la app

### 3. Configurar Permisos
- 📍 Ubicación (siempre)
- 🎤 Micrófono
- 📷 Cámara
- 🔔 Notificaciones

## 🚀 Instalación

```bash
# Clonar repositorio
git clone https://github.com/tu-usuario/AlertaTelegram.git

# Instalar dependencias
flutter pub get

# Ejecutar en dispositivo
flutter run
```

## 📋 Requisitos

- Flutter 3.0+
- Dart 3.0+
- iOS 14.0+ / Android 6.0+
- Conexión a internet
- Cuenta de Telegram

## 🔧 Dependencias Principales

- `camera`: Captura de fotos
- `geolocator`: Servicios de ubicación
- `flutter_sound`: Grabación de audio
- `permission_handler`: Gestión de permisos
- `dio`: Cliente HTTP para Telegram API

## 📚 Documentación

- [Configuración de Bot Telegram](TELEGRAM_BOT_SETUP.md)
- [Esquema de URLs](URL_SCHEME.md)

## 🛡️ LICENCIA Y TÉRMINOS DE USO

**⚠️ IMPORTANTE: Este proyecto está bajo una licencia MUY RESTRICTIVA**

### ❌ PROHIBICIONES ESTRICTAS:
- **Uso comercial o con fines de lucro**
- **Distribución del código o aplicación**
- **Venta, alquiler o monetización**
- **Publicación en tiendas de aplicaciones**
- **Remoción de atribuciones o licencia**

### ✅ PERMISOS LIMITADOS:
- Uso personal únicamente
- Estudio del código fuente
- Modificaciones para uso personal
- Fork para análisis (sin distribución)

### 📋 OBLIGACIONES:
- Mantener atribución al autor original
- Incluir esta licencia en modificaciones
- No redistribuir versiones modificadas

**Al usar este código, aceptas automáticamente todos los términos de la [LICENCIA](LICENSE)**

### ⚖️ Protección Legal

Este software está protegido por derechos de autor. El uso no autorizado puede resultar en:
- Acciones legales por violación de copyright
- Demandas por uso comercial no autorizado
- Solicitudes de cese y desistimiento

### 📞 Contacto para Permisos

Para solicitar permisos especiales o uso comercial:
- Email: [tu-email@dominio.com]
- Solo se considerarán solicitudes por escrito

## 🆘 Soporte

Para problemas técnicos (NO comerciales):
- Abrir issue en GitHub
- Incluir logs y pasos para reproducir
- Solo para uso personal autorizado

---

**Copyright © 2025 - Todos los derechos reservados**  
**Proyecto: AlertaTelegram**  
**Autor: [Tu nombre/alias]**

> ⚠️ **AVISO**: Este README no sustituye la licencia completa. 
> Lee el archivo [LICENSE](LICENSE) para términos legales completos.

---

## 🌐 Versiones de Idioma

- **🇪🇸 Español**: [README.md](README.md) | [LICENCIA](LICENSE)
- **🇺🇸 English**: [README_EN.md](README_EN.md) | [LICENSE_EN](LICENSE_EN)
