const logger = require('../utils/logger');

/**
 * Middleware global de manejo de errores
 */
function errorHandler(error, req, res, next) {
    // Log del error
    logger.error('Unhandled error occurred', {
        error: error.message,
        stack: error.stack,
        url: req.originalUrl,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        userToken: req.user?.user_token?.substring(0, 8) + '***' || 'none'
    });

    // Error de validación
    if (error.name === 'ValidationError') {
        return res.status(400).json({
            error: 'Validation Error',
            message: error.message,
            details: error.details
        });
    }

    // Error de base de datos
    if (error.code === '23505') { // Unique constraint violation
        return res.status(409).json({
            error: 'Conflict',
            message: 'Resource already exists'
        });
    }

    if (error.code === '23503') { // Foreign key constraint violation
        return res.status(400).json({
            error: 'Invalid Reference',
            message: 'Referenced resource does not exist'
        });
    }

    // Error de conexión a base de datos
    if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
        return res.status(503).json({
            error: 'Service Unavailable',
            message: 'Database connection failed'
        });
    }

    // Error de WhatsApp API
    if (error.response?.data?.error) {
        const whatsappError = error.response.data.error;
        
        // Rate limit de WhatsApp
        if (whatsappError.code === 131026) {
            return res.status(429).json({
                error: 'WhatsApp Rate Limit',
                message: 'WhatsApp API rate limit exceeded',
                retryAfter: 60
            });
        }

        // Token inválido de WhatsApp
        if (whatsappError.code === 190) {
            logger.error('WhatsApp access token is invalid', {
                whatsappError
            });
            return res.status(503).json({
                error: 'Service Configuration Error',
                message: 'WhatsApp service is temporarily unavailable'
            });
        }

        // Número de teléfono inválido
        if (whatsappError.code === 1006) {
            return res.status(400).json({
                error: 'Invalid Phone Number',
                message: 'The provided phone number is not valid for WhatsApp'
            });
        }

        // Error genérico de WhatsApp
        return res.status(400).json({
            error: 'WhatsApp API Error',
            message: whatsappError.message || 'WhatsApp service error',
            code: whatsappError.code
        });
    }

    // Error de timeout
    if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
        return res.status(408).json({
            error: 'Request Timeout',
            message: 'The request took too long to complete'
        });
    }

    // Error de sintaxis JSON
    if (error instanceof SyntaxError && error.status === 400 && 'body' in error) {
        return res.status(400).json({
            error: 'Invalid JSON',
            message: 'Request body contains invalid JSON'
        });
    }

    // Error de payload demasiado grande
    if (error.code === 'LIMIT_FILE_SIZE' || error.code === 'ENTITY_TOO_LARGE') {
        return res.status(413).json({
            error: 'Payload Too Large',
            message: 'Request payload exceeds maximum allowed size'
        });
    }

    // Error 404 personalizado
    if (error.status === 404) {
        return res.status(404).json({
            error: 'Not Found',
            message: 'The requested resource was not found'
        });
    }

    // Error de autenticación
    if (error.name === 'UnauthorizedError' || error.status === 401) {
        return res.status(401).json({
            error: 'Unauthorized',
            message: 'Authentication is required'
        });
    }

    // Error de autorización
    if (error.status === 403) {
        return res.status(403).json({
            error: 'Forbidden',
            message: 'You do not have permission to access this resource'
        });
    }

    // Error interno del servidor (genérico)
    const statusCode = error.status || error.statusCode || 500;
    
    // En producción, no exponer detalles internos
    if (process.env.NODE_ENV === 'production') {
        return res.status(statusCode).json({
            error: 'Internal Server Error',
            message: 'An unexpected error occurred'
        });
    }

    // En desarrollo, mostrar más detalles
    return res.status(statusCode).json({
        error: 'Internal Server Error',
        message: error.message,
        stack: error.stack,
        details: {
            name: error.name,
            code: error.code,
            status: error.status
        }
    });
}

/**
 * Middleware para manejar rutas no encontradas (404)
 */
function notFoundHandler(req, res, next) {
    logger.warn('Route not found', {
        url: req.originalUrl,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('User-Agent')
    });

    res.status(404).json({
        error: 'Not Found',
        message: `Cannot ${req.method} ${req.originalUrl}`,
        path: req.originalUrl,
        method: req.method,
        timestamp: new Date().toISOString()
    });
}

/**
 * Wrapper para funciones async que permite el manejo automático de errores
 */
function asyncHandler(fn) {
    return (req, res, next) => {
        Promise.resolve(fn(req, res, next)).catch(next);
    };
}

/**
 * Crear error personalizado con código de estado
 */
function createError(status, message, details = null) {
    const error = new Error(message);
    error.status = status;
    if (details) {
        error.details = details;
    }
    return error;
}

module.exports = {
    errorHandler,
    notFoundHandler,
    asyncHandler,
    createError
}; 