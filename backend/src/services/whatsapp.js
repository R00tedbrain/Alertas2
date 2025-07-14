const axios = require('axios');
const logger = require('../utils/logger');

class WhatsAppService {
    constructor() {
        this.accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
        this.phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
        this.businessAccountId = process.env.WHATSAPP_BUSINESS_ACCOUNT_ID;
        this.apiBaseUrl = process.env.API_BASE_URL || 'https://graph.facebook.com/v21.0';
        
        // Configurar axios con retry automático
        this.client = axios.create({
            baseURL: this.apiBaseUrl,
            timeout: 30000, // 30 segundos timeout
            headers: {
                'Authorization': `Bearer ${this.accessToken}`,
                'Content-Type': 'application/json'
            }
        });

        // Interceptor para logging automático
        this.client.interceptors.request.use(
            (config) => {
                logger.whatsapp.debug('WhatsApp API Request', {
                    method: config.method,
                    url: config.url,
                    data: config.data ? 'Has data' : 'No data'
                });
                return config;
            },
            (error) => {
                logger.whatsapp.error('WhatsApp API Request Error', { error: error.message });
                return Promise.reject(error);
            }
        );

        this.client.interceptors.response.use(
            (response) => {
                logger.whatsapp.debug('WhatsApp API Response', {
                    status: response.status,
                    url: response.config.url,
                    messageId: response.data?.messages?.[0]?.id || 'N/A'
                });
                return response;
            },
            (error) => {
                logger.whatsapp.error('WhatsApp API Response Error', {
                    status: error.response?.status,
                    url: error.config?.url,
                    error: error.response?.data || error.message
                });
                return Promise.reject(error);
            }
        );
    }

    /**
     * Validar número de teléfono internacional
     */
    validatePhoneNumber(phoneNumber) {
        // Formato internacional: +[código país][número]
        const regex = /^\+[1-9]\d{1,14}$/;
        return regex.test(phoneNumber);
    }

    /**
     * Limpiar número de teléfono para WhatsApp
     */
    cleanPhoneNumber(phoneNumber) {
        // Remover caracteres no numéricos excepto el +
        return phoneNumber.replace(/[^\d+]/g, '');
    }

    /**
     * Enviar mensaje de texto simple
     */
    async sendTextMessage(phoneNumber, message) {
        try {
            const cleanNumber = this.cleanPhoneNumber(phoneNumber);
            
            if (!this.validatePhoneNumber(cleanNumber)) {
                throw new Error(`Invalid phone number format: ${phoneNumber}`);
            }

            const payload = {
                messaging_product: "whatsapp",
                to: cleanNumber.substring(1), // Remover el + inicial
                type: "text",
                text: {
                    body: message
                }
            };

            const response = await this.client.post(`/${this.phoneNumberId}/messages`, payload);
            
            logger.whatsapp.info('Text message sent successfully', {
                to: cleanNumber,
                messageId: response.data.messages[0].id,
                status: response.data.messages[0].message_status
            });

            return {
                success: true,
                messageId: response.data.messages[0].id,
                phoneNumber: cleanNumber
            };

        } catch (error) {
            logger.whatsapp.error('Failed to send text message', {
                to: phoneNumber,
                error: error.response?.data || error.message
            });

            return {
                success: false,
                error: error.response?.data?.error || error.message,
                phoneNumber: phoneNumber
            };
        }
    }

    /**
     * Enviar mensaje con ubicación
     */
    async sendLocationMessage(phoneNumber, latitude, longitude, name = 'Ubicación de Emergencia', address = '') {
        try {
            const cleanNumber = this.cleanPhoneNumber(phoneNumber);
            
            if (!this.validatePhoneNumber(cleanNumber)) {
                throw new Error(`Invalid phone number format: ${phoneNumber}`);
            }

            const payload = {
                messaging_product: "whatsapp",
                to: cleanNumber.substring(1),
                type: "location",
                location: {
                    latitude: parseFloat(latitude),
                    longitude: parseFloat(longitude),
                    name: name,
                    address: address || `${latitude}, ${longitude}`
                }
            };

            const response = await this.client.post(`/${this.phoneNumberId}/messages`, payload);
            
            logger.whatsapp.info('Location message sent successfully', {
                to: cleanNumber,
                messageId: response.data.messages[0].id,
                latitude,
                longitude
            });

            return {
                success: true,
                messageId: response.data.messages[0].id,
                phoneNumber: cleanNumber
            };

        } catch (error) {
            logger.whatsapp.error('Failed to send location message', {
                to: phoneNumber,
                latitude,
                longitude,
                error: error.response?.data || error.message
            });

            return {
                success: false,
                error: error.response?.data?.error || error.message,
                phoneNumber: phoneNumber
            };
        }
    }

    /**
     * Enviar alerta de emergencia completa (texto + ubicación)
     */
    async sendEmergencyAlert(phoneNumber, message, latitude, longitude) {
        const results = [];

        try {
            // 1. Enviar mensaje de texto primero
            const textResult = await this.sendTextMessage(phoneNumber, message);
            results.push(textResult);

            // 2. Si el texto se envió exitosamente, enviar ubicación
            if (textResult.success && latitude && longitude) {
                // Pequeña pausa entre mensajes para evitar rate limiting
                await new Promise(resolve => setTimeout(resolve, 1000));
                
                const locationResult = await this.sendLocationMessage(
                    phoneNumber, 
                    latitude, 
                    longitude,
                    '🚨 Ubicación de Emergencia',
                    `Coordenadas: ${latitude}, ${longitude}`
                );
                results.push(locationResult);
            }

            const allSuccessful = results.every(r => r.success);
            
            logger.whatsapp.info('Emergency alert sent', {
                to: phoneNumber,
                textSent: textResult.success,
                locationSent: results.length > 1 ? results[1].success : false,
                allSuccessful
            });

            return {
                success: allSuccessful,
                results,
                phoneNumber
            };

        } catch (error) {
            logger.whatsapp.error('Failed to send emergency alert', {
                to: phoneNumber,
                error: error.message
            });

            return {
                success: false,
                error: error.message,
                results,
                phoneNumber
            };
        }
    }

    /**
     * Enviar mensaje a múltiples contactos
     */
    async sendBulkEmergencyAlert(phoneNumbers, message, latitude, longitude) {
        const results = [];
        const maxConcurrent = 3; // Máximo 3 mensajes concurrentes para evitar rate limiting

        logger.whatsapp.info('Starting bulk emergency alert', {
            recipients: phoneNumbers.length,
            hasLocation: !!(latitude && longitude)
        });

        // Procesar en lotes para evitar sobrecargar la API
        for (let i = 0; i < phoneNumbers.length; i += maxConcurrent) {
            const batch = phoneNumbers.slice(i, i + maxConcurrent);
            
            const batchPromises = batch.map(async (phoneNumber) => {
                try {
                    const result = await this.sendEmergencyAlert(phoneNumber, message, latitude, longitude);
                    return result;
                } catch (error) {
                    logger.whatsapp.error('Bulk alert failed for number', {
                        phoneNumber,
                        error: error.message
                    });
                    return {
                        success: false,
                        error: error.message,
                        phoneNumber
                    };
                }
            });

            const batchResults = await Promise.all(batchPromises);
            results.push(...batchResults);

            // Pausa entre lotes si no es el último
            if (i + maxConcurrent < phoneNumbers.length) {
                await new Promise(resolve => setTimeout(resolve, 2000));
            }
        }

        const successCount = results.filter(r => r.success).length;
        const failureCount = results.length - successCount;

        logger.whatsapp.info('Bulk emergency alert completed', {
            total: results.length,
            successful: successCount,
            failed: failureCount,
            successRate: `${((successCount / results.length) * 100).toFixed(1)}%`
        });

        return {
            success: successCount > 0,
            results,
            summary: {
                total: results.length,
                successful: successCount,
                failed: failureCount,
                successRate: (successCount / results.length) * 100
            }
        };
    }

    /**
     * Verificar estado del servicio WhatsApp
     */
    async checkServiceHealth() {
        try {
            // Verificar información del número de teléfono
            const response = await this.client.get(`/${this.phoneNumberId}?fields=display_phone_number,verified_name,quality_rating`);
            
            return {
                healthy: true,
                phoneNumber: response.data.display_phone_number,
                verifiedName: response.data.verified_name,
                qualityRating: response.data.quality_rating,
                lastChecked: new Date().toISOString()
            };
        } catch (error) {
            logger.whatsapp.error('WhatsApp service health check failed', {
                error: error.response?.data || error.message
            });

            return {
                healthy: false,
                error: error.response?.data || error.message,
                lastChecked: new Date().toISOString()
            };
        }
    }

    /**
     * Obtener información de la cuenta de WhatsApp Business
     */
    async getAccountInfo() {
        try {
            const response = await this.client.get(`/${this.businessAccountId}?fields=name,primary_business_location,timezone_id,message_template_namespace`);
            
            return {
                success: true,
                accountInfo: response.data
            };
        } catch (error) {
            logger.whatsapp.error('Failed to get account info', {
                error: error.response?.data || error.message
            });

            return {
                success: false,
                error: error.response?.data || error.message
            };
        }
    }

    /**
     * Crear mensaje de alerta de emergencia personalizado
     */
    createEmergencyMessage(userLocation, timestamp = new Date()) {
        const locationText = userLocation ? 
            `📍 Ubicación: ${userLocation.latitude}, ${userLocation.longitude}\nhttps://maps.google.com/?q=${userLocation.latitude},${userLocation.longitude}` : 
            '📍 Ubicación: No disponible';

        const message = `🚨 ALERTA DE EMERGENCIA 🚨

Necesito ayuda urgente.

${locationText}

⏰ Hora: ${timestamp.toLocaleTimeString('es-ES')}
📅 Fecha: ${timestamp.toLocaleDateString('es-ES')}

Este es un mensaje automático de AlertaTelegram.`;

        return message;
    }
}

// Crear instancia singleton
const whatsappService = new WhatsAppService();

module.exports = whatsappService; 