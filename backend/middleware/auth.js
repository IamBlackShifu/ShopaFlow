const jwt = require('jsonwebtoken');

/**
 * Authentication middleware
 * Verifies JWT tokens and attaches user information to request
 */
const authMiddleware = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No token provided',
      });
    }
    
    const token = authHeader.split(' ')[1]; // Bearer <token>
    
    if (!token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid token format',
      });
    }
    
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret_here');
    
    // Attach user info to request
    req.user = decoded;
    req.userId = decoded.id;
    req.storeId = decoded.storeId;
    
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Token Expired',
        message: 'Your session has expired. Please log in again.',
      });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Invalid Token',
        message: 'The provided token is invalid.',
      });
    }
    
    return res.status(500).json({
      error: 'Authentication Error',
      message: 'An error occurred during authentication.',
    });
  }
};

/**
 * Optional authentication middleware
 * Allows requests with or without authentication
 */
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (authHeader) {
    try {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_jwt_secret_here');
      req.user = decoded;
      req.userId = decoded.id;
      req.storeId = decoded.storeId;
    } catch (error) {
      // Continue without authentication if token is invalid
      req.user = null;
    }
  }
  
  next();
};

/**
 * Role-based authorization middleware
 * Checks if user has required role
 */
const requireRole = (role) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication required',
      });
    }
    
    if (req.user.role !== role && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Access denied. Required role: ${role}`,
      });
    }
    
    next();
  };
};

/**
 * Store ownership middleware
 * Ensures user can only access their store's data
 */
const requireStoreAccess = (req, res, next) => {
  const storeId = req.params.storeId || req.body.storeId || req.query.storeId;
  
  if (storeId && req.user.role !== 'admin' && req.storeId !== parseInt(storeId)) {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Access denied. You can only access your store data.',
    });
  }
  
  next();
};

module.exports = {
  authMiddleware,
  optionalAuth,
  requireRole,
  requireStoreAccess,
};