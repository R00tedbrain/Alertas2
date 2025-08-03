# 🚀 AlertaTelegram WhatsApp Backend

Backend centralizado para el servicio WhatsApp de AlertaTelegram. Permite a usuarios Premium enviar alertas de emergencia por WhatsApp a través de una API gestionada.

## 📋 Características

- ✅ **API REST completa** para envío de mensajes WhatsApp
- ✅ **Gestión de usuarios Premium** con cuotas mensales
- ✅ **Autenticación basada en tokens** de usuario
- ✅ **Rate limiting** y protección contra abuso
- ✅ **Logging completo** con rotación automática
- ✅ **Base de datos PostgreSQL** con migraciones automáticas
- ✅ **Redis** para cache y rate limiting
- ✅ **Nginx** como proxy reverso
- ✅ **Docker** para despliegue fácil
- ✅ **Trabajos programados** para mantenimiento
- ✅ **Health checks** automáticos

## 🏗️ Arquitectura

```
Flutter App → Nginx → Express.js API → WhatsApp Business API
                         ↓
                   PostgreSQL + Redis
```

## 🔧 Configuración Rápida

### 1. Clonar y configurar

```bash
# Copiar archivos al VPS
scp -r backend/ usuario@tu-vps:/opt/alertatelegram-backend/
ssh usuario@tu-vps
cd /opt/alertatelegram-backend
```

### 2. Configurar variables de entorno

```bash
# Editar docker-compose.yml y configurar estas variables:
nano docker-compose.yml
```

**Variables importantes:**
```yaml
environment:
  - WHATSAPP_ACCESS_TOKEN=TU_TOKEN_DE_WHATSAPP
  - WHATSAPP_PHONE_NUMBER_ID=TU_PHONE_ID
  - WHATSAPP_BUSINESS_ACCOUNT_ID=TU_BUSINESS_ID
  - DATABASE_URL=postgresql://whatsapp_user:YOUR_SECURE_PASSWORD@db:5432/alertatelegram_whatsapp
  - JWT_SECRET=YOUR_JWT_SECRET_HERE
```

### 3. Desplegar

```bash
# Iniciar servicios
docker-compose up -d

# Verificar que todo está funcionando
docker-compose logs -f whatsapp-api
```

### 4. Verificar endpoints

```bash
# Health check
curl http://localhost:4000/health

# Info del servicio  
curl http://localhost:4000/info

# Health check de WhatsApp
curl http://localhost:4000/whatsapp/health
```

## 📱 Configuración de la App Flutter

### Actualizar URL del servicio

En `lib/core/services/whatsapp_centralized_service.dart`:

```dart
static const String _baseUrl = 'https://api.your-domain.com'; // Tu dominio
```

### Token de usuario

Tu app necesita generar/obtener tokens de usuario. Ejemplo:

```dart
// En tu app Flutter
final userToken = 'test_premium_user_2024'; // Token de prueba incluido

// Enviar en headers
headers: {
  'X-User-Token': userToken,
  'Content-Type': 'application/json',
}
```

## 🔑 API Endpoints

### 🚨 Enviar Alerta de Emergencia

```http
POST /whatsapp/send-alert
X-User-Token: test_premium_user_2024
Content-Type: application/json

{
  "message": "🚨 ALERTA DE EMERGENCIA 🚨\n\nNecesito ayuda urgente.",
  "contacts": [
    {
      "name": "Mamá",
      "phoneNumber": "+34612345678"
    },
    {
      "name": "Papá", 
      "phoneNumber": "+34687654321"
    }
  ],
  "location": {
    "latitude": 40.4168,
    "longitude": -3.7038
  },
  "timestamp": "2024-01-15T12:34:56.789Z"
}
```

### 🧪 Mensaje de Prueba

```http
POST /whatsapp/test-message
X-User-Token: test_premium_user_2024
Content-Type: application/json

{
  "phoneNumber": "+34612345678",
  "message": "Mensaje de prueba"
}
```

### 📊 Obtener Cuota

```http
GET /whatsapp/quota
X-User-Token: test_premium_user_2024
```

## 🗄️ Base de Datos

### Tablas principales

- **users**: Usuarios premium con tokens y cuotas
- **whatsapp_contacts**: Contactos de WhatsApp por usuario (máx 3)
- **message_logs**: Log de todos los mensajes enviados
- **daily_stats**: Estadísticas diarias del servicio
- **rate_limits**: Control de rate limiting por usuario

### Usuario de prueba incluido

```sql
Token: test_premium_user_2024
Email: test@your-domain.com
Premium: Activo por 1 año
Cuota: 1000 mensajes/mes
```

## 🔧 Gestión y Mantenimiento

### Ver logs

```bash
# Logs del API
docker-compose logs -f whatsapp-api

# Logs de base de datos
docker-compose logs -f db

# Logs de nginx
docker-compose logs -f nginx
```

### Backup de base de datos

```bash
# Crear backup
docker-compose exec db pg_dump -U whatsapp_user alertatelegram_whatsapp > backup.sql

# Restaurar backup
docker-compose exec -T db psql -U whatsapp_user alertatelegram_whatsapp < backup.sql
```

### Monitoreo

```bash
# Estado de servicios
docker-compose ps

# Uso de recursos
docker stats

# Health check automatizado
curl -f http://localhost:4000/health || echo "Service is down!"
```

## 🚦 Puertos Utilizados

- **4000**: API Backend
- **5434**: PostgreSQL (externa)
- **6380**: Redis (externa)
- **4080**: Nginx HTTP
- **4443**: Nginx HTTPS

> ✅ Estos puertos no entran en conflicto con tus servicios existentes

## 🔒 Seguridad

### Configuración de producción

1. **Cambiar contraseñas** en docker-compose.yml
2. **Configurar HTTPS** con certificados SSL
3. **Firewall**: Solo abrir puertos 4080 y 4443
4. **Monitoreo**: Configurar alertas de logs

### Variables de entorno críticas

```bash
# ⚠️ CAMBIAR ESTAS EN PRODUCCIÓN
DATABASE_PASSWORD=tu_password_super_segura
JWT_SECRET=tu_jwt_secret_muy_largo_y_aleatorio
WHATSAPP_ACCESS_TOKEN=tu_token_real_de_whatsapp
```

## 📈 Escalabilidad

### Para más tráfico

1. **Múltiples instancias** del API:
```yaml
whatsapp-api:
  deploy:
    replicas: 3
```

2. **Load balancer** en nginx:
```nginx
upstream whatsapp_backend {
    server whatsapp-api_1:4000;
    server whatsapp-api_2:4000;
    server whatsapp-api_3:4000;
}
```

3. **Base de datos externa** (recomendado para producción)

## 🐛 Solución de Problemas

### Error: WhatsApp API token inválido

```bash
# Verificar token en docker-compose.yml
# Generar nuevo token en Facebook Developer Console
# Reiniciar servicio
docker-compose restart whatsapp-api
```

### Error: Base de datos no conecta

```bash
# Verificar que PostgreSQL está corriendo
docker-compose ps db

# Ver logs de base de datos
docker-compose logs db

# Reiniciar servicios
docker-compose down && docker-compose up -d
```

### Error: Rate limit excedido

```bash
# Ajustar límites en nginx.conf
# O en código: src/server.js
# Reiniciar nginx
docker-compose restart nginx
```

## 📞 API para Tu App

### Integración en Flutter

```dart
// En WhatsAppCentralizedService
Future<bool> sendAlert({
  required String userToken,
  required List<EmergencyContact> whatsAppContacts,
  required String message,
  required double latitude,
  required double longitude,
}) async {
  final response = await _dio.post(
    '/whatsapp/send-alert',
    data: {
      'userToken': userToken, // ⚠️ Cambiar a header
      'contacts': whatsAppContacts.map((contact) => {
        'name': contact.name,
        'phoneNumber': contact.whatsappNumber,
      }).toList(),
      'message': message,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'timestamp': DateTime.now().toIso8601String(),
    },
    options: Options(
      headers: {
        'X-User-Token': userToken, // ✅ Usar header
      },
    ),
  );
  
  return response.statusCode == 200;
}
```

## 📝 Logs Importantes

### Ubicación de logs

```bash
# Logs de aplicación
./logs/combined-2024-01-15.log
./logs/whatsapp-2024-01-15.log  
./logs/auth-2024-01-15.log
./logs/error-2024-01-15.log
```

### Monitoreo de logs

```bash
# Ver logs en tiempo real
tail -f logs/whatsapp-$(date +%Y-%m-%d).log

# Buscar errores
grep -i error logs/combined-$(date +%Y-%m-%d).log
```

---

## 🎉 ¡Listo!

Tu backend de WhatsApp está configurado y listo para recibir alertas de tu app AlertaTelegram. 

**URLs importantes:**
- 🌐 API: `https://api.your-domain.com`
- 🏥 Health: `https://api.your-domain.com/health`  
- 📱 WhatsApp: `https://api.your-domain.com/whatsapp/send-alert`

**Token de prueba:** `test_premium_user_2024` 