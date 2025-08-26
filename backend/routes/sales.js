const express = require('express');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router();

// In-memory sales storage for development
const sales = [];
const saleItems = [];

/**
 * @route   POST /api/v1/sales
 * @desc    Create new sale
 * @access  Private
 */
router.post('/', [
  body('items').isArray({ min: 1 }).withMessage('At least one item is required'),
  body('items.*.productId').isInt({ min: 1 }).withMessage('Valid product ID is required'),
  body('items.*.quantity').isInt({ min: 1 }).withMessage('Valid quantity is required'),
  body('items.*.unitPrice').isFloat({ min: 0 }).withMessage('Valid unit price is required'),
  body('paymentMethod').isIn(['cash', 'card', 'mobile_money', 'credit']).withMessage('Valid payment method is required'),
  body('totalAmount').isFloat({ min: 0 }).withMessage('Valid total amount is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const {
    items,
    paymentMethod,
    totalAmount,
    taxAmount = 0,
    discountAmount = 0,
    customerId = null,
    notes = '',
  } = req.body;

  // Generate receipt number
  const receiptNumber = `RCP-${Date.now()}-${Math.random().toString(36).substr(2, 4).toUpperCase()}`;

  // Create sale record
  const newSale = {
    id: Math.max(...sales.map(s => s.id), 0) + 1,
    totalAmount: parseFloat(totalAmount),
    taxAmount: parseFloat(taxAmount),
    discountAmount: parseFloat(discountAmount),
    paymentMethod,
    paymentStatus: 'completed',
    customerId,
    employeeId: req.userId,
    receiptNumber,
    notes,
    storeId: req.storeId,
    saleDate: new Date().toISOString(),
    createdAt: new Date().toISOString(),
    synced: false,
  };

  sales.push(newSale);

  // Create sale items
  const newSaleItems = items.map(item => ({
    id: Math.max(...saleItems.map(si => si.id), 0) + saleItems.length + 1,
    saleId: newSale.id,
    productId: item.productId,
    quantity: parseInt(item.quantity),
    unitPrice: parseFloat(item.unitPrice),
    totalPrice: parseFloat(item.unitPrice) * parseInt(item.quantity),
    discountAmount: item.discountAmount || 0,
    createdAt: new Date().toISOString(),
  }));

  saleItems.push(...newSaleItems);

  // TODO: Update product stock levels (would be done in database transaction)
  // This is a placeholder for the stock update logic

  res.status(201).json({
    success: true,
    message: 'Sale completed successfully',
    data: {
      sale: newSale,
      items: newSaleItems,
    },
  });
}));

/**
 * @route   GET /api/v1/sales
 * @desc    Get sales for user's store
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const {
    startDate,
    endDate,
    paymentMethod,
    customerId,
    page = 1,
    limit = 50,
    sortBy = 'createdAt',
    sortOrder = 'desc',
  } = req.query;

  let filteredSales = sales.filter(s => s.storeId === req.storeId);

  // Date range filter
  if (startDate) {
    filteredSales = filteredSales.filter(s => 
      new Date(s.saleDate) >= new Date(startDate)
    );
  }
  if (endDate) {
    filteredSales = filteredSales.filter(s => 
      new Date(s.saleDate) <= new Date(endDate)
    );
  }

  // Payment method filter
  if (paymentMethod) {
    filteredSales = filteredSales.filter(s => 
      s.paymentMethod === paymentMethod
    );
  }

  // Customer filter
  if (customerId) {
    filteredSales = filteredSales.filter(s => 
      s.customerId === parseInt(customerId)
    );
  }

  // Sorting
  filteredSales.sort((a, b) => {
    const aValue = a[sortBy];
    const bValue = b[sortBy];
    
    if (sortOrder === 'desc') {
      return bValue > aValue ? 1 : -1;
    } else {
      return aValue > bValue ? 1 : -1;
    }
  });

  // Pagination
  const startIndex = (page - 1) * limit;
  const endIndex = page * limit;
  const paginatedSales = filteredSales.slice(startIndex, endIndex);

  res.json({
    success: true,
    data: {
      sales: paginatedSales,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(filteredSales.length / limit),
        totalSales: filteredSales.length,
        hasNext: endIndex < filteredSales.length,
        hasPrev: startIndex > 0,
      },
    },
  });
}));

/**
 * @route   GET /api/v1/sales/:id
 * @desc    Get single sale with items
 * @access  Private
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const sale = sales.find(s => 
    s.id === parseInt(req.params.id) && 
    s.storeId === req.storeId
  );

  if (!sale) {
    return res.status(404).json({
      success: false,
      error: 'Sale not found',
    });
  }

  // Get sale items
  const items = saleItems.filter(si => si.saleId === sale.id);

  res.json({
    success: true,
    data: {
      sale,
      items,
    },
  });
}));

/**
 * @route   GET /api/v1/sales/receipt/:receiptNumber
 * @desc    Get sale by receipt number
 * @access  Private
 */
router.get('/receipt/:receiptNumber', asyncHandler(async (req, res) => {
  const sale = sales.find(s => 
    s.receiptNumber === req.params.receiptNumber && 
    s.storeId === req.storeId
  );

  if (!sale) {
    return res.status(404).json({
      success: false,
      error: 'Sale not found',
    });
  }

  // Get sale items
  const items = saleItems.filter(si => si.saleId === sale.id);

  res.json({
    success: true,
    data: {
      sale,
      items,
    },
  });
}));

/**
 * @route   GET /api/v1/sales/analytics/summary
 * @desc    Get sales analytics summary
 * @access  Private
 */
router.get('/analytics/summary', asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;
  
  let storeSales = sales.filter(s => s.storeId === req.storeId);
  
  // Date range filter
  if (startDate) {
    storeSales = storeSales.filter(s => 
      new Date(s.saleDate) >= new Date(startDate)
    );
  }
  if (endDate) {
    storeSales = storeSales.filter(s => 
      new Date(s.saleDate) <= new Date(endDate)
    );
  }

  // Calculate summary statistics
  const totalSales = storeSales.length;
  const totalRevenue = storeSales.reduce((sum, sale) => sum + sale.totalAmount, 0);
  const totalTax = storeSales.reduce((sum, sale) => sum + sale.taxAmount, 0);
  const totalDiscounts = storeSales.reduce((sum, sale) => sum + sale.discountAmount, 0);
  const averageSaleValue = totalSales > 0 ? totalRevenue / totalSales : 0;

  // Payment method breakdown
  const paymentMethods = {};
  storeSales.forEach(sale => {
    paymentMethods[sale.paymentMethod] = (paymentMethods[sale.paymentMethod] || 0) + 1;
  });

  // Daily sales for the period
  const dailySales = {};
  storeSales.forEach(sale => {
    const date = new Date(sale.saleDate).toISOString().split('T')[0];
    if (!dailySales[date]) {
      dailySales[date] = { count: 0, revenue: 0 };
    }
    dailySales[date].count++;
    dailySales[date].revenue += sale.totalAmount;
  });

  res.json({
    success: true,
    data: {
      summary: {
        totalSales,
        totalRevenue,
        totalTax,
        totalDiscounts,
        averageSaleValue,
      },
      paymentMethods,
      dailySales,
      period: {
        startDate: startDate || null,
        endDate: endDate || null,
      },
    },
  });
}));

/**
 * @route   GET /api/v1/sales/analytics/top-products
 * @desc    Get top selling products
 * @access  Private
 */
router.get('/analytics/top-products', asyncHandler(async (req, res) => {
  const { startDate, endDate, limit = 10 } = req.query;
  
  let storeSales = sales.filter(s => s.storeId === req.storeId);
  
  // Date range filter
  if (startDate) {
    storeSales = storeSales.filter(s => 
      new Date(s.saleDate) >= new Date(startDate)
    );
  }
  if (endDate) {
    storeSales = storeSales.filter(s => 
      new Date(s.saleDate) <= new Date(endDate)
    );
  }

  // Get sale IDs for the filtered sales
  const saleIds = storeSales.map(s => s.id);
  
  // Get all sale items for these sales
  const relevantSaleItems = saleItems.filter(si => saleIds.includes(si.saleId));
  
  // Aggregate by product
  const productStats = {};
  relevantSaleItems.forEach(item => {
    if (!productStats[item.productId]) {
      productStats[item.productId] = {
        productId: item.productId,
        totalQuantity: 0,
        totalRevenue: 0,
        salesCount: 0,
      };
    }
    productStats[item.productId].totalQuantity += item.quantity;
    productStats[item.productId].totalRevenue += item.totalPrice;
    productStats[item.productId].salesCount++;
  });

  // Convert to array and sort by quantity sold
  const topProducts = Object.values(productStats)
    .sort((a, b) => b.totalQuantity - a.totalQuantity)
    .slice(0, parseInt(limit));

  res.json({
    success: true,
    data: {
      topProducts,
      period: {
        startDate: startDate || null,
        endDate: endDate || null,
      },
    },
  });
}));

/**
 * @route   PUT /api/v1/sales/:id/refund
 * @desc    Process refund for a sale
 * @access  Private
 */
router.put('/:id/refund', [
  body('reason').notEmpty().withMessage('Refund reason is required'),
  body('refundAmount').isFloat({ min: 0 }).withMessage('Valid refund amount is required'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const saleIndex = sales.findIndex(s => 
    s.id === parseInt(req.params.id) && 
    s.storeId === req.storeId
  );

  if (saleIndex === -1) {
    return res.status(404).json({
      success: false,
      error: 'Sale not found',
    });
  }

  const { reason, refundAmount } = req.body;

  // Update sale with refund information
  sales[saleIndex].paymentStatus = 'refunded';
  sales[saleIndex].refundAmount = parseFloat(refundAmount);
  sales[saleIndex].refundReason = reason;
  sales[saleIndex].refundDate = new Date().toISOString();
  sales[saleIndex].refundedBy = req.userId;

  res.json({
    success: true,
    message: 'Refund processed successfully',
    data: { sale: sales[saleIndex] },
  });
}));

module.exports = router;