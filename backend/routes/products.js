const express = require('express');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router();

// In-memory product storage for development (replace with database in production)
const products = [
  {
    id: 1,
    name: 'Coca Cola 500ml',
    description: 'Refreshing cola drink',
    price: 1.50,
    cost: 0.80,
    stockQuantity: 25,
    minStockLevel: 10,
    barcode: '1234567890123',
    category: 'Beverages',
    sku: 'COKE-500',
    storeId: 1,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 2,
    name: 'Bread Loaf',
    description: 'Fresh white bread',
    price: 0.80,
    cost: 0.50,
    stockQuantity: 15,
    minStockLevel: 5,
    barcode: '2345678901234',
    category: 'Bakery',
    sku: 'BREAD-WHITE',
    storeId: 1,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 3,
    name: 'Milk 1L',
    description: 'Fresh whole milk',
    price: 2.20,
    cost: 1.50,
    stockQuantity: 8,
    minStockLevel: 10,
    barcode: '3456789012345',
    category: 'Dairy',
    sku: 'MILK-1L',
    storeId: 1,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 4,
    name: 'Rice 2kg',
    description: 'Long grain white rice',
    price: 4.50,
    cost: 3.00,
    stockQuantity: 12,
    minStockLevel: 5,
    barcode: '4567890123456',
    category: 'Groceries',
    sku: 'RICE-2KG',
    storeId: 1,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

/**
 * @route   GET /api/v1/products
 * @desc    Get all products for user's store
 * @access  Private
 */
router.get('/', asyncHandler(async (req, res) => {
  const { search, category, lowStock, page = 1, limit = 50 } = req.query;
  
  let filteredProducts = products.filter(p => 
    p.storeId === req.storeId && p.isActive
  );

  // Search filter
  if (search) {
    const searchTerm = search.toLowerCase();
    filteredProducts = filteredProducts.filter(p =>
      p.name.toLowerCase().includes(searchTerm) ||
      p.description.toLowerCase().includes(searchTerm) ||
      p.sku.toLowerCase().includes(searchTerm) ||
      p.barcode.includes(searchTerm)
    );
  }

  // Category filter
  if (category) {
    filteredProducts = filteredProducts.filter(p => 
      p.category.toLowerCase() === category.toLowerCase()
    );
  }

  // Low stock filter
  if (lowStock === 'true') {
    filteredProducts = filteredProducts.filter(p => 
      p.stockQuantity <= p.minStockLevel
    );
  }

  // Pagination
  const startIndex = (page - 1) * limit;
  const endIndex = page * limit;
  const paginatedProducts = filteredProducts.slice(startIndex, endIndex);

  res.json({
    success: true,
    data: {
      products: paginatedProducts,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(filteredProducts.length / limit),
        totalProducts: filteredProducts.length,
        hasNext: endIndex < filteredProducts.length,
        hasPrev: startIndex > 0,
      },
    },
  });
}));

/**
 * @route   GET /api/v1/products/:id
 * @desc    Get single product by ID
 * @access  Private
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const product = products.find(p => 
    p.id === parseInt(req.params.id) && 
    p.storeId === req.storeId && 
    p.isActive
  );

  if (!product) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  res.json({
    success: true,
    data: { product },
  });
}));

/**
 * @route   GET /api/v1/products/barcode/:barcode
 * @desc    Get product by barcode
 * @access  Private
 */
router.get('/barcode/:barcode', asyncHandler(async (req, res) => {
  const product = products.find(p => 
    p.barcode === req.params.barcode && 
    p.storeId === req.storeId && 
    p.isActive
  );

  if (!product) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  res.json({
    success: true,
    data: { product },
  });
}));

/**
 * @route   POST /api/v1/products
 * @desc    Create new product
 * @access  Private
 */
router.post('/', [
  body('name').notEmpty().withMessage('Product name is required'),
  body('price').isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('stockQuantity').isInt({ min: 0 }).withMessage('Stock quantity must be a non-negative integer'),
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
    name,
    description = '',
    price,
    cost = 0,
    stockQuantity,
    minStockLevel = 5,
    barcode = '',
    category = 'General',
    sku,
  } = req.body;

  // Check for duplicate SKU or barcode within store
  const duplicateSku = products.find(p => 
    p.sku === sku && p.storeId === req.storeId && p.isActive
  );
  const duplicateBarcode = barcode && products.find(p => 
    p.barcode === barcode && p.storeId === req.storeId && p.isActive
  );

  if (duplicateSku) {
    return res.status(400).json({
      success: false,
      error: 'Product with this SKU already exists',
    });
  }

  if (duplicateBarcode) {
    return res.status(400).json({
      success: false,
      error: 'Product with this barcode already exists',
    });
  }

  const newProduct = {
    id: Math.max(...products.map(p => p.id), 0) + 1,
    name,
    description,
    price: parseFloat(price),
    cost: parseFloat(cost),
    stockQuantity: parseInt(stockQuantity),
    minStockLevel: parseInt(minStockLevel),
    barcode,
    category,
    sku: sku || `PROD-${Date.now()}`,
    storeId: req.storeId,
    isActive: true,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  products.push(newProduct);

  res.status(201).json({
    success: true,
    message: 'Product created successfully',
    data: { product: newProduct },
  });
}));

/**
 * @route   PUT /api/v1/products/:id
 * @desc    Update product
 * @access  Private
 */
router.put('/:id', [
  body('name').optional().notEmpty().withMessage('Product name cannot be empty'),
  body('price').optional().isFloat({ min: 0 }).withMessage('Price must be a positive number'),
  body('stockQuantity').optional().isInt({ min: 0 }).withMessage('Stock quantity must be a non-negative integer'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const productIndex = products.findIndex(p => 
    p.id === parseInt(req.params.id) && 
    p.storeId === req.storeId && 
    p.isActive
  );

  if (productIndex === -1) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  const updatedProduct = {
    ...products[productIndex],
    ...req.body,
    id: products[productIndex].id, // Prevent ID changes
    storeId: products[productIndex].storeId, // Prevent store changes
    createdAt: products[productIndex].createdAt, // Preserve creation date
    updatedAt: new Date().toISOString(),
  };

  products[productIndex] = updatedProduct;

  res.json({
    success: true,
    message: 'Product updated successfully',
    data: { product: updatedProduct },
  });
}));

/**
 * @route   PUT /api/v1/products/:id/stock
 * @desc    Update product stock quantity
 * @access  Private
 */
router.put('/:id/stock', [
  body('stockQuantity').isInt({ min: 0 }).withMessage('Stock quantity must be a non-negative integer'),
  body('operation').optional().isIn(['set', 'add', 'subtract']).withMessage('Operation must be set, add, or subtract'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      details: errors.array(),
    });
  }

  const productIndex = products.findIndex(p => 
    p.id === parseInt(req.params.id) && 
    p.storeId === req.storeId && 
    p.isActive
  );

  if (productIndex === -1) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  const { stockQuantity, operation = 'set' } = req.body;
  let newStockQuantity;

  switch (operation) {
    case 'add':
      newStockQuantity = products[productIndex].stockQuantity + parseInt(stockQuantity);
      break;
    case 'subtract':
      newStockQuantity = Math.max(0, products[productIndex].stockQuantity - parseInt(stockQuantity));
      break;
    default: // 'set'
      newStockQuantity = parseInt(stockQuantity);
  }

  products[productIndex].stockQuantity = newStockQuantity;
  products[productIndex].updatedAt = new Date().toISOString();

  res.json({
    success: true,
    message: 'Stock updated successfully',
    data: { 
      product: products[productIndex],
      previousStock: operation === 'set' ? null : products[productIndex].stockQuantity - newStockQuantity,
    },
  });
}));

/**
 * @route   DELETE /api/v1/products/:id
 * @desc    Delete product (soft delete)
 * @access  Private
 */
router.delete('/:id', asyncHandler(async (req, res) => {
  const productIndex = products.findIndex(p => 
    p.id === parseInt(req.params.id) && 
    p.storeId === req.storeId && 
    p.isActive
  );

  if (productIndex === -1) {
    return res.status(404).json({
      success: false,
      error: 'Product not found',
    });
  }

  products[productIndex].isActive = false;
  products[productIndex].updatedAt = new Date().toISOString();

  res.json({
    success: true,
    message: 'Product deleted successfully',
  });
}));

/**
 * @route   GET /api/v1/products/categories
 * @desc    Get all product categories for store
 * @access  Private
 */
router.get('/meta/categories', asyncHandler(async (req, res) => {
  const storeProducts = products.filter(p => 
    p.storeId === req.storeId && p.isActive
  );

  const categories = [...new Set(storeProducts.map(p => p.category))].sort();

  res.json({
    success: true,
    data: { categories },
  });
}));

/**
 * @route   GET /api/v1/products/low-stock
 * @desc    Get products with low stock levels
 * @access  Private
 */
router.get('/alerts/low-stock', asyncHandler(async (req, res) => {
  const lowStockProducts = products.filter(p => 
    p.storeId === req.storeId && 
    p.isActive && 
    p.stockQuantity <= p.minStockLevel
  );

  res.json({
    success: true,
    data: {
      products: lowStockProducts,
      count: lowStockProducts.length,
    },
  });
}));

module.exports = router;