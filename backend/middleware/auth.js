const jwt = require('jsonwebtoken');
const db = require('../db');
const SecurityUtils = require('./security');

/**
 * Enhanced Authentication middleware with session validation
 * Verifies JWT tokens, validates sessions, and attaches user information to request
 */
const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'No token provided',
      });
    }
    
    const token = authHeader.split(' ')[1]; // Bearer <token>
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Invalid token format',
      });
    }
    
    try {
      // Verify JWT token with enhanced security
      const decoded = jwt.verify(token, process.env.JWT_SECRET, {
        issuer: 'ShopaFlow',
        algorithms: ['HS256']
      });

      // Validate session is still active (if sessionId exists)
      if (decoded.sessionId) {
        const sessionResult = await db.query(
          'SELECT id, user_id, tenant_id, is_active, expires_at FROM user_sessions WHERE session_id = $1 AND user_id = $2',
          [decoded.sessionId, decoded.userId]
        );

        if (sessionResult.rows.length === 0 || !sessionResult.rows[0].is_active) {
          // Log invalid session attempt
          await db.query(
            'INSERT INTO security_events (tenant_id, user_id, event_type, severity, details, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5, $6, $7)',
            [
              decoded.tenantId,
              decoded.userId,
              'INVALID_SESSION_ACCESS',
              'high',
              JSON.stringify({ 
                session_id: decoded.sessionId, 
                token_used: true,
                reason: sessionResult.rows.length === 0 ? 'session_not_found' : 'session_inactive'
              }),
              req.ip,
              req.get('User-Agent')
            ]
          );
          
          return res.status(401).json({
            success: false,
            error: 'Session Invalid',
            message: 'Session expired or invalid. Please login again.',
          });
        }

        const session = sessionResult.rows[0];
        
        // Check if session has expired
        if (new Date() > new Date(session.expires_at)) {
          // Mark session as expired
          await db.query(
            'UPDATE user_sessions SET is_active = FALSE WHERE session_id = $1',
            [decoded.sessionId]
          );
          
          return res.status(401).json({
            success: false,
            error: 'Session Expired',
            message: 'Session expired. Please login again.',
          });
        }

        // Update session last activity
        await db.query(
          'UPDATE user_sessions SET last_activity = NOW() WHERE session_id = $1',
          [decoded.sessionId]
        );
      }

      // Verify user still exists and is active
      const userResult = await db.query(
        'SELECT id, email, role, tenant_id, branch_id, locked_until FROM users WHERE id = $1',
        [decoded.userId || decoded.id]
      );

      if (userResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          error: 'User Not Found',
          message: 'User not found or access denied.',
        });
      }

      const user = userResult.rows[0];
      
      // Check if user account is locked
      if (user.locked_until && new Date() < new Date(user.locked_until)) {
        return res.status(423).json({
          success: false,
          error: 'Account Locked',
          message: 'Account is temporarily locked.',
        });
      }
    
      // Attach enhanced user info to request
      req.user = {
        id: user.id,
        userId: user.id,
        email: user.email,
        role: user.role,
        tenantId: user.tenant_id,
        branchId: user.branch_id,
        sessionId: decoded.sessionId
      };
      req.userId = user.id;
      req.storeId = user.tenant_id; // For backward compatibility
      
      next();
    } catch (jwtError) {
      if (jwtError.name === 'TokenExpiredError') {
        return res.status(401).json({
          success: false,
          error: 'Token Expired',
          message: 'Your session has expired. Please log in again.',
        });
      } else if (jwtError.name === 'JsonWebTokenError') {
        // Log suspicious token usage
        await db.query(
          'INSERT INTO security_events (event_type, severity, details, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5)',
          [
            'INVALID_TOKEN_USAGE',
            'high',
            JSON.stringify({ error: jwtError.message, token_provided: !!token }),
            req.ip,
            req.get('User-Agent')
          ]
        );
        
        return res.status(401).json({
          success: false,
          error: 'Invalid Token',
          message: 'The provided token is invalid.',
        });
      } else {
        throw jwtError;
      }
    }
  } catch (error) {
    console.error('Auth middleware error:', error);
    
    // Log system error
    try {
      await db.query(
        'INSERT INTO security_events (event_type, severity, details, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5)',
        [
          'AUTH_SYSTEM_ERROR',
          'high',
          JSON.stringify({ error: error.message }),
          req.ip,
          req.get('User-Agent')
        ]
      );
    } catch (logError) {
      console.error('Failed to log auth error:', logError);
    }
    
    return res.status(500).json({
      success: false,
      error: 'Authentication Error',
      message: 'An error occurred during authentication.',
    });
  }
};

/**
 * Enhanced optional authentication middleware
 * Allows requests with or without authentication with security logging
 */
const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (authHeader) {
    try {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET, {
        issuer: 'ShopaFlow',
        algorithms: ['HS256']
      });
      
      // Quick user validation for optional auth
      const userResult = await db.query(
        'SELECT id, email, role, tenant_id, branch_id FROM users WHERE id = $1',
        [decoded.userId || decoded.id]
      );
      
      if (userResult.rows.length > 0) {
        const user = userResult.rows[0];
        req.user = {
          id: user.id,
          userId: user.id,
          email: user.email,
          role: user.role,
          tenantId: user.tenant_id,
          branchId: user.branch_id,
          sessionId: decoded.sessionId
        };
        req.userId = user.id;
        req.storeId = user.tenant_id;
      }
    } catch (error) {
      // Continue without authentication if token is invalid
      req.user = null;
      
      // Log suspicious optional auth attempts
      if (error.name === 'JsonWebTokenError') {
        try {
          await db.query(
            'INSERT INTO security_events (event_type, severity, details, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5)',
            [
              'OPTIONAL_AUTH_INVALID_TOKEN',
              'low',
              JSON.stringify({ error: error.message }),
              req.ip,
              req.get('User-Agent')
            ]
          );
        } catch (logError) {
          console.error('Failed to log optional auth error:', logError);
        }
      }
    }
  }
  
  next();
};

/**
 * Enhanced role-based authorization middleware
 * Checks if user has required role with audit logging
 */
const requireRole = (role) => {
  return async (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Authentication required',
      });
    }
    
    if (req.user.role !== role && req.user.role !== 'owner') {
      // Log unauthorized access attempt
      try {
        await db.query(
          'INSERT INTO security_events (tenant_id, user_id, event_type, severity, details, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5, $6, $7)',
          [
            req.user.tenantId,
            req.user.userId,
            'UNAUTHORIZED_ROLE_ACCESS',
            'medium',
            JSON.stringify({ 
              required_role: role, 
              user_role: req.user.role,
              endpoint: req.originalUrl,
              method: req.method
            }),
            req.ip,
            req.get('User-Agent')
          ]
        );
      } catch (logError) {
        console.error('Failed to log role access attempt:', logError);
      }
      
      return res.status(403).json({
        success: false,
        error: 'Forbidden',
        message: `Access denied. Required role: ${role}`,
      });
    }
    
    next();
  };
};

/**
 * Enhanced tenant/store access middleware
 * Ensures user can only access their tenant's data with audit logging
 */
const requireStoreAccess = async (req, res, next) => {
  const storeId = req.params.storeId || req.body.storeId || req.query.storeId;
  const tenantId = req.params.tenantId || req.body.tenantId || req.query.tenantId;
  const userTenantId = req.user.tenantId || req.storeId;
  
  const targetId = storeId || tenantId;
  
  if (targetId && req.user.role !== 'owner' && userTenantId !== parseInt(targetId)) {
    // Log unauthorized tenant access attempt
    try {
      await db.query(
        'INSERT INTO security_events (tenant_id, user_id, event_type, severity, details, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5, $6, $7)',
        [
          req.user.tenantId,
          req.user.userId,
          'UNAUTHORIZED_TENANT_ACCESS',
          'high',
          JSON.stringify({ 
            user_tenant_id: userTenantId, 
            attempted_access_id: targetId,
            endpoint: req.originalUrl,
            method: req.method
          }),
          req.ip,
          req.get('User-Agent')
        ]
      );
    } catch (logError) {
      console.error('Failed to log tenant access attempt:', logError);
    }
    
    return res.status(403).json({
      success: false,
      error: 'Forbidden',
      message: 'Access denied. You can only access your tenant data.',
    });
  }
  
  next();
};

// Role-based authorization helpers
const ownerOnly = requireRole('owner');
const adminOnly = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Authentication required',
    });
  }
  
  if (!['owner', 'admin'].includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden',
      message: 'Access denied. Admin privileges required.',
    });
  }
  
  next();
};

const managerOnly = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Authentication required',
    });
  }
  
  if (!['owner', 'admin', 'manager'].includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      error: 'Forbidden',
      message: 'Access denied. Manager privileges required.',
    });
  }
  
  next();
};

module.exports = {
  authMiddleware,
  optionalAuth,
  requireRole,
  requireStoreAccess,
  ownerOnly,
  adminOnly,
  managerOnly,
};