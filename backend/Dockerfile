FROM node:18-alpine

# Crear directorio de trabajo
WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache \
    curl \
    tzdata

# Configurar zona horaria
ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm ci --only=production && npm cache clean --force

# Crear usuario no privilegiado
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Crear directorios necesarios
RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

# Copiar código fuente
COPY --chown=nodejs:nodejs . .

# Cambiar a usuario no privilegiado
USER nodejs

# Exponer puerto
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

# Comando de inicio
CMD ["npm", "start"] 