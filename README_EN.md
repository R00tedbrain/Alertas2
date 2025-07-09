# 🚨 AlertaTelegram

Emergency alert system that sends location, audio, and photos to Telegram contacts during critical situations.

## 📱 Main Features

- **🎤 Audio Recordings**: Automatic sending every 30 seconds in background
- **📍 Real-time Location**: Continuous GPS position updates
- **📷 Emergency Photos**: Front and rear camera capture every 20 seconds
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

**By using this code, you automatically accept all terms of the [LICENSE](LICENSE) / [LICENSE_EN](LICENSE_EN)**

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
> Read the [LICENSE](LICENSE) or [LICENSE_EN](LICENSE_EN) file for complete legal terms.

---

## 🌐 Language Versions

- **🇪🇸 Español**: [README.md](README.md) | [LICENCIA](LICENSE)
- **🇺🇸 English**: [README_EN.md](README_EN.md) | [LICENSE_EN](LICENSE_EN) 