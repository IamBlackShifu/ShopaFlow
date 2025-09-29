-- GDPR Compliance and Security Tables
-- These tables ensure strict data isolation and GDPR compliance for multi-tenant SaaS

-- User consent tracking for GDPR compliance
CREATE TABLE user_consent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    consent_type VARCHAR(50) NOT NULL, -- 'data_processing', 'marketing', 'analytics'
    granted BOOLEAN NOT NULL,
    ip_address INET,
    user_agent TEXT,
    legal_basis VARCHAR(100), -- 'consent', 'contract', 'legitimate_interest'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_user_consent UNIQUE(user_id, tenant_id, consent_type)
);

-- Audit trail for all tenant data access (GDPR Article 30)
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL, -- 'create', 'read', 'update', 'delete', 'export'
    resource_type VARCHAR(50) NOT NULL, -- 'user', 'product', 'sale', 'branch'
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    request_path VARCHAR(500),
    sensitive_data BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure tenant isolation in audit logs
    CONSTRAINT audit_tenant_isolation CHECK (tenant_id IS NOT NULL)
);

-- Data export requests (Right to data portability - GDPR Article 20)
CREATE TABLE data_export_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_type VARCHAR(50) NOT NULL, -- 'full_export', 'specific_data'
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    file_path VARCHAR(500),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Data deletion requests (Right to be forgotten - GDPR Article 17)
CREATE TABLE data_deletion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    deletion_type VARCHAR(50) NOT NULL, -- 'anonymization', 'full_deletion'
    reason VARCHAR(500),
    status VARCHAR(50) DEFAULT 'pending',
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Session tracking for security
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Failed login attempts for security monitoring
CREATE TABLE failed_login_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255),
    ip_address INET NOT NULL,
    user_agent TEXT,
    attempted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Index for performance on security queries
    INDEX idx_failed_login_ip_time (ip_address, attempted_at)
);

-- Tenant-specific security settings
CREATE TABLE tenant_security_settings (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    password_policy JSONB DEFAULT '{"min_length": 12, "require_uppercase": true, "require_lowercase": true, "require_numbers": true, "require_special": true}',
    session_timeout_minutes INTEGER DEFAULT 480, -- 8 hours
    max_failed_login_attempts INTEGER DEFAULT 5,
    lockout_duration_minutes INTEGER DEFAULT 30,
    two_factor_required BOOLEAN DEFAULT false,
    data_retention_days INTEGER DEFAULT 2555, -- 7 years
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add encrypted fields to users table for sensitive data
ALTER TABLE users ADD COLUMN encrypted_phone VARCHAR(500);
ALTER TABLE users ADD COLUMN phone_hash VARCHAR(64);
ALTER TABLE users ADD COLUMN last_password_change TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE users ADD COLUMN failed_login_count INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN locked_until TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN two_factor_secret VARCHAR(255);
ALTER TABLE users ADD COLUMN two_factor_enabled BOOLEAN DEFAULT false;

-- Add GDPR fields to tenants
ALTER TABLE tenants ADD COLUMN gdpr_contact_email VARCHAR(255);
ALTER TABLE tenants ADD COLUMN dpo_contact_email VARCHAR(255);
ALTER TABLE tenants ADD COLUMN privacy_policy_url VARCHAR(500);
ALTER TABLE tenants ADD COLUMN terms_of_service_url VARCHAR(500);
ALTER TABLE tenants ADD COLUMN data_processing_agreement TEXT;

-- Indexes for performance and security
CREATE INDEX idx_audit_log_tenant_time ON audit_log(tenant_id, created_at);
CREATE INDEX idx_audit_log_user_action ON audit_log(user_id, action);
CREATE INDEX idx_user_consent_tenant ON user_consent(tenant_id, consent_type);
CREATE INDEX idx_user_sessions_active ON user_sessions(user_id, is_active, expires_at);
CREATE INDEX idx_failed_login_ip ON failed_login_attempts(ip_address);

-- Row Level Security policies for strict tenant isolation
CREATE POLICY tenant_isolation_audit_log ON audit_log
    FOR ALL TO authenticated_users
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_user_consent ON user_consent
    FOR ALL TO authenticated_users
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_export_requests ON data_export_requests
    FOR ALL TO authenticated_users
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- Enable RLS on new tables
ALTER TABLE user_consent ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_export_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_deletion_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_security_settings ENABLE ROW LEVEL SECURITY;