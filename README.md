# 🚨 AlertaTelegram | Sistema de Alertas de Emergencia

[![Ver Demo en YouTube](https://img.youtube.com/vi/RGg1LfyRmqg/0.jpg)](https://youtu.be/RGg1LfyRmqg)

![License](https://img.shields.io/badge/License-PRL%201.0-red.svg)
![Commercial Use](https://img.shields.io/badge/Commercial%20Use-Prohibited-red.svg)
![Distribution](https://img.shields.io/badge/Distribution-Prohibited-red.svg)
![Type](https://img.shields.io/badge/Type-Proprietary%20Restrictive-red.svg)

> **🇪🇸 Español** | **🇺🇸 [English](#english-version)**

Sistema de alertas de emergencia que envía ubicación, audio y fotos a contactos de Telegram durante situaciones críticas.

## 📱 Características Principales

- **🎤 Grabaciones de Audio**: Envío automático cada 30 segundos en segundo plano
- **📍 Ubicación en Tiempo Real**: Actualización continua de posición GPS
- **📷 Fotos de Emergencia**: Captura de cámaras frontal y trasera cada 20 segundos
- **🗺️ Mapa Interactivo**: Mapa clickeable con pantalla completa y actualización cada 10 segundos
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

> 📄 **Licencia GitHub**: [LICENSE.md](LICENSE.md) (formato optimizado para GitHub)

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

# English Version

# 🚨 AlertaTelegram | Emergency Alert System

![License](https://img.shields.io/badge/License-PRL%201.0-red.svg)
![Commercial Use](https://img.shields.io/badge/Commercial%20Use-Prohibited-red.svg)
![Distribution](https://img.shields.io/badge/Distribution-Prohibited-red.svg)
![Type](https://img.shields.io/badge/Type-Proprietary%20Restrictive-red.svg)

> **🇺🇸 English** | **🇪🇸 [Español](#-alertategram--sistema-de-alertas-de-emergencia)**

Emergency alert system that sends location, audio, and photos to Telegram contacts during critical situations.

## 📱 Main Features

- **🎤 Audio Recordings**: Automatic sending every 30 seconds in background
- **📍 Real-time Location**: Continuous GPS position updates
- **📷 Emergency Photos**: Front and rear camera capture every 20 seconds
- **🗺️ Interactive Map**: Clickable map with full screen and 10-second updates
- **🤖 Telegram Integration**: Direct sending through custom bot
- **⚡ Background Operation**: Continues working even when app is closed

## ⚠️ Important Restrictions - iOS

On iOS devices, due to system limitations:
- ✅ **Audio and location** work perfectly in background
- ❌ **Photos are only captured when app is open**
- 💡 **Recommendation**: Keep app open during emergencies to get photos

## 🛠️ Initial Setup

### 1. Create Telegram Bot
1. Search for `@BotFather` on Telegram
2. Send `/newbot`
3. Follow instructions to create your bot
4. Save the **token** provided

### 2. Get Chat IDs
1. Send a message to your bot
2. Use `@userinfobot` to get your Chat ID
3. Add Chat IDs in app configuration

### 3. Configure Permissions
- 📍 Location (always)
- 🎤 Microphone
- 📷 Camera
- 🔔 Notifications

## 🚀 Installation

```bash
# Clone repository
git clone https://github.com/your-user/AlertaTelegram.git

# Install dependencies
flutter pub get

# Run on device
flutter run
```

## 📋 Requirements

- Flutter 3.0+
- Dart 3.0+
- iOS 14.0+ / Android 6.0+
- Internet connection
- Telegram account

## 🔧 Main Dependencies

- `camera`: Photo capture
- `geolocator`: Location services
- `flutter_sound`: Audio recording
- `permission_handler`: Permission management
- `dio`: HTTP client for Telegram API

## 📚 Documentation

- [Telegram Bot Setup](TELEGRAM_BOT_SETUP.md)
- [URL Scheme](URL_SCHEME.md)

## 🛡️ LICENSE AND TERMS OF USE

**⚠️ IMPORTANT: This project is under a VERY RESTRICTIVE license**

### ❌ STRICT PROHIBITIONS:
- **Commercial use or for profit**
- **Distribution of code or application**
- **Sale, rental, or monetization**
- **Publication in app stores**
- **Removal of attributions or license**

### ✅ LIMITED PERMISSIONS:
- Personal use only
- Source code study
- Modifications for personal use
- Fork for analysis (no distribution)

### 📋 OBLIGATIONS:
- Maintain attribution to original author
- Include this license in modifications
- Do not redistribute modified versions

**By using this code, you automatically accept all terms of the [LICENSE](LICENSE)**

> 📄 **GitHub License**: [LICENSE.md](LICENSE.md) (GitHub-optimized format)

### ⚖️ Legal Protection

This software is protected by copyright. Unauthorized use may result in:
- Legal actions for copyright violation
- Lawsuits for unauthorized commercial use
- Cease and desist requests

### 📞 Contact for Permissions

To request special permissions or commercial use:
- Email: [your-email@domain.com]
- Only written requests will be considered

## 🆘 Support

For technical issues (NOT commercial):
- Open issue on GitHub
- Include logs and steps to reproduce
- For authorized personal use only

---

**Copyright © 2025 - All rights reserved**  
**Project: AlertaTelegram**  
**Author: [Your name/alias]**

> ⚠️ **NOTICE**: This README does not replace the complete license. 
> Read the [LICENSE](LICENSE) file for complete legal terms.

---

## 🌐 Versiones de Idioma | Language Versions

- **🇪🇸 Español**: Sección principal arriba | Main section above
- **🇺🇸 English**: [English section](#english-version) | Sección en inglés
- **📄 Licencias**: [LICENSE](LICENSE) (ES) | [LICENSE_EN](LICENSE_EN) (EN) | [LICENSE.md](LICENSE.md) (GitHub)
