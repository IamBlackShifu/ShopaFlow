const express = require('express');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const axios = require('axios');

const router = express.Router();

// In-memory config storage for development
const storeConfigs = {
  1: {
    id: 1,
    storeId: 1,
    storeName: 'Demo Store',
    currency: {
      primary: 'USD',
      secondary: 'ZWL',
      exchangeRate: 320.00,
      lastUpdated: new Date().toISOString(),
      autoUpdate: true,
    },
    receipt: {
      headerText: 'Welcome to Demo Store',
      footerText: 'Thank you for your business!',
      showTax: true,
      showDiscount: true,
      logoUrl: null,
    },
    notifications: {
      lowStockEnabled: true,
      lowStockThreshold: 10,
      dailyReportsEnabled: true,
      emailNotifications: true,
      smsNotifications: false,
    },
    payment: {
      ecocashEnabled: false,
      ecocashMerchantCode: '',
      oneMoneyEnabled: false,
      oneMoneyMerchantId: '',
      cashEnabled: true,
      cardEnabled: false,
    },
    hardware: {
      printerEnabled: false,
      printerType: 'thermal',
      scannerEnabled: false,
      cashDrawerEnabled: false,
    },
    sync: {
      autoSyncEnabled: true,
      syncInterval: 300, // 5 minutes
      syncOnSale: true,
      offlineModeEnabled: true,
    },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
};

/**
 * @route   GET /api/v1/config
 * @desc    Get store configuration
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const config = storeConfigs[req.storeId];
  
  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  res.json({
    success: true,
    data: { config },
  });
}));

/**
 * @route   PUT /api/v1/config
 * @desc    Update store configuration
 * @access  Private
 */
router.put('/', [
  body('storeName').optional().notEmpty().withMessage('Store name cannot be empty'),
  body('currency.primary').optional().isLength({ min: 3, max: 3 }).withMessage('Currency code must be 3 characters'),
  body('currency.exchangeRate').optional().isFloat({ min: 0 }).withMessage('Exchange rate must be positive'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const config = storeConfigs[req.storeId];
  
  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  // Update configuration
  const updatedConfig = {
    ...config,
    ...req.body,
    id: config.id,
    storeId: config.storeId,
    createdAt: config.createdAt,
    updatedAt: new Date().toISOString(),
  };

  storeConfigs[req.storeId] = updatedConfig;

  res.json({
    success: true,
    message: 'Configuration updated successfully',
    data: { config: updatedConfig },
  });
}));

/**
 * @route   GET /api/v1/config/exchange-rate
 * @desc    Get current exchange rate
 * @access  Private
 */
router.get('/exchange-rate', asyncHandler(async (req, res) => {
  const config = storeConfigs[req.storeId];
  
  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  res.json({
    success: true,
    data: {
      exchangeRate: config.currency,
    },
  });
}));

/**
 * @route   POST /api/v1/config/exchange-rate/update
 * @desc    Update exchange rate (manual or from API)
 * @access  Private
 */
router.post('/exchange-rate/update', [
  body('rate').optional().isFloat({ min: 0 }).withMessage('Exchange rate must be positive'),
  body('source').optional().isIn(['manual', 'api']).withMessage('Source must be manual or api'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const config = storeConfigs[req.storeId];
  
  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  const { rate, source = 'manual' } = req.body;
  let newRate = rate;

  // If no rate provided and source is API, fetch from external API
  if (!rate && source === 'api') {
    try {
      // Placeholder for actual exchange rate API
      // In production, you would use a real API like:
      // - Bank of Zimbabwe
      // - XE.com API
      // - CurrencyAPI
      // - Exchange Rates API
      
      // Simulate API call
      const mockApiResponse = {
        data: {
          USD_ZWL: 320.50 + (Math.random() * 10 - 5), // Random fluctuation
        },
      };
      
      newRate = mockApiResponse.data.USD_ZWL;
    } catch (error) {
      return res.status(500).json({
        success: false,
        error: 'Failed to fetch exchange rate from API',
        details: error.message,
      });
    }
  }

  if (!newRate) {
    return res.status(400).json({
      success: false,
      error: 'Exchange rate is required',
    });
  }

  // Update exchange rate
  config.currency.exchangeRate = parseFloat(newRate);
  config.currency.lastUpdated = new Date().toISOString();
  config.updatedAt = new Date().toISOString();

  res.json({
    success: true,
    message: 'Exchange rate updated successfully',
    data: {
      exchangeRate: config.currency,
      source,
      previousRate: rate || 'unknown',
    },
  });
}));

/**
 * @route   GET /api/v1/config/exchange-rate/history
 * @desc    Get exchange rate history (placeholder)
 * @access  Private
 */
router.get('/exchange-rate/history', asyncHandler(async (req, res) => {
  const { days = 7 } = req.query;
  
  // Simulate exchange rate history
  const history = [];
  const now = new Date();
  const baseRate = 320;
  
  for (let i = parseInt(days) - 1; i >= 0; i--) {
    const date = new Date(now.getTime() - (i * 24 * 60 * 60 * 1000));
    const rate = baseRate + (Math.random() * 20 - 10); // Random fluctuation
    
    history.push({
      date: date.toISOString().split('T')[0],
      rate: parseFloat(rate.toFixed(2)),
      source: Math.random() > 0.5 ? 'api' : 'manual',
    });
  }

  res.json({
    success: true,
    data: {
      history,
      period: `${days} days`,
    },
  });
}));

/**
 * @route   POST /api/v1/config/test-payment
 * @desc    Test payment gateway configuration
 * @access  Private
 */
router.post('/test-payment', [
  body('gateway').isIn(['ecocash', 'onemoney']).withMessage('Valid gateway is required'),
  body('amount').isFloat({ min: 0.01 }).withMessage('Valid test amount is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const { gateway, amount } = req.body;
  const config = storeConfigs[req.storeId];

  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  // Check if gateway is enabled
  const gatewayKey = `${gateway}Enabled`;
  if (!config.payment[gatewayKey]) {
    return res.status(400).json({
      success: false,
      error: `${gateway} payment gateway is not enabled`,
    });
  }

  // Simulate payment test
  const testResult = {
    gateway,
    amount: parseFloat(amount),
    success: Math.random() > 0.2, // 80% success rate for simulation
    transactionId: `TEST-${Date.now()}`,
    responseTime: Math.floor(Math.random() * 3000) + 500, // 500-3500ms
    timestamp: new Date().toISOString(),
  };

  if (!testResult.success) {
    testResult.error = 'Simulated payment failure for testing';
  }

  res.json({
    success: true,
    message: 'Payment test completed',
    data: { testResult },
  });
}));

/**
 * @route   GET /api/v1/config/receipt-preview
 * @desc    Generate receipt preview with current settings
 * @access  Private
 */
router.get('/receipt-preview', asyncHandler(async (req, res) => {
  const config = storeConfigs[req.storeId];
  
  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  // Generate mock receipt data
  const receiptData = {
    header: config.receipt.headerText,
    footer: config.receipt.footerText,
    storeName: config.storeName,
    receiptNumber: 'PREVIEW-001',
    date: new Date().toISOString(),
    items: [
      { name: 'Sample Product 1', quantity: 2, price: 1.50, total: 3.00 },
      { name: 'Sample Product 2', quantity: 1, price: 2.20, total: 2.20 },
    ],
    subtotal: 5.20,
    tax: config.receipt.showTax ? 0.52 : 0,
    discount: config.receipt.showDiscount ? 0.25 : 0,
    total: 5.47,
    paymentMethod: 'Cash',
    currency: config.currency,
  };

  res.json({
    success: true,
    data: { receiptData },
  });
}));

/**
 * @route   POST /api/v1/config/backup
 * @desc    Create configuration backup
 * @access  Private
 */
router.post('/backup', asyncHandler(async (req, res) => {
  const config = storeConfigs[req.storeId];
  
  if (!config) {
    return res.status(404).json({
      success: false,
      error: 'Store configuration not found',
    });
  }

  const backup = {
    version: '1.0',
    backupDate: new Date().toISOString(),
    storeId: req.storeId,
    config: { ...config },
  };

  res.json({
    success: true,
    message: 'Configuration backup created',
    data: { backup },
  });
}));

/**
 * @route   POST /api/v1/config/restore
 * @desc    Restore configuration from backup
 * @access  Private
 */
router.post('/restore', [
  body('backup').isObject().withMessage('Backup data is required'),
  body('backup.config').isObject().withMessage('Configuration data is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const { backup } = req.body;

  // Validate backup belongs to this store
  if (backup.storeId !== req.storeId) {
    return res.status(403).json({
      success: false,
      error: 'Backup does not belong to this store',
    });
  }

  // Restore configuration
  const restoredConfig = {
    ...backup.config,
    updatedAt: new Date().toISOString(),
    restoredAt: new Date().toISOString(),
    restoredFrom: backup.backupDate,
  };

  storeConfigs[req.storeId] = restoredConfig;

  res.json({
    success: true,
    message: 'Configuration restored successfully',
    data: { config: restoredConfig },
  });
}));

module.exports = router;