# Configuración del Bot de Telegram

Esta guía detalla el proceso para crear y configurar un bot de Telegram para usar con la aplicación Alerta Telegram.

## 1. Crear un Bot de Telegram

1. **Abre Telegram** y busca a **@BotFather** (el bot oficial para crear bots)

2. **Inicia la conversación** con BotFather y envía el comando `/start`

3. **Crea un nuevo bot** con el comando `/newbot`

4. **Sigue las instrucciones** de BotFather:
   - Te pedirá un nombre para el bot (por ejemplo, "Mi Alerta de Emergencia")
   - Luego te pedirá un nombre de usuario para el bot (debe terminar en "bot", por ejemplo: "mi_alerta_emergencia_bot")

5. **Guarda el token** que te proporciona BotFather. Se verá algo así:
   ```
   123456789:ABCDefGhIJKlmNoPQRsTUVwxyZ
   ```

   Este token es la clave para usar en la aplicación Alerta Telegram.

## 2. Configuración adicional (opcional)

Puedes personalizar tu bot con estos comandos adicionales a BotFather:

- `/setdescription` - Establece una descripción para tu bot
- `/setabouttext` - Establece el texto "Acerca de"
- `/setuserpic` - Establece una imagen de perfil para tu bot
- `/setcommands` - Define comandos disponibles para tu bot

## 3. Obtener Chat IDs

Para que la aplicación pueda enviar mensajes a tus contactos de emergencia, necesitas obtener su "chat_id". Hay dos maneras de hacer esto:

### Opción 1: Usando un bot externo
1. Pide a tu contacto que busque e inicie una conversación con el bot **@userinfobot**
2. Este bot responderá automáticamente con su información, incluyendo su `id`

### Opción 2: Usando la API de Telegram
1. Pide a tu contacto que busque tu bot (el que acabas de crear) y le envíe un mensaje (por ejemplo, el comando `/start`)
2. Visita esta URL en tu navegador (reemplaza YOUR_BOT_TOKEN con tu token):
   ```
   https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   ```
3. Busca en la respuesta JSON el campo `chat` -> `id`. Este es el chat_id que necesitas.

## 4. Configuración en la Aplicación

1. Abre la aplicación Alerta Telegram
2. En la pantalla principal, toca el ícono de edición junto a "Configuración Telegram Bot"
3. Ingresa el token que obtuviste de BotFather
4. Agrega los contactos de emergencia con sus nombres y chat_ids

## 5. Prueba del Sistema

1. Antes de una emergencia real, es importante probar que todo funcione correctamente:
   - Asegúrate de que todos los contactos hayan iniciado una conversación con tu bot
   - Realiza una prueba breve informando a tus contactos de antemano
   - Verifica que los mensajes, ubicación y audio lleguen correctamente

## Notas importantes

- **Seguridad**: El token de tu bot es como una contraseña. No lo compartas públicamente.
- **Privacidad**: Informa a tus contactos de emergencia que recibirán actualizaciones automáticas de ubicación y audio en caso de emergencia.
- **Limitaciones**: Los bots de Telegram no pueden iniciar conversaciones. Tus contactos deben enviar al menos un mensaje a tu bot primero.
- **Cobertura**: La aplicación necesita conexión a Internet para enviar los mensajes a Telegram.

## Solución de problemas

- Si los mensajes no se envían, verifica que:
  - El token ingresado sea correcto
  - Los chat_ids sean correctos
  - Todos los contactos hayan iniciado una conversación con el bot
  - Tu dispositivo tenga conexión a Internet

- Si necesitas regenerar el token del bot (por seguridad), usa el comando `/revoke` en BotFather y actualiza el token en la aplicación. 