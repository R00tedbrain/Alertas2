const express = require('express');
const router = express.Router();
const database = require('../database/connection');
const logger = require('../utils/logger');

/**
 * GET /stats/service
 * Estadísticas básicas del servicio (públicas)
 */
router.get('/service', async (req, res) => {
    try {
        const stats = {
            service: 'AlertaTelegram WhatsApp Backend',
            version: '1.0.0',
            uptime: Math.floor(process.uptime()),
            timestamp: new Date().toISOString(),
            environment: process.env.NODE_ENV || 'development'
        };
        
        res.status(200).json({
            success: true,
            data: stats
        });
    } catch (error) {
        logger.error('Failed to get service stats', {
            error: error.message
        });
        
        res.status(500).json({
            error: 'Internal server error'
        });
    }
});

module.exports = router; 