# URL Scheme para Alerta Telegram

Este documento explica cómo crear un atajo en iOS para activar la alerta de emergencia directamente desde la pantalla de inicio o el centro de control.

## URL Scheme

La aplicación admite el siguiente URL Scheme:

```
alertatelegram://iniciar
```

Este esquema permite iniciar la alerta de emergencia ("Problema Detectado") directamente sin tener que abrir la aplicación y pulsar el botón.

## Crear un Atajo en iOS

### Método 1: Crear un atajo básico

1. Abre la aplicación **Atajos** en tu iPhone
2. Toca el botón **+** en la esquina superior derecha para crear un nuevo atajo
3. Toca **Añadir acción**
4. Busca **Abrir URL** y selecciónalo
5. En el campo URL, escribe: `alertatelegram://iniciar`
6. Toca en **Siguiente** en la esquina superior derecha
7. Introduce un nombre para tu atajo, por ejemplo: "Alerta de Emergencia"
8. Opcionalmente, personaliza el icono tocando en él
9. Toca en **Listo**

### Método 2: Añadir a la pantalla de inicio

Para añadir el atajo a tu pantalla de inicio:

1. Crea el atajo siguiendo los pasos anteriores
2. En la biblioteca de atajos, mantén presionado el atajo que acabas de crear
3. Selecciona **Compartir**
4. Toca **Añadir a pantalla de inicio**
5. Confirma tocando **Añadir**

### Método 3: Añadir al centro de control

Para acceder rápidamente desde el centro de control:

1. Ve a **Ajustes** > **Centro de Control**
2. Toca **Personalizar controles**
3. Busca **Atajos** y añádelo a los controles incluidos
4. Ahora, cuando abras el centro de control, podrás acceder a tus atajos

## Consideraciones importantes

- La aplicación debe estar instalada para que el URL Scheme funcione
- La primera vez que uses el atajo, iOS puede pedirte confirmación
- Si la aplicación no tiene los permisos necesarios configurados, la alerta no se iniciará y tendrás que configurarlos manualmente
- Asegúrate de haber configurado correctamente el token del bot de Telegram y al menos un contacto de emergencia antes de usar el atajo

## Solución de problemas

Si el atajo no funciona:

1. Verifica que la aplicación está instalada correctamente
2. Comprueba que has introducido el URL Scheme exactamente como se muestra
3. Asegúrate de que todos los permisos necesarios están concedidos (ubicación, micrófono)
4. Verifica que has configurado correctamente el token del bot y al menos un contacto de emergencia
5. Reinicia tu dispositivo e intenta nuevamente

## Ejemplo: Crear un atajo con confirmación

Si prefieres tener una confirmación antes de activar la alerta:

1. Crea un nuevo atajo
2. Añade la acción **Mostrar alerta**
3. En el título, escribe "¿Activar alerta de emergencia?"
4. En el mensaje, escribe "Esto iniciará el envío de tu ubicación y audio a tus contactos"
5. Añade los botones "Cancelar" y "Activar"
6. Añade una condición **Si** que compruebe si la entrada es "Activar"
7. Dentro de la condición, añade la acción **Abrir URL** con `alertatelegram://iniciar`
8. Guarda el atajo y añádelo a tu pantalla de inicio

De esta forma, tendrás una capa adicional de seguridad para evitar activaciones accidentales. 