const { Pool } = require('pg');
const logger = require('../utils/logger');

class Database {
    constructor() {
        this.pool = null;
        this.isConnected = false;
    }

    async connect() {
        try {
            // Configuración de la conexión
            const config = {
                connectionString: process.env.DATABASE_URL,
                ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
                max: 20, // máximo número de conexiones en el pool
                idleTimeoutMillis: 30000, // tiempo de espera antes de cerrar conexión inactiva
                connectionTimeoutMillis: 2000, // tiempo de espera para conectar
                maxUses: 7500, // máximo número de usos por conexión antes de renovarla
            };

            this.pool = new Pool(config);

            // Event listeners para el pool
            this.pool.on('connect', (client) => {
                logger.debug('New database client connected', {
                    processId: client.processID
                });
            });

            this.pool.on('acquire', (client) => {
                logger.debug('Database client acquired from pool', {
                    processId: client.processID
                });
            });

            this.pool.on('error', (err, client) => {
                logger.error('Unexpected database pool error', {
                    error: err.message,
                    stack: err.stack,
                    processId: client?.processID
                });
            });

            this.pool.on('remove', (client) => {
                logger.debug('Database client removed from pool', {
                    processId: client.processID
                });
            });

            // Probar la conexión
            const client = await this.pool.connect();
            const result = await client.query('SELECT NOW() as current_time, version() as postgres_version');
            client.release();

            this.isConnected = true;
            
            logger.info('Database connection established successfully', {
                currentTime: result.rows[0].current_time,
                postgresVersion: result.rows[0].postgres_version.split(' ')[0] + ' ' + result.rows[0].postgres_version.split(' ')[1],
                poolSize: this.pool.totalCount,
                maxPoolSize: config.max
            });

            // Verificar si las tablas existen
            await this.checkTables();

            return true;
        } catch (error) {
            this.isConnected = false;
            logger.error('Failed to connect to database', {
                error: error.message,
                stack: error.stack,
                databaseUrl: process.env.DATABASE_URL ? 'Configured' : 'Not configured'
            });
            throw error;
        }
    }

    async checkTables() {
        try {
            const query = `
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_type = 'BASE TABLE'
                ORDER BY table_name;
            `;
            
            const result = await this.query(query);
            const tables = result.rows.map(row => row.table_name);
            
            const expectedTables = ['users', 'whatsapp_contacts', 'message_logs', 'daily_stats', 'rate_limits'];
            const missingTables = expectedTables.filter(table => !tables.includes(table));
            
            if (missingTables.length > 0) {
                logger.warn('Missing database tables detected', {
                    missingTables,
                    existingTables: tables,
                    note: 'Run database migrations to create missing tables'
                });
            } else {
                logger.info('All required database tables are present', {
                    tables: expectedTables
                });
            }
        } catch (error) {
            logger.error('Error checking database tables', {
                error: error.message
            });
        }
    }

    async query(text, params = []) {
        if (!this.isConnected) {
            throw new Error('Database is not connected');
        }

        const start = Date.now();
        try {
            const result = await this.pool.query(text, params);
            const duration = Date.now() - start;
            
            logger.debug('Database query executed', {
                query: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
                duration: `${duration}ms`,
                rowCount: result.rowCount
            });
            
            return result;
        } catch (error) {
            const duration = Date.now() - start;
            logger.error('Database query error', {
                query: text.substring(0, 100) + (text.length > 100 ? '...' : ''),
                duration: `${duration}ms`,
                error: error.message,
                params: params.length > 0 ? 'Has parameters' : 'No parameters'
            });
            throw error;
        }
    }

    async transaction(callback) {
        if (!this.isConnected) {
            throw new Error('Database is not connected');
        }

        const client = await this.pool.connect();
        
        try {
            await client.query('BEGIN');
            logger.debug('Database transaction started');
            
            const result = await callback(client);
            
            await client.query('COMMIT');
            logger.debug('Database transaction committed');
            
            return result;
        } catch (error) {
            await client.query('ROLLBACK');
            logger.error('Database transaction rolled back', {
                error: error.message
            });
            throw error;
        } finally {
            client.release();
        }
    }

    async getUser(userToken) {
        const query = `
            SELECT id, user_token, email, telegram_user_id, premium_active, 
                   premium_expires_at, subscription_type, whatsapp_quota_used, 
                   whatsapp_quota_limit, whatsapp_quota_reset_at, created_at, 
                   updated_at, last_active_at
            FROM users 
            WHERE user_token = $1
        `;
        
        const result = await this.query(query, [userToken]);
        return result.rows[0] || null;
    }

    async updateUserActivity(userId) {
        const query = `
            UPDATE users 
            SET last_active_at = CURRENT_TIMESTAMP 
            WHERE id = $1
        `;
        
        await this.query(query, [userId]);
    }

    async incrementQuotaUsage(userId) {
        const query = `
            UPDATE users 
            SET whatsapp_quota_used = whatsapp_quota_used + 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1
            RETURNING whatsapp_quota_used, whatsapp_quota_limit
        `;
        
        const result = await this.query(query, [userId]);
        return result.rows[0];
    }

    async getUserContacts(userId) {
        const query = `
            SELECT id, name, phone_number, is_active, created_at, updated_at
            FROM whatsapp_contacts 
            WHERE user_id = $1 AND is_active = true
            ORDER BY created_at ASC
        `;
        
        const result = await this.query(query, [userId]);
        return result.rows;
    }

    async logMessage(userId, messageType, recipients, messageContent, locationData, whatsappMessageId, status, errorMessage = null) {
        const query = `
            INSERT INTO message_logs 
            (user_id, message_type, recipients, message_content, location_data, whatsapp_message_id, status, error_message)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id, sent_at
        `;
        
        const result = await this.query(query, [
            userId, messageType, JSON.stringify(recipients), messageContent, 
            locationData ? JSON.stringify(locationData) : null, 
            whatsappMessageId, status, errorMessage
        ]);
        
        return result.rows[0];
    }

    async updateMessageStatus(messageId, status, deliveredAt = null, errorMessage = null) {
        const query = `
            UPDATE message_logs 
            SET status = $2, delivered_at = $3, error_message = $4
            WHERE id = $1
        `;
        
        await this.query(query, [messageId, status, deliveredAt, errorMessage]);
    }

    async getStats(startDate, endDate) {
        const query = `
            SELECT 
                DATE(sent_at) as date,
                COUNT(*) as total_messages,
                COUNT(CASE WHEN status = 'sent' THEN 1 END) as successful_messages,
                COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_messages,
                COUNT(DISTINCT user_id) as unique_users
            FROM message_logs 
            WHERE sent_at >= $1 AND sent_at < $2
            GROUP BY DATE(sent_at)
            ORDER BY date DESC
        `;
        
        const result = await this.query(query, [startDate, endDate]);
        return result.rows;
    }

    async disconnect() {
        if (this.pool) {
            try {
                await this.pool.end();
                this.isConnected = false;
                logger.info('Database connection closed successfully');
            } catch (error) {
                logger.error('Error closing database connection', {
                    error: error.message
                });
                throw error;
            }
        }
    }

    async healthCheck() {
        try {
            if (!this.isConnected) {
                return { healthy: false, message: 'Database not connected' };
            }

            const result = await this.query('SELECT 1 as health_check');
            
            if (result.rows[0].health_check === 1) {
                return { 
                    healthy: true, 
                    message: 'Database is healthy',
                    totalConnections: this.pool.totalCount,
                    idleConnections: this.pool.idleCount,
                    waitingCount: this.pool.waitingCount
                };
            } else {
                return { healthy: false, message: 'Database health check failed' };
            }
        } catch (error) {
            logger.error('Database health check failed', {
                error: error.message
            });
            return { 
                healthy: false, 
                message: 'Database health check error',
                error: error.message 
            };
        }
    }
}

// Crear instancia singleton
const database = new Database();

module.exports = database; 