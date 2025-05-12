# Alerta Telegram

Una aplicación de emergencia que envía automáticamente ubicación y clips de audio a contactos de emergencia vía Telegram Bot cuando se detecta un problema.

## Funcionalidades

- Envío de ubicación actual al pulsar el botón "Problema detectado"
- Actualizaciones periódicas de ubicación cada minuto
- Grabación y envío de clips de audio de 30 segundos cada 30 segundos
- Almacenamiento local de contactos de emergencia (chat_id de Telegram)
- Funcionamiento en segundo plano incluso con la aplicación cerrada
- Configuración personalizable de intervalos y token del bot

## Tecnologías utilizadas

- Flutter 3.x con null safety
- Riverpod para gestión de estado
- SQLite/SharedPreferences para almacenamiento local
- Flutter Background Service para servicios en segundo plano
- Dio para comunicación HTTP con la API de Telegram Bot
- Geolocator para obtener ubicación
- Flutter Sound para grabación de audio
- Permission Handler para gestión de permisos

## Requisitos previos

1. Bot de Telegram - Necesitas crear un bot usando [BotFather](https://t.me/botfather) y obtener su token
2. Cada contacto de emergencia debe iniciar el bot con `/start` para poder recibir mensajes
3. Permisos de ubicación, micrófono y notificaciones

## Estructura del proyecto

```
lib/
├── core/
│   ├── constants/     # Constantes de la aplicación
│   ├── exceptions/    # Clases de error personalizadas
│   ├── services/      # Servicios (Telegram, ubicación, audio, etc.)
│   └── utils/         # Funciones de utilidad
├── data/
│   ├── datasources/   # Fuentes de datos (local, remoto)
│   ├── models/        # Modelos de datos
│   └── repositories/  # Repositorios de datos
├── domain/
│   └── providers/     # Providers de Riverpod
└── presentation/
    ├── screens/       # Pantallas de la aplicación
    ├── viewmodels/    # ViewModels (lógica de presentación)
    └── widgets/       # Widgets reutilizables
```

## Configuración inicial

1. Crear un bot en Telegram usando [BotFather](https://t.me/botfather)
2. Obtener el token del bot
3. Iniciar el bot con `/start` desde cada cuenta que será contacto de emergencia
4. Obtener el chat_id de cada contacto
5. Configurar el token y los contactos en la aplicación

## Funcionamiento

1. Al pulsar "PROBLEMA DETECTADO" se inicia un servicio en segundo plano
2. La aplicación envía inmediatamente la ubicación actual a todos los contactos configurados
3. Periódicamente envía actualizaciones de ubicación según el intervalo configurado
4. Graba y envía clips de audio según los intervalos configurados
5. Todo continúa en segundo plano incluso si la aplicación se cierra
6. Para detener la alerta, pulsa "DETENER ALERTA"

## Permisos requeridos

- Ubicación (incluida en segundo plano)
- Micrófono
- Notificaciones
- Ejecución en segundo plano

## Instalación y compilación

1. Clonar el repositorio
   ```bash
   git clone https://github.com/tu-usuario/alerta-telegram.git
   ```

2. Instalar dependencias
   ```bash
   flutter pub get
   ```

3. Ejecutar la aplicación
   ```bash
   flutter run
   ```

4. Compilar para Android
   ```bash
   flutter build apk --release
   ```

5. Compilar para iOS
   ```bash
   flutter build ios --release
   ```

## Notas importantes

La aplicación requiere Android SDK 24 (Android 7.0 Nougat) o superior debido a los requisitos de biblioteca de Flutter Sound y otros componentes. La aplicación está configurada para usar Java 11 y requiere desugaring habilitado para funcionar correctamente.

## Actualizaciones y correcciones

- Reemplazado paquete descontinuado `telegram_client` por `dio` para manejo directo de la API de Telegram
- Actualizada la ruta de archivos de configuración para uso correcto
- Corregidas referencias de importaciones faltantes para servicios de Flutter
- Actualizado el manejo de permisos para evitar llamadas recursivas
- Actualizada la configuración de Gradle para Android con desugaring de Java 8
- Actualizado el SDK mínimo a 24 para compatibilidad con Flutter Sound

## Configuración del archivo config.json

El archivo `assets/config/config.json` contiene la configuración inicial:

```json
{
  "telegram_bot_token": "TU_TOKEN_AQUI",
  "emergency_contacts": [
    {
      "name": "Contacto de Emergencia 1",
      "chat_id": "12345678"
    }
  ],
  "alert_settings": {
    "location_update_interval_seconds": 60,
    "audio_recording_duration_seconds": 30,
    "audio_recording_interval_seconds": 30
  }
}
```

## Licencia

MIT

## Contribuir

Las contribuciones son bienvenidas. Por favor, abre un issue o envía un pull request para cualquier mejora.
