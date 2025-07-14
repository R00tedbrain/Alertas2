const cron = require('node-cron');
const database = require('../database/connection');
const logger = require('../utils/logger');

/**
 * Resetear cuotas mensuales de WhatsApp
 * Se ejecuta diariamente a las 00:00
 */
function scheduleQuotaReset() {
    cron.schedule('0 0 * * *', async () => {
        try {
            logger.info('Starting monthly quota reset job');
            
            const result = await database.query(`
                UPDATE users 
                SET whatsapp_quota_used = 0,
                    whatsapp_quota_reset_at = CURRENT_TIMESTAMP + INTERVAL '1 month'
                WHERE whatsapp_quota_reset_at <= CURRENT_TIMESTAMP
                RETURNING id, user_token
            `);
            
            if (result.rowCount > 0) {
                logger.info('Monthly quota reset completed', {
                    usersAffected: result.rowCount,
                    userTokens: result.rows.map(row => row.user_token.substring(0, 8) + '***')
                });
            } else {
                logger.info('No users needed quota reset');
            }
            
        } catch (error) {
            logger.error('Failed to reset monthly quotas', {
                error: error.message,
                stack: error.stack
            });
        }
    }, {
        timezone: 'Europe/Madrid'
    });
    
    logger.info('Scheduled monthly quota reset job (daily at 00:00 CET)');
}

/**
 * Limpiar logs antiguos
 * Se ejecuta semanalmente los domingos a las 02:00
 */
function scheduleLogCleanup() {
    cron.schedule('0 2 * * 0', async () => {
        try {
            logger.info('Starting log cleanup job');
            
            // Eliminar logs de mensajes antiguos (más de 90 días)
            const result = await database.query(`
                DELETE FROM message_logs 
                WHERE sent_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
            `);
            
            logger.info('Log cleanup completed', {
                deletedRecords: result.rowCount
            });
            
        } catch (error) {
            logger.error('Failed to cleanup old logs', {
                error: error.message
            });
        }
    }, {
        timezone: 'Europe/Madrid'
    });
    
    logger.info('Scheduled log cleanup job (weekly on Sundays at 02:00 CET)');
}

/**
 * Actualizar estadísticas diarias
 * Se ejecuta diariamente a las 01:00
 */
function scheduleDailyStats() {
    cron.schedule('0 1 * * *', async () => {
        try {
            logger.info('Starting daily stats update job');
            
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 1);
            const yesterdayStr = yesterday.toISOString().split('T')[0];
            
            // Calcular estadísticas del día anterior
            const statsResult = await database.query(`
                INSERT INTO daily_stats (date, total_messages, successful_messages, failed_messages, unique_users)
                SELECT 
                    $1::date as date,
                    COUNT(*) as total_messages,
                    COUNT(CASE WHEN status = 'sent' THEN 1 END) as successful_messages,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_messages,
                    COUNT(DISTINCT user_id) as unique_users
                FROM message_logs 
                WHERE DATE(sent_at) = $1::date
                ON CONFLICT (date) DO UPDATE SET
                    total_messages = EXCLUDED.total_messages,
                    successful_messages = EXCLUDED.successful_messages,
                    failed_messages = EXCLUDED.failed_messages,
                    unique_users = EXCLUDED.unique_users
            `, [yesterdayStr]);
            
            logger.info('Daily stats updated', {
                date: yesterdayStr,
                recordsAffected: statsResult.rowCount
            });
            
        } catch (error) {
            logger.error('Failed to update daily stats', {
                error: error.message
            });
        }
    }, {
        timezone: 'Europe/Madrid'
    });
    
    logger.info('Scheduled daily stats job (daily at 01:00 CET)');
}

/**
 * Health check periódico del servicio WhatsApp
 * Se ejecuta cada hora
 */
function scheduleHealthCheck() {
    cron.schedule('0 * * * *', async () => {
        try {
            const whatsappService = require('../services/whatsapp');
            const health = await whatsappService.checkServiceHealth();
            
            if (!health.healthy) {
                logger.warn('WhatsApp service health check failed', {
                    error: health.error,
                    lastChecked: health.lastChecked
                });
            } else {
                logger.debug('WhatsApp service health check passed', {
                    phoneNumber: health.phoneNumber,
                    qualityRating: health.qualityRating
                });
            }
            
        } catch (error) {
            logger.error('Failed to perform WhatsApp health check', {
                error: error.message
            });
        }
    }, {
        timezone: 'Europe/Madrid'
    });
    
    logger.info('Scheduled WhatsApp health check (hourly)');
}

/**
 * Inicializar todos los trabajos programados
 */
function scheduleJobs() {
    logger.info('Initializing scheduled jobs...');
    
    scheduleQuotaReset();
    scheduleLogCleanup();
    scheduleDailyStats();
    scheduleHealthCheck();
    
    logger.info('All scheduled jobs initialized successfully');
}

module.exports = {
    scheduleJobs,
    scheduleQuotaReset,
    scheduleLogCleanup,
    scheduleDailyStats,
    scheduleHealthCheck
}; 