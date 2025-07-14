const express = require('express');
const router = express.Router();
const { authMiddleware, optionalAuthMiddleware } = require('../middleware/auth');
const database = require('../database/connection');
const logger = require('../utils/logger');

/**
 * GET /users/profile
 * Obtener perfil del usuario autenticado
 */
router.get('/profile', authMiddleware, async (req, res) => {
    try {
        const user = req.user;
        
        res.status(200).json({
            success: true,
            data: {
                id: user.id,
                email: user.email,
                telegramUserId: user.telegram_user_id,
                premiumActive: user.premium_active,
                premiumExpiresAt: user.premium_expires_at,
                subscriptionType: user.subscription_type,
                whatsappQuota: {
                    used: user.whatsapp_quota_used,
                    limit: user.whatsapp_quota_limit,
                    remaining: user.whatsapp_quota_limit - user.whatsapp_quota_used,
                    resetAt: user.whatsapp_quota_reset_at
                },
                createdAt: user.created_at,
                lastActiveAt: user.last_active_at
            }
        });
    } catch (error) {
        logger.error('Failed to get user profile', {
            userId: req.user?.id,
            error: error.message
        });
        
        res.status(500).json({
            error: 'Internal server error'
        });
    }
});

/**
 * GET /users/health-check
 * Health check que no requiere autenticación
 */
router.get('/health-check', async (req, res) => {
    try {
        const dbHealth = await database.healthCheck();
        
        res.status(200).json({
            status: 'healthy',
            service: 'User Service',
            database: dbHealth,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            error: error.message
        });
    }
});

module.exports = router; 