const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

/**
 * Tenant-aware middleware that enforces complete data isolation
 * This middleware MUST be used on all API endpoints that access tenant data
 */
class TenantMiddleware {
  constructor(dbPool) {
    this.db = dbPool;
  }

  /**
   * Extract and validate tenant from JWT token
   * Adds tenant_id and branch_id to request object
   */
  extractTenant = async (req, res, next) => {
    try {
      const authHeader = req.headers.authorization;
      
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
          success: false,
          error: 'Missing or invalid authorization header'
        });
      }

      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // Verify user exists and get full tenant context
      const userQuery = `
        SELECT 
          u.id as user_id,
          u.tenant_id,
          u.branch_id,
          u.role,
          u.permissions,
          u.is_active,
          t.subscription_status,
          t.business_name,
          b.name as branch_name
        FROM users u
        JOIN tenants t ON u.tenant_id = t.id
        LEFT JOIN branches b ON u.branch_id = b.id
        WHERE u.id = $1 AND u.is_active = true
      `;

      const userResult = await this.db.query(userQuery, [decoded.user_id]);
      
      if (userResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          error: 'Invalid user or inactive account'
        });
      }

      const user = userResult.rows[0];

      // Check subscription status
      if (user.subscription_status !== 'active') {
        return res.status(403).json({
          success: false,
          error: 'Account subscription is not active'
        });
      }

      // Add tenant context to request
      req.tenant = {
        id: user.tenant_id,
        user_id: user.user_id,
        branch_id: user.branch_id,
        role: user.role,
        permissions: user.permissions,
        business_name: user.business_name,
        branch_name: user.branch_name
      };

      next();
    } catch (error) {
      console.error('Tenant middleware error:', error);
      return res.status(401).json({
        success: false,
        error: 'Invalid token or tenant context'
      });
    }
  };

  /**
   * Require specific roles
   */
  requireRole = (allowedRoles) => {
    return (req, res, next) => {
      if (!req.tenant) {
        return res.status(401).json({
          success: false,
          error: 'Tenant context required'
        });
      }

      if (!allowedRoles.includes(req.tenant.role)) {
        return res.status(403).json({
          success: false,
          error: `Access denied. Required roles: ${allowedRoles.join(', ')}`
        });
      }

      next();
    };
  };

  /**
   * Require branch access (for branch-specific operations)
   */
  requireBranchAccess = () => {
    return (req, res, next) => {
      if (!req.tenant) {
        return res.status(401).json({
          success: false,
          error: 'Tenant context required'
        });
      }

      // Owners and admins can access any branch
      if (['owner', 'admin'].includes(req.tenant.role)) {
        return next();
      }

      // Cashiers and managers must have a branch assigned
      if (!req.tenant.branch_id) {
        return res.status(403).json({
          success: false,
          error: 'No branch access assigned'
        });
      }

      // If branch_id is specified in params, validate access
      const requestedBranchId = req.params.branch_id || req.body.branch_id;
      if (requestedBranchId && requestedBranchId !== req.tenant.branch_id) {
        return res.status(403).json({
          success: false,
          error: 'Access denied to this branch'
        });
      }

      next();
    };
  };

  /**
   * Database query wrapper that automatically adds tenant isolation
   */
  createTenantQuery = (baseQuery, params = []) => {
    // Ensure all queries include tenant_id filter
    if (!baseQuery.toLowerCase().includes('tenant_id')) {
      throw new Error('All tenant queries must include tenant_id filter');
    }
    return { query: baseQuery, params };
  };
}

/**
 * Helper functions for common tenant-aware database operations
 */
class TenantDatabase {
  constructor(dbPool, tenantId) {
    this.db = dbPool;
    this.tenantId = tenantId;
  }

  async query(text, params = []) {
    // Automatically inject tenant_id into all queries
    const tenantParams = [this.tenantId, ...params];
    return this.db.query(text, tenantParams);
  }

  // Products operations
  async getProducts(branchId = null, filters = {}) {
    let query = `
      SELECT 
        p.*,
        COALESCE(bi.stock_quantity, 0) as stock_quantity,
        COALESCE(bi.price_override_usd, p.price_usd) as current_price_usd,
        COALESCE(bi.price_override_zwl, p.price_zwl) as current_price_zwl
      FROM products p
      LEFT JOIN branch_inventory bi ON p.id = bi.product_id 
        AND bi.tenant_id = $1 
        ${branchId ? 'AND bi.branch_id = $2' : ''}
      WHERE p.tenant_id = $1 AND p.is_active = true
    `;

    const params = branchId ? [this.tenantId, branchId] : [this.tenantId];
    
    if (filters.search) {
      query += ` AND (p.name ILIKE $${params.length + 1} OR p.sku ILIKE $${params.length + 1})`;
      params.push(`%${filters.search}%`);
    }

    if (filters.category) {
      query += ` AND p.category = $${params.length + 1}`;
      params.push(filters.category);
    }

    query += ` ORDER BY p.name`;

    return this.db.query(query, params);
  }

  // Sales operations
  async createSale(branchId, saleData, saleItems) {
    const client = await this.db.connect();
    
    try {
      await client.query('BEGIN');

      // Insert sale
      const saleQuery = `
        INSERT INTO sales (
          tenant_id, branch_id, cashier_id, receipt_number,
          total_usd, total_zwl, tax_usd, tax_zwl,
          payment_method, customer_name, customer_phone, notes
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING id
      `;

      const saleResult = await client.query(saleQuery, [
        this.tenantId,
        branchId,
        saleData.cashier_id,
        saleData.receipt_number,
        saleData.total_usd,
        saleData.total_zwl,
        saleData.tax_usd || 0,
        saleData.tax_zwl || 0,
        saleData.payment_method,
        saleData.customer_name,
        saleData.customer_phone,
        saleData.notes
      ]);

      const saleId = saleResult.rows[0].id;

      // Insert sale items and update inventory
      for (const item of saleItems) {
        // Insert sale item
        await client.query(`
          INSERT INTO sale_items (
            tenant_id, sale_id, product_id, quantity,
            unit_price_usd, unit_price_zwl, total_price_usd, total_price_zwl
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `, [
          this.tenantId,
          saleId,
          item.product_id,
          item.quantity,
          item.unit_price_usd,
          item.unit_price_zwl,
          item.total_price_usd,
          item.total_price_zwl
        ]);

        // Update branch inventory
        await client.query(`
          UPDATE branch_inventory 
          SET stock_quantity = stock_quantity - $4,
              last_stock_update = NOW()
          WHERE tenant_id = $1 AND branch_id = $2 AND product_id = $3
        `, [this.tenantId, branchId, item.product_id, item.quantity]);
      }

      await client.query('COMMIT');
      return { success: true, sale_id: saleId };

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  // Branch operations
  async getBranches(userRole, userBranchId = null) {
    let query = `
      SELECT b.*, u.first_name || ' ' || u.last_name as manager_name
      FROM branches b
      LEFT JOIN users u ON b.manager_id = u.id
      WHERE b.tenant_id = $1 AND b.is_active = true
    `;

    const params = [this.tenantId];

    // Branch access control
    if (!['owner', 'admin'].includes(userRole) && userBranchId) {
      query += ` AND b.id = $2`;
      params.push(userBranchId);
    }

    query += ` ORDER BY b.name`;

    return this.db.query(query, params);
  }
}

module.exports = { TenantMiddleware, TenantDatabase };