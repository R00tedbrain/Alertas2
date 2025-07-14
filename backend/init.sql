-- Inicialización de base de datos para AlertaTelegram WhatsApp Backend

-- Crear extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabla de usuarios Premium
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_token VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255),
    telegram_user_id VARCHAR(100),
    premium_active BOOLEAN DEFAULT FALSE,
    premium_expires_at TIMESTAMP WITH TIME ZONE,
    subscription_type VARCHAR(50) DEFAULT 'none', -- 'monthly', 'yearly', 'trial', 'none'
    whatsapp_quota_used INTEGER DEFAULT 0,
    whatsapp_quota_limit INTEGER DEFAULT 1000, -- Mensajes por mes
    whatsapp_quota_reset_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '1 month'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de contactos de WhatsApp
CREATE TABLE whatsapp_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Límite de 3 contactos por usuario
    CONSTRAINT max_contacts_per_user UNIQUE (user_id, id)
);

-- Tabla de mensajes enviados (para logs y estadísticas)
CREATE TABLE message_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    message_type VARCHAR(50) NOT NULL, -- 'emergency_alert', 'test_message'
    recipients JSONB NOT NULL, -- Array de números de teléfono
    message_content TEXT NOT NULL,
    location_data JSONB, -- Coordenadas de ubicación
    whatsapp_message_id VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'sent', 'delivered', 'failed'
    error_message TEXT,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP WITH TIME ZONE
);

-- Tabla de estadísticas diarias
CREATE TABLE daily_stats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL,
    total_messages INTEGER DEFAULT 0,
    successful_messages INTEGER DEFAULT 0,
    failed_messages INTEGER DEFAULT 0,
    unique_users INTEGER DEFAULT 0,
    premium_users INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(date)
);

-- Tabla de rate limiting
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    endpoint VARCHAR(255) NOT NULL,
    requests_count INTEGER DEFAULT 1,
    window_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    blocked_until TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(user_id, endpoint)
);

-- Índices para optimizar consultas
CREATE INDEX idx_users_user_token ON users(user_token);
CREATE INDEX idx_users_premium_active ON users(premium_active);
CREATE INDEX idx_users_telegram_user_id ON users(telegram_user_id);

CREATE INDEX idx_whatsapp_contacts_user_id ON whatsapp_contacts(user_id);
CREATE INDEX idx_whatsapp_contacts_phone ON whatsapp_contacts(phone_number);
CREATE INDEX idx_whatsapp_contacts_active ON whatsapp_contacts(is_active);

CREATE INDEX idx_message_logs_user_id ON message_logs(user_id);
CREATE INDEX idx_message_logs_sent_at ON message_logs(sent_at);
CREATE INDEX idx_message_logs_status ON message_logs(status);

CREATE INDEX idx_daily_stats_date ON daily_stats(date);

CREATE INDEX idx_rate_limits_user_id ON rate_limits(user_id);
CREATE INDEX idx_rate_limits_window ON rate_limits(window_start);

-- Función para validar límite de contactos
CREATE OR REPLACE FUNCTION check_contact_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM whatsapp_contacts WHERE user_id = NEW.user_id AND is_active = TRUE) >= 3 THEN
        RAISE EXCEPTION 'Maximum 3 WhatsApp contacts allowed per user';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para validar límite de contactos
CREATE TRIGGER trigger_check_contact_limit
    BEFORE INSERT ON whatsapp_contacts
    FOR EACH ROW
    EXECUTE FUNCTION check_contact_limit();

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para updated_at
CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_whatsapp_contacts_updated_at
    BEFORE UPDATE ON whatsapp_contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Función para resetear cuota mensual
CREATE OR REPLACE FUNCTION reset_monthly_quota()
RETURNS void AS $$
BEGIN
    UPDATE users 
    SET 
        whatsapp_quota_used = 0,
        whatsapp_quota_reset_at = CURRENT_TIMESTAMP + INTERVAL '1 month'
    WHERE whatsapp_quota_reset_at <= CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Insertar usuario de prueba (opcional)
INSERT INTO users (
    user_token, 
    email, 
    telegram_user_id, 
    premium_active, 
    premium_expires_at,
    subscription_type
) VALUES (
    'test_premium_user_2024',
    'test@***REMOVED***',
    '123456789',
    TRUE,
    CURRENT_TIMESTAMP + INTERVAL '1 year',
    'yearly'
) ON CONFLICT (user_token) DO NOTHING;

-- Mensaje de confirmación
DO $$
BEGIN
    RAISE NOTICE 'Base de datos inicializada correctamente para AlertaTelegram WhatsApp Backend';
    RAISE NOTICE 'Usuario de prueba creado con token: test_premium_user_2024';
END $$; 