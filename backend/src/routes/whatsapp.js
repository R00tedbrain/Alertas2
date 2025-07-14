const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();

const whatsappService = require('../services/whatsapp');
const database = require('../database/connection');
const logger = require('../utils/logger');
const authMiddleware = require('../middleware/auth');

/**
 * POST /whatsapp/send-alert
 * Endpoint principal para enviar alertas de emergencia por WhatsApp
 */
router.post('/send-alert', [
    authMiddleware,
    // Validaciones
    body('message').isString().isLength({ min: 1, max: 1000 }).withMessage('Message must be between 1 and 1000 characters'),
    body('contacts').isArray({ min: 1, max: 3 }).withMessage('Must provide 1-3 contacts'),
    body('contacts.*.name').isString().isLength({ min: 1, max: 100 }).withMessage('Contact name required'),
    body('contacts.*.phoneNumber').isMobilePhone().withMessage('Valid phone number required'),
    body('location.latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    body('location.longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude')
], async (req, res) => {
    try {
        // Verificar errores de validación
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            logger.warn('WhatsApp alert validation failed', {
                userToken: req.user.user_token.substring(0, 8) + '***',
                errors: errors.array()
            });
            return res.status(400).json({
                error: 'Validation failed',
                details: errors.array()
            });
        }

        const { message, contacts, location, timestamp } = req.body;
        const user = req.user;

        // Verificar que el usuario tenga premium activo
        if (!user.premium_active) {
            logger.auth.warn('Non-premium user attempted WhatsApp service', {
                userToken: user.user_token.substring(0, 8) + '***',
                ip: req.ip
            });
            return res.status(403).json({
                error: 'Premium subscription required',
                message: 'WhatsApp service is only available for premium users'
            });
        }

        // Verificar cuota de mensajes
        const totalMessages = contacts.length * (location ? 2 : 1); // 2 mensajes si incluye ubicación
        if (user.whatsapp_quota_used + totalMessages > user.whatsapp_quota_limit) {
            logger.warn('WhatsApp quota exceeded', {
                userToken: user.user_token.substring(0, 8) + '***',
                quotaUsed: user.whatsapp_quota_used,
                quotaLimit: user.whatsapp_quota_limit,
                requestedMessages: totalMessages
            });
            return res.status(429).json({
                error: 'Quota exceeded',
                message: 'Monthly WhatsApp message limit exceeded',
                quota: {
                    used: user.whatsapp_quota_used,
                    limit: user.whatsapp_quota_limit,
                    remaining: user.whatsapp_quota_limit - user.whatsapp_quota_used
                }
            });
        }

        // Extraer números de teléfono
        const phoneNumbers = contacts.map(contact => contact.phoneNumber);

        // Crear mensaje de emergencia
        const emergencyMessage = message || whatsappService.createEmergencyMessage(location, new Date(timestamp));

        logger.whatsapp.info('Starting emergency alert', {
            userToken: user.user_token.substring(0, 8) + '***',
            recipients: phoneNumbers.length,
            hasLocation: !!location,
            messageLength: emergencyMessage.length
        });

        // Enviar mensajes
        const result = await whatsappService.sendBulkEmergencyAlert(
            phoneNumbers,
            emergencyMessage,
            location?.latitude,
            location?.longitude
        );

        // Actualizar cuota del usuario
        const quotaUpdate = await database.incrementQuotaUsage(user.id);

        // Log del mensaje en la base de datos
        const messageLog = await database.logMessage(
            user.id,
            'emergency_alert',
            contacts,
            emergencyMessage,
            location,
            result.results.map(r => r.results?.[0]?.messageId).filter(Boolean).join(','),
            result.success ? 'sent' : 'failed',
            result.success ? null : JSON.stringify(result.results.filter(r => !r.success).map(r => r.error))
        );

        // Actualizar actividad del usuario
        await database.updateUserActivity(user.id);

        logger.whatsapp.info('Emergency alert completed', {
            userToken: user.user_token.substring(0, 8) + '***',
            messageLogId: messageLog.id,
            successful: result.summary.successful,
            failed: result.summary.failed,
            quotaUsed: quotaUpdate.whatsapp_quota_used
        });

        res.status(200).json({
            success: result.success,
            message: result.success ? 'Emergency alert sent successfully' : 'Emergency alert partially failed',
            data: {
                messageId: messageLog.id,
                timestamp: messageLog.sent_at,
                results: result.results.map(r => ({
                    phoneNumber: r.phoneNumber,
                    success: r.success,
                    error: r.error || null
                })),
                summary: result.summary,
                quota: {
                    used: quotaUpdate.whatsapp_quota_used,
                    limit: quotaUpdate.whatsapp_quota_limit,
                    remaining: quotaUpdate.whatsapp_quota_limit - quotaUpdate.whatsapp_quota_used
                }
            }
        });

    } catch (error) {
        logger.error('Emergency alert failed', {
            userToken: req.user?.user_token.substring(0, 8) + '***' || 'unknown',
            error: error.message,
            stack: error.stack
        });

        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to send emergency alert'
        });
    }
});

/**
 * POST /whatsapp/test-message
 * Endpoint para enviar mensaje de prueba
 */
router.post('/test-message', [
    authMiddleware,
    body('phoneNumber').isMobilePhone().withMessage('Valid phone number required'),
    body('message').optional().isString().isLength({ max: 500 }).withMessage('Message too long')
], async (req, res) => {
    try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(400).json({
                error: 'Validation failed',
                details: errors.array()
            });
        }

        const { phoneNumber, message } = req.body;
        const user = req.user;

        if (!user.premium_active) {
            return res.status(403).json({
                error: 'Premium subscription required'
            });
        }

        // Verificar cuota
        if (user.whatsapp_quota_used >= user.whatsapp_quota_limit) {
            return res.status(429).json({
                error: 'Quota exceeded',
                quota: {
                    used: user.whatsapp_quota_used,
                    limit: user.whatsapp_quota_limit
                }
            });
        }

        const testMessage = message || `🧪 Mensaje de prueba de AlertaTelegram

Este es un mensaje de prueba para verificar que el servicio WhatsApp funciona correctamente.

⏰ ${new Date().toLocaleString('es-ES')}

¡Tu configuración está funcionando perfectamente! 🎉`;

        const result = await whatsappService.sendTextMessage(phoneNumber, testMessage);

        if (result.success) {
            await database.incrementQuotaUsage(user.id);
            await database.logMessage(
                user.id,
                'test_message',
                [{ phoneNumber }],
                testMessage,
                null,
                result.messageId,
                'sent'
            );
        }

        res.status(200).json({
            success: result.success,
            message: result.success ? 'Test message sent successfully' : 'Failed to send test message',
            data: {
                messageId: result.messageId,
                phoneNumber: result.phoneNumber,
                error: result.error || null
            }
        });

    } catch (error) {
        logger.error('Test message failed', {
            userToken: req.user?.user_token.substring(0, 8) + '***',
            error: error.message
        });

        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to send test message'
        });
    }
});

/**
 * GET /whatsapp/quota
 * Obtener información de cuota del usuario
 */
router.get('/quota', authMiddleware, async (req, res) => {
    try {
        const user = req.user;

        res.status(200).json({
            success: true,
            data: {
                used: user.whatsapp_quota_used,
                limit: user.whatsapp_quota_limit,
                remaining: user.whatsapp_quota_limit - user.whatsapp_quota_used,
                resetDate: user.whatsapp_quota_reset_at,
                percentage: Math.round((user.whatsapp_quota_used / user.whatsapp_quota_limit) * 100)
            }
        });

    } catch (error) {
        logger.error('Failed to get quota info', {
            userToken: req.user?.user_token.substring(0, 8) + '***',
            error: error.message
        });

        res.status(500).json({
            error: 'Internal server error'
        });
    }
});

/**
 * GET /whatsapp/service-info
 * Información del servicio WhatsApp
 */
router.get('/service-info', async (req, res) => {
    try {
        const serviceHealth = await whatsappService.checkServiceHealth();
        
        res.status(200).json({
            success: true,
            data: {
                serviceName: 'AlertaTelegram WhatsApp Service',
                version: '1.0.0',
                features: [
                    'Emergency alerts',
                    'Location sharing',
                    'Bulk messaging (max 3 contacts)',
                    'Premium only service'
                ],
                limits: {
                    maxContacts: 3,
                    monthlyQuota: 1000,
                    messageTypes: ['text', 'location']
                },
                health: serviceHealth
            }
        });

    } catch (error) {
        logger.error('Failed to get service info', {
            error: error.message
        });

        res.status(500).json({
            error: 'Internal server error'
        });
    }
});

/**
 * GET /whatsapp/health
 * Health check específico para WhatsApp
 */
router.get('/health', async (req, res) => {
    try {
        const serviceHealth = await whatsappService.checkServiceHealth();
        
        if (serviceHealth.healthy) {
            res.status(200).json({
                status: 'healthy',
                service: 'WhatsApp Business API',
                ...serviceHealth
            });
        } else {
            res.status(503).json({
                status: 'unhealthy',
                service: 'WhatsApp Business API',
                ...serviceHealth
            });
        }

    } catch (error) {
        logger.error('WhatsApp health check failed', {
            error: error.message
        });

        res.status(503).json({
            status: 'unhealthy',
            error: error.message
        });
    }
});

module.exports = router; 