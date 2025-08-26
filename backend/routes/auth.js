const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router();

// In-memory user storage for development (replace with database in production)
const users = [
  {
    id: 1,
    email: 'admin@shopaflow.com',
    password: '$2a$12$.2U9PQXD11RV1z07Rif0MOG3Slejxq6RBOi.a3YsLn5c.RuMzVlzq', // password123
    role: 'admin',
    storeId: 1,
    storeName: 'Demo Store',
    firstName: 'Admin',
    lastName: 'User',
    isActive: true,
    createdAt: new Date().toISOString(),
  },
  {
    id: 2,
    email: 'cashier@shopaflow.com',
    password: '$2a$12$.2U9PQXD11RV1z07Rif0MOG3Slejxq6RBOi.a3YsLn5c.RuMzVlzq', // password123
    role: 'cashier',
    storeId: 1,
    storeName: 'Demo Store',
    firstName: 'Cashier',
    lastName: 'User',
    isActive: true,
    createdAt: new Date().toISOString(),
  },
];

/**
 * Generate JWT token
 */
const generateToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
      storeId: user.storeId,
      storeName: user.storeName,
    },
    process.env.JWT_SECRET || 'your_jwt_secret_here',
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

/**
 * Generate refresh token
 */
const generateRefreshToken = (user) => {
  return jwt.sign(
    { id: user.id },
    process.env.JWT_REFRESH_SECRET || 'your_jwt_refresh_secret_here',
    { expiresIn: '30d' }
  );
};

/**
 * @route   POST /api/v1/auth/register
 * @desc    Register new user
 * @access  Public (will be restricted in production)
 */
router.post('/register', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('firstName').notEmpty().withMessage('First name is required'),
  body('lastName').notEmpty().withMessage('Last name is required'),
  body('storeName').notEmpty().withMessage('Store name is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const { email, password, firstName, lastName, storeName, role = 'admin' } = req.body;

  // Check if user already exists
  const existingUser = users.find(user => user.email === email);
  if (existingUser) {
    return res.status(400).json({
      success: false,
      error: 'User already exists with this email',
    });
  }

  // Hash password
  const salt = await bcrypt.genSalt(12);
  const hashedPassword = await bcrypt.hash(password, salt);

  // Create new user
  const newUser = {
    id: users.length + 1,
    email,
    password: hashedPassword,
    role,
    storeId: users.length + 1,
    storeName,
    firstName,
    lastName,
    isActive: true,
    createdAt: new Date().toISOString(),
  };

  users.push(newUser);

  // Generate tokens
  const token = generateToken(newUser);
  const refreshToken = generateRefreshToken(newUser);

  res.status(201).json({
    success: true,
    message: 'User registered successfully',
    data: {
      user: {
        id: newUser.id,
        email: newUser.email,
        firstName: newUser.firstName,
        lastName: newUser.lastName,
        role: newUser.role,
        storeId: newUser.storeId,
        storeName: newUser.storeName,
      },
      token,
      refreshToken,
    },
  });
}));

/**
 * @route   POST /api/v1/auth/login
 * @desc    Authenticate user and get token
 * @access  Public
 */
router.post('/login', [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const { email, password } = req.body;

  // Find user
  const user = users.find(u => u.email === email && u.isActive);
  if (!user) {
    return res.status(401).json({
      success: false,
      error: 'Invalid credentials',
    });
  }

  // Check password
  const isPasswordValid = await bcrypt.compare(password, user.password);
  if (!isPasswordValid) {
    return res.status(401).json({
      success: false,
      error: 'Invalid credentials',
    });
  }

  // Generate tokens
  const token = generateToken(user);
  const refreshToken = generateRefreshToken(user);

  res.json({
    success: true,
    message: 'Login successful',
    data: {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
        storeId: user.storeId,
        storeName: user.storeName,
      },
      token,
      refreshToken,
    },
  });
}));

/**
 * @route   POST /api/v1/auth/refresh
 * @desc    Refresh access token
 * @access  Public
 */
router.post('/refresh', [
  body('refreshToken').notEmpty().withMessage('Refresh token is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const { refreshToken } = req.body;

  try {
    // Verify refresh token
    const decoded = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET || 'your_jwt_refresh_secret_here'
    );

    // Find user
    const user = users.find(u => u.id === decoded.id && u.isActive);
    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid refresh token',
      });
    }

    // Generate new access token
    const newToken = generateToken(user);

    res.json({
      success: true,
      message: 'Token refreshed successfully',
      data: {
        token: newToken,
      },
    });
  } catch (error) {
    return res.status(401).json({
      success: false,
      error: 'Invalid or expired refresh token',
    });
  }
}));

/**
 * @route   GET /api/v1/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/me', require('../middleware/auth').authMiddleware, asyncHandler(async (req, res) => {
  const user = users.find(u => u.id === req.userId && u.isActive);
  
  if (!user) {
    return res.status(404).json({
      success: false,
      error: 'User not found',
    });
  }

  res.json({
    success: true,
    data: {
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
        storeId: user.storeId,
        storeName: user.storeName,
        createdAt: user.createdAt,
      },
    },
  });
}));

/**
 * @route   POST /api/v1/auth/logout
 * @desc    Logout user (invalidate token)
 * @access  Private
 */
router.post('/logout', require('../middleware/auth').authMiddleware, asyncHandler(async (req, res) => {
  // In a production app, you would:
  // 1. Add token to blacklist
  // 2. Remove refresh token from database
  // 3. Clear any session data
  
  res.json({
    success: true,
    message: 'Logged out successfully',
  });
}));

module.exports = router;