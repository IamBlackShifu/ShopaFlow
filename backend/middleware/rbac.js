/**
 * Role-Based Access Control (RBAC) middleware
 * Handles permission checking for different user roles
 */

/**
 * RBAC middleware factory
 * @param {Array} allowedRoles - Array of roles that can access the route
 * @returns {Function} Express middleware function
 */
const rbac = (allowedRoles = []) => {
  return (req, res, next) => {
    try {
      // Check if user is authenticated
      if (!req.user) {
        return res.status(401).json({
          success: false,
          error: 'Authentication required',
          message: 'Please log in to access this resource',
        });
      }

      const userRole = req.user.role;

      // Check if user role is in allowed roles
      if (!allowedRoles.includes(userRole)) {
        return res.status(403).json({
          success: false,
          error: 'Insufficient permissions',
          message: `Access denied. Required roles: ${allowedRoles.join(', ')}`,
          userRole,
          allowedRoles,
        });
      }

      // User has required permissions
      next();
    } catch (error) {
      console.error('RBAC middleware error:', error);
      return res.status(500).json({
        success: false,
        error: 'Authorization error',
        message: 'An error occurred while checking permissions',
      });
    }
  };
};

/**
 * Admin-only middleware
 */
const adminOnly = rbac(['admin']);

/**
 * Owner and Admin middleware
 */
const ownerOrAdmin = rbac(['owner', 'admin']);

/**
 * Manager, Owner and Admin middleware
 */
const managerOrAbove = rbac(['manager', 'owner', 'admin']);

/**
 * All staff roles middleware
 */
const staffAccess = rbac(['cashier', 'manager', 'owner', 'admin']);

/**
 * Tenant isolation middleware
 * Ensures users can only access data from their tenant
 */
const tenantIsolation = (req, res, next) => {
  try {
    if (!req.user || !req.user.tenant_id) {
      return res.status(401).json({
        success: false,
        error: 'Invalid user session',
        message: 'User session is missing tenant information',
      });
    }

    // Add tenant_id to request for database queries
    req.tenantId = req.user.tenant_id;
    next();
  } catch (error) {
    console.error('Tenant isolation error:', error);
    return res.status(500).json({
      success: false,
      error: 'Tenant isolation error',
      message: 'An error occurred while checking tenant access',
    });
  }
};

/**
 * Branch access middleware
 * Ensures users can only access data from their assigned branch (for cashiers)
 */
const branchAccess = (req, res, next) => {
  try {
    const userRole = req.user.role;
    
    // Admins and owners can access any branch
    if (['admin', 'owner'].includes(userRole)) {
      return next();
    }

    // Cashiers and managers must have a branch assigned
    if (!req.user.branch_id) {
      return res.status(403).json({
        success: false,
        error: 'No branch access',
        message: 'User is not assigned to any branch',
      });
    }

    // Add branch_id to request for database queries
    req.branchId = req.user.branch_id;
    next();
  } catch (error) {
    console.error('Branch access error:', error);
    return res.status(500).json({
      success: false,
      error: 'Branch access error',
      message: 'An error occurred while checking branch access',
    });
  }
};

module.exports = {
  rbac,
  adminOnly,
  ownerOrAdmin,
  managerOrAbove,
  staffAccess,
  tenantIsolation,
  branchAccess,
};