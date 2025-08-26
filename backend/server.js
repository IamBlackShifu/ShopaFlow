const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
require('dotenv').config();

// Import routes
const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const salesRoutes = require('./routes/sales');
const syncRoutes = require('./routes/sync');
const configRoutes = require('./routes/config');

// Import middleware
const { errorHandler } = require('./middleware/errorHandler');
const { authMiddleware } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression middleware
app.use(compression());

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
}));

// Logging middleware
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
  });
});

// API Documentation endpoint
app.get('/api/v1', (req, res) => {
  res.json({
    message: 'ShopaFlow API v1',
    version: '1.0.0',
    documentation: '/api/v1/docs',
    endpoints: {
      auth: '/api/v1/auth',
      products: '/api/v1/products',
      sales: '/api/v1/sales',
      sync: '/api/v1/sync',
      config: '/api/v1/config',
    },
  });
});

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/products', authMiddleware, productRoutes);
app.use('/api/v1/sales', authMiddleware, salesRoutes);
app.use('/api/v1/sync', authMiddleware, syncRoutes);
app.use('/api/v1/config', authMiddleware, configRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    timestamp: new Date().toISOString(),
  });
});

// Global error handler
app.use(errorHandler);

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Received SIGINT. Graceful shutdown...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('Received SIGTERM. Graceful shutdown...');
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  console.log(`
🚀 ShopaFlow API Server starting...
📡 Server running on port ${PORT}
🌍 Environment: ${process.env.NODE_ENV || 'development'}
⏰ Started at: ${new Date().toISOString()}
  `);
});

module.exports = app;