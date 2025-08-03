const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const logger = require('./utils/logger');
const database = require('./database/connection');
const whatsappRoutes = require('./routes/whatsapp');
const userRoutes = require('./routes/users');
const statsRoutes = require('./routes/stats');
const errorHandler = require('./middleware/errorHandler');
const { scheduleJobs } = require('./jobs/scheduler');

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware de seguridad
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
        },
    },
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
}));

// CORS configurado para AlertaTelegram
app.use(cors({
    origin: [
        'https://your-domain.com',
        'https://www.your-domain.com',
        'https://api.your-domain.com',
        'http://localhost:3000', // Para desarrollo
        'http://localhost:4000'  // Para testing
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-User-Token']
}));

// Compresión
app.use(compression());

// Logging de requests
app.use(morgan('combined', {
    stream: {
        write: (message) => logger.info(message.trim())
    }
}));

// Rate limiting global
const globalLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 100, // 100 requests por ventana
    message: {
        error: 'Too many requests',
        message: 'Rate limit exceeded. Try again later.',
        retryAfter: 15 * 60 // 15 minutos en segundos
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
        logger.warn(`Rate limit exceeded for IP: ${req.ip}`);
        res.status(429).json({
            error: 'Too many requests',
            message: 'Rate limit exceeded. Try again later.',
            retryAfter: 15 * 60
        });
    }
});

app.use(globalLimiter);

// Rate limiting específico para WhatsApp
const whatsappLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minuto
    max: 10, // 10 mensajes por minuto por usuario
    keyGenerator: (req) => {
        return req.headers['x-user-token'] || req.ip;
    },
    message: {
        error: 'WhatsApp rate limit exceeded',
        message: 'Too many WhatsApp messages. Wait before sending more.',
        retryAfter: 60
    }
});

// Parsing JSON
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    });
});

// Info endpoint
app.get('/info', (req, res) => {
    res.status(200).json({
        service: 'AlertaTelegram WhatsApp Backend',
        version: '1.0.0',
        description: 'Servicio centralizado para envío de alertas por WhatsApp',
        endpoints: {
            whatsapp: '/whatsapp/*',
            users: '/users/*',
            stats: '/stats/*',
            health: '/health'
        },
        documentation: 'https://docs.your-domain.com/whatsapp-api'
    });
});

// Rutas principales
app.use('/whatsapp', whatsappLimiter, whatsappRoutes);
app.use('/users', userRoutes);
app.use('/stats', statsRoutes);

// Ruta 404
app.use('*', (req, res) => {
    logger.warn(`404 - Route not found: ${req.method} ${req.originalUrl}`);
    res.status(404).json({
        error: 'Not Found',
        message: 'The requested endpoint does not exist',
        path: req.originalUrl,
        method: req.method
    });
});

// Middleware de manejo de errores
app.use(errorHandler);

// Inicialización del servidor
async function startServer() {
    try {
        // Conectar a la base de datos
        await database.connect();
        logger.info('✅ Database connection established');

        // Iniciar trabajos programados
        scheduleJobs();
        logger.info('✅ Scheduled jobs started');

        // Iniciar servidor
        const server = app.listen(PORT, '0.0.0.0', () => {
            logger.info(`🚀 AlertaTelegram WhatsApp Backend started on port ${PORT}`);
            logger.info(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
            logger.info(`🌐 Health check: http://localhost:${PORT}/health`);
            logger.info(`📝 API Info: http://localhost:${PORT}/info`);
        });

        // Graceful shutdown
        const gracefulShutdown = (signal) => {
            logger.info(`${signal} received. Starting graceful shutdown...`);
            
            server.close(async () => {
                logger.info('✅ HTTP server closed');
                
                try {
                    await database.disconnect();
                    logger.info('✅ Database connection closed');
                } catch (error) {
                    logger.error('Error closing database connection:', error);
                }
                
                logger.info('✅ Graceful shutdown completed');
                process.exit(0);
            });

            // Force shutdown after 30 seconds
            setTimeout(() => {
                logger.error('❌ Forced shutdown due to timeout');
                process.exit(1);
            }, 30000);
        };

        process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
        process.on('SIGINT', () => gracefulShutdown('SIGINT'));

        // Manejo de errores no capturados
        process.on('unhandledRejection', (reason, promise) => {
            logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
        });

        process.on('uncaughtException', (error) => {
            logger.error('Uncaught Exception:', error);
            process.exit(1);
        });

    } catch (error) {
        logger.error('❌ Failed to start server:', error);
        process.exit(1);
    }
}

// Iniciar el servidor
startServer(); 