-- Core tenants table - the foundation of multi-tenancy
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(100), -- retail, restaurant, wholesale
    subscription_plan VARCHAR(50) DEFAULT 'basic', -- basic, pro, enterprise
    subscription_status VARCHAR(20) DEFAULT 'active', -- active, suspended, cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Business details
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    tax_number VARCHAR(50),
    currency_primary VARCHAR(3) DEFAULT 'USD',
    currency_secondary VARCHAR(3) DEFAULT 'ZWL',
    exchange_rate DECIMAL(10,4) DEFAULT 320.0000,
    
    -- Subscription limits
    max_branches INTEGER DEFAULT 1,
    max_users INTEGER DEFAULT 5,
    max_products INTEGER DEFAULT 1000,
    
    -- Security
    api_key VARCHAR(255) UNIQUE,
    webhook_url VARCHAR(500),
    
    CONSTRAINT valid_subscription_plan CHECK (subscription_plan IN ('basic', 'pro', 'enterprise')),
    CONSTRAINT valid_subscription_status CHECK (subscription_status IN ('active', 'suspended', 'cancelled'))
);

-- Users table with tenant isolation
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL, -- owner, admin, manager, cashier
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Branch assignment (NULL means access to all branches)
    branch_id UUID,
    
    -- Permissions
    permissions JSONB DEFAULT '{}',
    
    CONSTRAINT unique_email_per_tenant UNIQUE (tenant_id, email),
    CONSTRAINT valid_role CHECK (role IN ('owner', 'admin', 'manager', 'cashier'))
);

-- Branches table
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(20) NOT NULL, -- unique branch identifier
    address TEXT,
    phone VARCHAR(20),
    manager_id UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Branch-specific settings
    settings JSONB DEFAULT '{}',
    
    CONSTRAINT unique_branch_code_per_tenant UNIQUE (tenant_id, code)
);

-- Add foreign key constraint for branch_id in users after branches table is created
ALTER TABLE users ADD CONSTRAINT fk_users_branch 
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL;

-- Products table with tenant and branch awareness
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(100),
    barcode VARCHAR(100),
    category VARCHAR(100),
    
    -- Pricing
    price_usd DECIMAL(10,2) NOT NULL,
    price_zwl DECIMAL(15,2),
    cost_usd DECIMAL(10,2),
    cost_zwl DECIMAL(15,2),
    
    -- Global product settings
    is_active BOOLEAN DEFAULT true,
    track_inventory BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_sku_per_tenant UNIQUE (tenant_id, sku),
    CONSTRAINT unique_barcode_per_tenant UNIQUE (tenant_id, barcode)
);

-- Branch inventory - tracks stock levels per branch
CREATE TABLE branch_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    stock_quantity INTEGER DEFAULT 0,
    min_stock_level INTEGER DEFAULT 5,
    max_stock_level INTEGER,
    reorder_point INTEGER DEFAULT 10,
    
    -- Branch-specific pricing overrides
    price_override_usd DECIMAL(10,2),
    price_override_zwl DECIMAL(15,2),
    
    last_stock_update TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_product_per_branch UNIQUE (tenant_id, branch_id, product_id)
);

-- Sales table
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    cashier_id UUID NOT NULL REFERENCES users(id),
    
    receipt_number VARCHAR(50) NOT NULL,
    
    -- Totals in both currencies
    total_usd DECIMAL(10,2) NOT NULL,
    total_zwl DECIMAL(15,2) NOT NULL,
    tax_usd DECIMAL(10,2) DEFAULT 0,
    tax_zwl DECIMAL(15,2) DEFAULT 0,
    discount_usd DECIMAL(10,2) DEFAULT 0,
    discount_zwl DECIMAL(15,2) DEFAULT 0,
    
    payment_method VARCHAR(50) NOT NULL, -- cash, card, mobile_money
    payment_status VARCHAR(20) DEFAULT 'completed',
    
    customer_name VARCHAR(255),
    customer_phone VARCHAR(20),
    
    notes TEXT,
    sale_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    synced_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT unique_receipt_per_branch UNIQUE (tenant_id, branch_id, receipt_number)
);

-- Sale items
CREATE TABLE sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    quantity INTEGER NOT NULL,
    unit_price_usd DECIMAL(10,2) NOT NULL,
    unit_price_zwl DECIMAL(15,2) NOT NULL,
    total_price_usd DECIMAL(10,2) NOT NULL,
    total_price_zwl DECIMAL(15,2) NOT NULL,
    
    discount_usd DECIMAL(10,2) DEFAULT 0,
    discount_zwl DECIMAL(15,2) DEFAULT 0
);

-- Indexes for performance
CREATE INDEX idx_users_tenant_id ON users(tenant_id);
CREATE INDEX idx_branches_tenant_id ON branches(tenant_id);
CREATE INDEX idx_products_tenant_id ON products(tenant_id);
CREATE INDEX idx_branch_inventory_tenant_branch ON branch_inventory(tenant_id, branch_id);
CREATE INDEX idx_sales_tenant_branch_date ON sales(tenant_id, branch_id, sale_date);
CREATE INDEX idx_sale_items_tenant_sale ON sale_items(tenant_id, sale_id);

-- Row Level Security (RLS) for additional data isolation
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE branch_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;