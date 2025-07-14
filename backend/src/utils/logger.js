const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');

// Configuración de niveles de log
const logLevels = {
    error: 0,
    warn: 1,
    info: 2,
    http: 3,
    debug: 4
};

// Colores para los niveles
const logColors = {
    error: 'red',
    warn: 'yellow',
    info: 'green',
    http: 'magenta',
    debug: 'blue'
};

winston.addColors(logColors);

// Formato personalizado para logs
const logFormat = winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.printf((info) => {
        const { timestamp, level, message, stack, ...meta } = info;
        
        let logMessage = `${timestamp} [${level.toUpperCase()}]: ${message}`;
        
        // Añadir stack trace para errores
        if (stack) {
            logMessage += `\n${stack}`;
        }
        
        // Añadir metadata si existe
        if (Object.keys(meta).length > 0) {
            logMessage += `\nMetadata: ${JSON.stringify(meta, null, 2)}`;
        }
        
        return logMessage;
    })
);

// Formato para consola
const consoleFormat = winston.format.combine(
    winston.format.colorize({ all: true }),
    winston.format.timestamp({ format: 'HH:mm:ss' }),
    winston.format.printf((info) => {
        const { timestamp, level, message, stack } = info;
        let logMessage = `${timestamp} ${level}: ${message}`;
        
        if (stack) {
            logMessage += `\n${stack}`;
        }
        
        return logMessage;
    })
);

// Configuración de transports
const transports = [];

// Console transport (solo en desarrollo)
if (process.env.NODE_ENV !== 'production') {
    transports.push(
        new winston.transports.Console({
            level: 'debug',
            format: consoleFormat
        })
    );
}

// File transport para errores
transports.push(
    new DailyRotateFile({
        filename: path.join(__dirname, '../../logs/error-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        level: 'error',
        format: logFormat,
        maxSize: '20m',
        maxFiles: '30d',
        zippedArchive: true
    })
);

// File transport para todos los logs
transports.push(
    new DailyRotateFile({
        filename: path.join(__dirname, '../../logs/combined-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        format: logFormat,
        maxSize: '20m',
        maxFiles: '30d',
        zippedArchive: true
    })
);

// File transport para logs de WhatsApp específicamente
transports.push(
    new DailyRotateFile({
        filename: path.join(__dirname, '../../logs/whatsapp-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        format: logFormat,
        maxSize: '20m',
        maxFiles: '30d',
        zippedArchive: true,
        level: 'info'
    })
);

// Crear logger principal
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    levels: logLevels,
    format: logFormat,
    transports,
    exitOnError: false
});

// Logger específico para WhatsApp
const whatsappLogger = winston.createLogger({
    level: 'info',
    levels: logLevels,
    format: winston.format.combine(
        winston.format.label({ label: 'WHATSAPP' }),
        logFormat
    ),
    transports: [
        new DailyRotateFile({
            filename: path.join(__dirname, '../../logs/whatsapp-%DATE%.log'),
            datePattern: 'YYYY-MM-DD',
            format: winston.format.combine(
                winston.format.label({ label: 'WHATSAPP' }),
                logFormat
            ),
            maxSize: '20m',
            maxFiles: '30d',
            zippedArchive: true
        })
    ]
});

// Logger específico para autenticación
const authLogger = winston.createLogger({
    level: 'info',
    levels: logLevels,
    format: winston.format.combine(
        winston.format.label({ label: 'AUTH' }),
        logFormat
    ),
    transports: [
        new DailyRotateFile({
            filename: path.join(__dirname, '../../logs/auth-%DATE%.log'),
            datePattern: 'YYYY-MM-DD',
            format: winston.format.combine(
                winston.format.label({ label: 'AUTH' }),
                logFormat
            ),
            maxSize: '20m',
            maxFiles: '30d',
            zippedArchive: true
        })
    ]
});

// Funciones de utilidad para logging
const loggers = {
    // Logger principal
    info: (message, meta = {}) => logger.info(message, meta),
    warn: (message, meta = {}) => logger.warn(message, meta),
    error: (message, meta = {}) => logger.error(message, meta),
    debug: (message, meta = {}) => logger.debug(message, meta),
    http: (message, meta = {}) => logger.http(message, meta),
    
    // Logger de WhatsApp
    whatsapp: {
        info: (message, meta = {}) => whatsappLogger.info(message, meta),
        warn: (message, meta = {}) => whatsappLogger.warn(message, meta),
        error: (message, meta = {}) => whatsappLogger.error(message, meta),
        debug: (message, meta = {}) => whatsappLogger.debug(message, meta)
    },
    
    // Logger de autenticación
    auth: {
        info: (message, meta = {}) => authLogger.info(message, meta),
        warn: (message, meta = {}) => authLogger.warn(message, meta),
        error: (message, meta = {}) => authLogger.error(message, meta),
        debug: (message, meta = {}) => authLogger.debug(message, meta)
    },
    
    // Función para log de requests HTTP
    logRequest: (req, res, responseTime) => {
        const logData = {
            method: req.method,
            url: req.originalUrl,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            statusCode: res.statusCode,
            responseTime: `${responseTime}ms`,
            userToken: req.headers['x-user-token'] ? '***HIDDEN***' : 'none'
        };
        
        if (res.statusCode >= 400) {
            logger.warn('HTTP Request Error', logData);
        } else {
            logger.http('HTTP Request', logData);
        }
    },
    
    // Función para log de mensajes WhatsApp
    logWhatsAppMessage: (userToken, phoneNumbers, success, error = null) => {
        const logData = {
            userToken: userToken.substring(0, 8) + '***',
            recipients: phoneNumbers.length,
            success,
            timestamp: new Date().toISOString()
        };
        
        if (error) {
            logData.error = error;
            whatsappLogger.error('WhatsApp Message Failed', logData);
        } else {
            whatsappLogger.info('WhatsApp Message Sent', logData);
        }
    },
    
    // Función para log de autenticación
    logAuth: (userToken, action, success, ip, details = {}) => {
        const logData = {
            userToken: userToken ? userToken.substring(0, 8) + '***' : 'none',
            action,
            success,
            ip,
            timestamp: new Date().toISOString(),
            ...details
        };
        
        if (success) {
            authLogger.info(`Auth Success: ${action}`, logData);
        } else {
            authLogger.warn(`Auth Failed: ${action}`, logData);
        }
    }
};

// Manejo de errores no capturados en los loggers
logger.on('error', (error) => {
    console.error('Logger error:', error);
});

whatsappLogger.on('error', (error) => {
    console.error('WhatsApp Logger error:', error);
});

authLogger.on('error', (error) => {
    console.error('Auth Logger error:', error);
});

module.exports = loggers; 