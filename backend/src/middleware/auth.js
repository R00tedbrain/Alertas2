const database = require('../database/connection');
const logger = require('../utils/logger');

/**
 * Middleware de autenticación para verificar tokens de usuario
 */
async function authMiddleware(req, res, next) {
    try {
        // Obtener token del header
        const userToken = req.headers['x-user-token'] || req.headers['authorization']?.replace('Bearer ', '');

        if (!userToken) {
            logger.auth.warn('Missing user token', {
                ip: req.ip,
                userAgent: req.get('User-Agent'),
                endpoint: req.originalUrl
            });
            return res.status(401).json({
                error: 'Authentication required',
                message: 'X-User-Token header is required'
            });
        }

        // Buscar usuario en la base de datos
        const user = await database.getUser(userToken);

        if (!user) {
            logger.auth.warn('Invalid user token', {
                userToken: userToken.substring(0, 8) + '***',
                ip: req.ip,
                endpoint: req.originalUrl
            });
            return res.status(401).json({
                error: 'Invalid token',
                message: 'User token not found or expired'
            });
        }

        // Verificar si la suscripción premium ha expirado
        if (user.premium_expires_at && new Date(user.premium_expires_at) < new Date()) {
            // Actualizar estado premium en la base de datos
            await database.query(
                'UPDATE users SET premium_active = false WHERE id = $1',
                [user.id]
            );
            user.premium_active = false;

            logger.auth.info('Premium subscription expired', {
                userId: user.id,
                userToken: userToken.substring(0, 8) + '***',
                expiredAt: user.premium_expires_at
            });
        }

        // Verificar si necesita resetear cuota mensual
        if (user.whatsapp_quota_reset_at && new Date(user.whatsapp_quota_reset_at) <= new Date()) {
            await database.query(
                `UPDATE users 
                 SET whatsapp_quota_used = 0, 
                     whatsapp_quota_reset_at = CURRENT_TIMESTAMP + INTERVAL '1 month'
                 WHERE id = $1`,
                [user.id]
            );
            user.whatsapp_quota_used = 0;
            user.whatsapp_quota_reset_at = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // +30 días

            logger.info('Monthly quota reset for user', {
                userId: user.id,
                userToken: userToken.substring(0, 8) + '***'
            });
        }

        // Añadir usuario al request
        req.user = user;

        // Log de autenticación exitosa
        logger.auth.info('User authenticated successfully', {
            userId: user.id,
            userToken: userToken.substring(0, 8) + '***',
            premiumActive: user.premium_active,
            subscriptionType: user.subscription_type,
            endpoint: req.originalUrl,
            ip: req.ip
        });

        next();

    } catch (error) {
        logger.auth.error('Authentication middleware error', {
            error: error.message,
            stack: error.stack,
            ip: req.ip,
            endpoint: req.originalUrl
        });

        res.status(500).json({
            error: 'Authentication error',
            message: 'Internal server error during authentication'
        });
    }
}

/**
 * Middleware opcional de autenticación (no falla si no hay token)
 */
async function optionalAuthMiddleware(req, res, next) {
    try {
        const userToken = req.headers['x-user-token'] || req.headers['authorization']?.replace('Bearer ', '');

        if (!userToken) {
            // No hay token, continuar sin usuario
            req.user = null;
            return next();
        }

        const user = await database.getUser(userToken);

        if (user) {
            // Verificar expiración de premium
            if (user.premium_expires_at && new Date(user.premium_expires_at) < new Date()) {
                await database.query(
                    'UPDATE users SET premium_active = false WHERE id = $1',
                    [user.id]
                );
                user.premium_active = false;
            }

            req.user = user;
            
            logger.auth.debug('Optional auth - user found', {
                userId: user.id,
                userToken: userToken.substring(0, 8) + '***'
            });
        } else {
            req.user = null;
            
            logger.auth.debug('Optional auth - user not found', {
                userToken: userToken.substring(0, 8) + '***'
            });
        }

        next();

    } catch (error) {
        logger.auth.error('Optional authentication error', {
            error: error.message
        });

        // En caso de error, continuar sin usuario
        req.user = null;
        next();
    }
}

/**
 * Middleware para verificar que el usuario tenga premium activo
 */
function requirePremium(req, res, next) {
    if (!req.user) {
        return res.status(401).json({
            error: 'Authentication required',
            message: 'User authentication is required'
        });
    }

    if (!req.user.premium_active) {
        logger.auth.warn('Non-premium user attempted premium feature', {
            userId: req.user.id,
            userToken: req.user.user_token.substring(0, 8) + '***',
            endpoint: req.originalUrl,
            ip: req.ip
        });

        return res.status(403).json({
            error: 'Premium subscription required',
            message: 'This feature is only available for premium users',
            subscription: {
                current: req.user.subscription_type,
                active: req.user.premium_active,
                expiresAt: req.user.premium_expires_at
            }
        });
    }

    next();
}

/**
 * Middleware para verificar cuota de WhatsApp
 */
function checkWhatsAppQuota(req, res, next) {
    if (!req.user) {
        return res.status(401).json({
            error: 'Authentication required'
        });
    }

    const quotaUsed = req.user.whatsapp_quota_used || 0;
    const quotaLimit = req.user.whatsapp_quota_limit || 1000;

    if (quotaUsed >= quotaLimit) {
        logger.warn('WhatsApp quota exceeded', {
            userId: req.user.id,
            userToken: req.user.user_token.substring(0, 8) + '***',
            quotaUsed,
            quotaLimit,
            endpoint: req.originalUrl
        });

        return res.status(429).json({
            error: 'Quota exceeded',
            message: 'Monthly WhatsApp message limit exceeded',
            quota: {
                used: quotaUsed,
                limit: quotaLimit,
                remaining: quotaLimit - quotaUsed,
                resetDate: req.user.whatsapp_quota_reset_at
            }
        });
    }

    next();
}

/**
 * Generar token de usuario (para testing o creación de usuarios)
 */
function generateUserToken() {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2);
    return `alertatelegram_${timestamp}_${random}`;
}

module.exports = {
    authMiddleware,
    optionalAuthMiddleware,
    requirePremium,
    checkWhatsAppQuota,
    generateUserToken
}; 