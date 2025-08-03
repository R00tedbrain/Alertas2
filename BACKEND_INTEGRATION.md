# 🔗 Integración Backend WhatsApp - AlertaTelegram

Esta guía explica cómo integrar el backend de WhatsApp que acabamos de crear con tu app AlertaTelegram.

## 📁 Estructura Creada

```
backend/
├── docker-compose.yml          # Configuración de servicios
├── Dockerfile                  # Imagen del backend
├── package.json               # Dependencias Node.js
├── init.sql                   # Inicialización de base de datos
├── nginx.conf                 # Configuración del proxy
├── deploy.sh                  # Script de despliegue automatizado
├── README.md                  # Documentación completa
├── src/
│   ├── server.js              # Servidor principal Express
│   ├── database/
│   │   └── connection.js      # Conexión PostgreSQL
│   ├── services/
│   │   └── whatsapp.js        # Servicio WhatsApp Business API
│   ├── routes/
│   │   ├── whatsapp.js        # Rutas API WhatsApp
│   │   ├── users.js           # Rutas de usuarios
│   │   └── stats.js           # Rutas de estadísticas
│   ├── middleware/
│   │   ├── auth.js            # Autenticación de usuarios
│   │   └── errorHandler.js    # Manejo de errores
│   ├── jobs/
│   │   └── scheduler.js       # Trabajos programados
│   └── utils/
│       └── logger.js          # Sistema de logging
└── logs/                      # Logs del sistema (se crea automáticamente)
```

## 🚀 Pasos de Despliegue

### 1. Preparar el Backend

```bash
# En tu VPS, copiar la carpeta backend
scp -r backend/ usuario@tu-vps:/opt/alertatelegram-backend/
ssh usuario@tu-vps
cd /opt/alertatelegram-backend

# Hacer ejecutable el script de deploy
chmod +x deploy.sh

# Ejecutar despliegue automatizado
./deploy.sh
```

### 2. Configurar Variables de WhatsApp

Edita `docker-compose.yml` y configura:

```yaml
environment:
  - WHATSAPP_ACCESS_TOKEN=TU_TOKEN_REAL
  - WHATSAPP_PHONE_NUMBER_ID=TU_PHONE_ID_REAL  
  - WHATSAPP_BUSINESS_ACCOUNT_ID=TU_BUSINESS_ID_REAL
```

### 3. Verificar Funcionamiento

```bash
# Health check
curl http://localhost:4000/health

# Info del servicio
curl http://localhost:4000/info

# Estado de WhatsApp
curl http://localhost:4000/whatsapp/health
```

## 📱 Integración con Flutter

### 1. Actualizar Dependencias

Agrega en `pubspec.yaml`:

```yaml
dependencies:
  shared_preferences: ^2.2.2
  crypto: ^3.0.3
```

Ejecuta:
```bash
flutter pub get
```

### 2. Servicios Creados

Ya se han creado estos archivos:

- ✅ `lib/core/services/whatsapp_centralized_service.dart` - Actualizado para usar headers
- ✅ `lib/core/services/user_token_service.dart` - Nuevo servicio para tokens

### 3. Configurar URL del Backend

En `whatsapp_centralized_service.dart`, actualiza la URL:

```dart
static const String _baseUrl = 'http://tu-servidor:4000'; // Cambiar por tu servidor
```

### 4. Usar en la App

#### En la pantalla de configuración (settings_screen.dart):

```dart
import '../core/services/user_token_service.dart';

class _SettingsScreenState extends State<SettingsScreen> {
  final UserTokenService _tokenService = UserTokenService();
  
  // Mostrar info del token
  Widget _buildTokenInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _tokenService.getTokenInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final info = snapshot.data!;
        return Card(
          child: ListTile(
            title: Text('Estado del Servicio WhatsApp'),
            subtitle: Text(info['status']),
            trailing: info['isTestMode'] 
                ? Chip(label: Text('PRUEBA'))
                : Chip(label: Text('ACTIVO')),
          ),
        );
      },
    );
  }
}
```

#### Para enviar alertas:

```dart
import '../core/services/whatsapp_centralized_service.dart';

// En tu método de alerta existente
Future<void> _sendEmergencyAlert() async {
  // Tu código existente para Telegram...
  
  // Agregar WhatsApp
  final whatsappService = WhatsAppCentralizedService();
  
  try {
    final success = await whatsappService.sendAlert(
      whatsAppContacts: whatsAppContacts, // Lista existente
      message: 'Tu mensaje de emergencia',
      latitude: position.latitude,
      longitude: position.longitude,
    );
    
    if (success) {
      print('✅ Alerta WhatsApp enviada');
    } else {
      print('❌ Error enviando WhatsApp');
    }
  } catch (e) {
    print('Error WhatsApp: $e');
  }
}
```

## 🔑 API del Backend

### Endpoints Principales

#### 🚨 Enviar Alerta de Emergencia
```http
POST /whatsapp/send-alert
X-User-Token: test_premium_user_2024
Content-Type: application/json

{
  "message": "🚨 ALERTA DE EMERGENCIA 🚨\n\nNecesito ayuda urgente.",
  "contacts": [
    {
      "name": "Contacto",
      "phoneNumber": "+34612345678"
    }
  ],
  "location": {
    "latitude": 40.4168,
    "longitude": -3.7038
  },
  "timestamp": "2024-01-15T12:34:56.789Z"
}
```

#### 🧪 Mensaje de Prueba
```http
POST /whatsapp/test-message
X-User-Token: test_premium_user_2024
Content-Type: application/json

{
  "phoneNumber": "+34612345678",
  "message": "Mensaje de prueba desde AlertaTelegram"
}
```

#### 📊 Ver Cuota de Usuario
```http
GET /whatsapp/quota
X-User-Token: test_premium_user_2024
```

## 🧪 Testing

### 1. Probar con cURL

```bash
# Enviar mensaje de prueba
curl -X POST http://localhost:4000/whatsapp/test-message \
  -H "X-User-Token: test_premium_user_2024" \
  -H "Content-Type: application/json" \
  -d '{
    "phoneNumber": "+34612345678",
    "message": "Prueba desde cURL"
  }'
```

### 2. Probar desde Flutter

```dart
// En algún widget de prueba
ElevatedButton(
  onPressed: () async {
    final whatsapp = WhatsAppCentralizedService();
    
    // Simular contacto de prueba
    final testContact = EmergencyContact(
      id: 'test',
      name: 'Prueba',
      telegramNumber: '',
      whatsappNumber: '+34612345678',
      telegramEnabled: false,
      whatsappEnabled: true,
    );
    
    final success = await whatsapp.sendAlert(
      whatsAppContacts: [testContact],
      message: 'Prueba desde Flutter',
      latitude: 40.4168,
      longitude: -3.7038,
    );
    
    print(success ? '✅ Enviado' : '❌ Error');
  },
  child: Text('Probar WhatsApp'),
)
```

## 🔧 Configuración Producción

### 1. Dominio y HTTPS

```nginx
# Configurar dominio real en nginx.conf
server_name api.your-domain.com;

# Configurar certificados SSL
ssl_certificate /etc/nginx/ssl/alertatelegram.pem;
ssl_certificate_key /etc/nginx/ssl/alertatelegram.key;
```

### 2. Variables de Entorno Seguras

```bash
# Cambiar contraseñas en producción
DATABASE_PASSWORD=password_super_segura_2024
JWT_SECRET=jwt_secret_muy_largo_y_aleatorio_2024
```

### 3. Actualizar URL en Flutter

```dart
// En whatsapp_centralized_service.dart
static const String _baseUrl = 'https://api.your-domain.com';
```

## 🗄️ Base de Datos

### Usuario de Prueba Incluido

```sql
Token: test_premium_user_2024
Email: test@your-domain.com
Premium: Activo por 1 año
Cuota: 1000 mensajes/mes
```

### Gestión de Usuarios

```sql
-- Ver usuarios
SELECT * FROM users;

-- Crear usuario premium
INSERT INTO users (user_token, email, premium_active, premium_expires_at, subscription_type)
VALUES ('tu_token_personalizado', 'usuario@email.com', true, CURRENT_TIMESTAMP + INTERVAL '1 year', 'yearly');

-- Ver logs de mensajes
SELECT * FROM message_logs ORDER BY sent_at DESC LIMIT 10;
```

## 📝 Logs y Monitoreo

### Ver Logs

```bash
# Logs de la API
docker-compose logs -f whatsapp-api

# Logs específicos de WhatsApp
tail -f logs/whatsapp-$(date +%Y-%m-%d).log

# Buscar errores
grep -i error logs/combined-$(date +%Y-%m-%d).log
```

### Monitoreo

```bash
# Estado de servicios
docker-compose ps

# Recursos
docker stats

# Health check automático
curl -f http://localhost:4000/health || echo "Servicio caído"
```

## 🚦 Resolución de Problemas

### Error: "Database not connected"
```bash
docker-compose logs db
docker-compose restart db
```

### Error: "WhatsApp token invalid"
```bash
# Verificar token en docker-compose.yml
# Generar nuevo token en Facebook Developer Console
docker-compose restart whatsapp-api
```

### Error: "Rate limit exceeded"
```bash
# Ajustar límites en nginx.conf o src/server.js
docker-compose restart nginx
```

## ✅ Checklist de Integración

- [ ] Backend desplegado y funcionando
- [ ] Variables de WhatsApp configuradas
- [ ] Health checks pasando
- [ ] Flutter actualizado con nuevos servicios
- [ ] URL del backend configurada
- [ ] Test de mensaje enviado correctamente
- [ ] Logs funcionando
- [ ] Monitoreo configurado

## 🎉 ¡Listo!

Tu integración de WhatsApp está completa. Los usuarios Premium de tu app ahora pueden:

1. ✅ Agregar hasta 3 números de WhatsApp
2. ✅ Enviar alertas de emergencia por WhatsApp + Telegram
3. ✅ Ver cuota de mensajes restantes
4. ✅ Servicio completamente gestionado sin configuración técnica

**URL de prueba**: `http://localhost:4000`  
**Token de prueba**: `test_premium_user_2024` 