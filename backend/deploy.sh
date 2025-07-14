#!/bin/bash

# ===================================
# SCRIPT DE DESPLIEGUE AUTOMATIZADO
# AlertaTelegram WhatsApp Backend
# ===================================

set -e  # Salir si hay errores

echo "🚀 Iniciando despliegue de AlertaTelegram WhatsApp Backend..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logs con colores
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que Docker está instalado
if ! command -v docker &> /dev/null; then
    log_error "Docker no está instalado. Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    log_success "Docker instalado correctamente"
fi

# Verificar que Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose no está instalado. Instalando..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose instalado correctamente"
fi

# Crear directorio para logs si no existe
log_info "Creando estructura de directorios..."
mkdir -p logs
mkdir -p ssl
chmod 755 logs

# Verificar configuración
log_info "Verificando configuración..."

if [ ! -f "docker-compose.yml" ]; then
    log_error "Archivo docker-compose.yml no encontrado"
    exit 1
fi

# Preguntar por configuración de WhatsApp si no está configurada
if grep -q "TU_TOKEN_DE_WHATSAPP" docker-compose.yml; then
    log_warning "⚠️  Configuración de WhatsApp no completada"
    echo
    echo "Necesitas configurar las credenciales de WhatsApp en docker-compose.yml:"
    echo "1. WHATSAPP_ACCESS_TOKEN"
    echo "2. WHATSAPP_PHONE_NUMBER_ID" 
    echo "3. WHATSAPP_BUSINESS_ACCOUNT_ID"
    echo
    read -p "¿Has configurado las credenciales de WhatsApp? (y/n): " configured
    if [[ $configured != "y" && $configured != "Y" ]]; then
        log_error "Por favor configura las credenciales de WhatsApp en docker-compose.yml antes de continuar"
        exit 1
    fi
fi

# Parar servicios existentes si están corriendo
log_info "Parando servicios existentes..."
docker-compose down --remove-orphans || true

# Limpiar volúmenes si se solicita
read -p "¿Quieres limpiar datos existentes de la base de datos? (y/n): " clean_db
if [[ $clean_db == "y" || $clean_db == "Y" ]]; then
    log_warning "Limpiando volúmenes de base de datos..."
    docker-compose down -v
    docker volume prune -f
fi

# Construir e iniciar servicios
log_info "Construyendo e iniciando servicios..."
docker-compose up -d --build

# Esperar a que los servicios estén listos
log_info "Esperando a que los servicios estén listos..."
sleep 10

# Verificar que la base de datos está funcionando
log_info "Verificando conexión a base de datos..."
for i in {1..30}; do
    if docker-compose exec -T db pg_isready -U whatsapp_user -d alertatelegram_whatsapp &> /dev/null; then
        log_success "Base de datos conectada correctamente"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "Timeout esperando conexión a base de datos"
        docker-compose logs db
        exit 1
    fi
    sleep 2
done

# Verificar que la API está funcionando
log_info "Verificando API del backend..."
for i in {1..30}; do
    if curl -sf http://localhost:4000/health &> /dev/null; then
        log_success "API del backend funcionando correctamente"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "Timeout esperando API del backend"
        docker-compose logs whatsapp-api
        exit 1
    fi
    sleep 2
done

# Verificar servicios de WhatsApp
log_info "Verificando servicio de WhatsApp..."
if curl -sf http://localhost:4000/whatsapp/health &> /dev/null; then
    log_success "Servicio de WhatsApp funcionando correctamente"
else
    log_warning "Servicio de WhatsApp no está disponible (verifica credenciales)"
fi

# Mostrar estado de servicios
log_info "Estado de servicios:"
docker-compose ps

# Mostrar información de endpoints
echo
log_success "🎉 ¡Despliegue completado exitosamente!"
echo
echo "📋 INFORMACIÓN DEL SERVICIO:"
echo "================================"
echo "🌐 API Base URL: http://localhost:4000"
echo "🏥 Health Check: http://localhost:4000/health"
echo "📖 Info: http://localhost:4000/info"
echo "📱 WhatsApp API: http://localhost:4000/whatsapp/"
echo
echo "🔍 ENDPOINTS IMPORTANTES:"
echo "================================"
echo "POST /whatsapp/send-alert - Enviar alerta de emergencia"
echo "POST /whatsapp/test-message - Enviar mensaje de prueba"
echo "GET  /whatsapp/quota - Ver cuota de usuario"
echo "GET  /whatsapp/health - Estado del servicio WhatsApp"
echo
echo "🔑 TOKEN DE PRUEBA:"
echo "================================"
echo "X-User-Token: test_premium_user_2024"
echo
echo "🗄️ BASE DE DATOS:"
echo "================================"
echo "Host: localhost:5434"
echo "Database: alertatelegram_whatsapp"
echo "User: whatsapp_user"
echo
echo "📝 LOGS:"
echo "================================"
echo "Ver logs: docker-compose logs -f whatsapp-api"
echo "Logs de DB: docker-compose logs -f db"
echo "Todos los logs: docker-compose logs -f"
echo
echo "🔧 COMANDOS ÚTILES:"
echo "================================"
echo "Parar: docker-compose down"
echo "Reiniciar: docker-compose restart"
echo "Ver estado: docker-compose ps"
echo "Backup DB: docker-compose exec db pg_dump -U whatsapp_user alertatelegram_whatsapp > backup.sql"
echo

# Probar endpoint básico
echo "🧪 PRUEBA RÁPIDA:"
echo "================================"
log_info "Probando endpoint de health check..."
if curl -s http://localhost:4000/health | jq -r .status &> /dev/null; then
    curl -s http://localhost:4000/health | jq
    log_success "¡Backend funcionando correctamente!"
else
    log_warning "jq no instalado. Respuesta raw:"
    curl -s http://localhost:4000/health
fi

echo
log_success "✅ Despliegue completado. El backend está listo para recibir peticiones de tu app AlertaTelegram."
echo
log_info "Para probar la integración:"
echo "1. Actualiza la URL en tu app Flutter: http://tu-servidor:4000"
echo "2. Usa el token de prueba: test_premium_user_2024"
echo "3. Envía una alerta de prueba desde tu app"
echo
log_warning "📋 TODO para producción:"
echo "- Configurar HTTPS con certificados SSL"
echo "- Cambiar contraseñas en docker-compose.yml"
echo "- Configurar dominio real (api.***REMOVED***)"
echo "- Configurar firewall para puertos 4080, 4443"
echo "- Configurar backup automático de base de datos" 