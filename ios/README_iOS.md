# Configuración de iOS para Alerta Telegram

Este documento detalla la configuración específica para iOS en la aplicación Alerta Telegram, incluyendo información sobre permisos, configuración de privacidad y consideraciones para la publicación en la App Store.

## Permisos requeridos

La aplicación solicita los siguientes permisos, necesarios para su funcionamiento:

1. **Ubicación** (incluida en segundo plano)
   - Usado para enviar la ubicación actual a los contactos de emergencia
   - Es esencial para el funcionamiento principal de la aplicación

2. **Micrófono**
   - Usado para grabar clips de audio que se envían a los contactos
   - Componente crítico para la funcionalidad de alerta

3. **Notificaciones**
   - Usado para mantener al usuario informado del estado de las alertas
   - Necesario para la experiencia de usuario durante situaciones de emergencia

4. **Modo en segundo plano**
   - Necesario para que la alerta siga funcionando incluso cuando la aplicación no está activa
   - Incluye modos de audio, ubicación, procesamiento y notificaciones remotas

## Archivos de configuración importantes

La aplicación incluye los siguientes archivos para cumplir con los requisitos de la App Store:

1. **InfoPlist.strings** (en `es.lproj` y `en.lproj`)
   - Contiene las descripciones localizadas de los permisos
   - Explica al usuario por qué la aplicación necesita cada permiso

2. **PrivacyInfo.xcprivacy**
   - Proporciona información detallada sobre los datos recopilados
   - Especifica los propósitos para los que se utilizan los datos (seguridad)
   - Indica que no se realiza seguimiento de usuario

3. **Info.plist**
   - Incluye todos los permisos y capacidades requeridos
   - Configura los modos de segundo plano necesarios

## Preparación para la App Store

Al subir la aplicación a la App Store, es importante considerar:

1. **Descripción de la App**
   - Explicar claramente el propósito de seguridad y emergencia de la aplicación
   - Destacar que los datos solo se envían a contactos elegidos por el usuario

2. **Revisión de la App**
   - Estar preparado para explicar a los revisores de Apple por qué se necesita cada permiso
   - Proporcionar instrucciones claras para probar la funcionalidad de la app

3. **Política de privacidad**
   - Crear una política de privacidad completa que explique:
     - Qué datos se recopilan (ubicación, audio)
     - Cómo se utilizan (para enviar a contactos de emergencia)
     - Que no se comparten con terceros excepto para la función prevista
     - Que no se almacenan permanentemente en servidores

## Configuración de capacidades

Para el correcto funcionamiento, asegúrate de que estas capacidades estén habilitadas en Xcode:

1. **Background Modes**
   - Audio, AirPlay and Picture in Picture
   - Location updates
   - Background fetch
   - Background processing
   - Remote notifications

2. **Push Notifications**
   - Necesario para las notificaciones locales y remotas

## Notas adicionales

- La aplicación está diseñada para usar recursos de manera eficiente en segundo plano
- Se ha optimizado para minimizar el consumo de batería durante el funcionamiento continuo
- Cumple con todas las directrices de privacidad y seguridad de Apple 