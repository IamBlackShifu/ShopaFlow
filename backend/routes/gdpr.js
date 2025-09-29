const express = require('express');
const { body, validationResult } = require('express-validator');
const { asyncHandler } = require('../middleware/errorHandler');
const { TenantMiddleware } = require('../middleware/tenantMiddleware');
const SecurityUtils = require('../middleware/security');
const path = require('path');
const fs = require('fs');

const router = express.Router();
const tenantMiddleware = new TenantMiddleware(require('../db'));

// Apply tenant isolation to all GDPR routes
router.use(tenantMiddleware.extractTenant);

/**
 * @route   POST /api/gdpr/consent
 * @desc    Record user consent for GDPR compliance
 * @access  Private
 */
router.post('/consent', [
  body('consentType').isIn(['data_processing', 'marketing', 'analytics']).withMessage('Invalid consent type'),
  body('granted').isBoolean().withMessage('Granted must be boolean'),
], asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      errors: errors.array()
    });
  }

  const { consentType, granted } = req.body;
  
  await req.db.query(`
    INSERT INTO user_consent (
      user_id, tenant_id, consent_type, granted, ip_address, user_agent, legal_basis
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (user_id, tenant_id, consent_type)
    DO UPDATE SET 
      granted = EXCLUDED.granted,
      ip_address = EXCLUDED.ip_address,
      updated_at = NOW()
  `, [
    req.tenant.user_id,
    req.tenant.id,
    consentType,
    granted,
    req.ip,
    req.get('User-Agent'),
    'consent'
  ]);

  // Audit log
  global.gdprCompliance.auditLog('consent_recorded', req.tenant.user_id, req.tenant.id, {
    consentType,
    granted,
    ip: req.ip
  });

  res.json({
    success: true,
    message: 'Consent recorded successfully'
  });
}));

/**
 * @route   GET /api/gdpr/consent
 * @desc    Get user's current consent status
 * @access  Private
 */
router.get('/consent', asyncHandler(async (req, res) => {
  const consents = await req.db.query(
    'SELECT consent_type, granted, created_at, updated_at FROM user_consent WHERE user_id = $1 AND tenant_id = $2',
    [req.tenant.user_id, req.tenant.id]
  );

  res.json({
    success: true,
    data: { consents: consents.rows }
  });
}));

/**
 * @route   POST /api/gdpr/export-request
 * @desc    Request data export (Right to data portability)
 * @access  Private
 */
router.post('/export-request', asyncHandler(async (req, res) => {
  // Check if there's already a pending request
  const existingRequest = await req.db.query(
    'SELECT id FROM data_export_requests WHERE user_id = $1 AND tenant_id = $2 AND status = $3',
    [req.tenant.user_id, req.tenant.id, 'pending']
  );

  if (existingRequest.rows.length > 0) {
    return res.status(409).json({
      success: false,
      error: 'A data export request is already pending'
    });
  }

  // Create export request
  const result = await req.db.query(`
    INSERT INTO data_export_requests (
      tenant_id, user_id, request_type, expires_at
    ) VALUES ($1, $2, $3, $4)
    RETURNING id
  `, [
    req.tenant.id,
    req.tenant.user_id,
    'full_export',
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
  ]);

  // Audit log
  global.gdprCompliance.auditLog('data_export_requested', req.tenant.user_id, req.tenant.id, {
    requestId: result.rows[0].id
  });

  res.json({
    success: true,
    message: 'Data export request submitted. You will receive an email when ready.',
    data: { requestId: result.rows[0].id }
  });
}));

/**
 * @route   POST /api/gdpr/deletion-request
 * @desc    Request data deletion (Right to be forgotten)
 * @access  Private
 */
router.post('/deletion-request', [
  body('reason').optional().isLength({ max: 500 }).withMessage('Reason too long'),
  body('deletionType').isIn(['anonymization', 'full_deletion']).withMessage('Invalid deletion type'),
], asyncHandler(async (req, res) => {
  const { reason, deletionType } = req.body;

  // Create deletion request
  const result = await req.db.query(`
    INSERT INTO data_deletion_requests (
      tenant_id, user_id, deletion_type, reason
    ) VALUES ($1, $2, $3, $4)
    RETURNING id
  `, [
    req.tenant.id,
    req.tenant.user_id,
    deletionType,
    SecurityUtils.sanitizeInput(reason, 500)
  ]);

  // Audit log
  global.gdprCompliance.auditLog('data_deletion_requested', req.tenant.user_id, req.tenant.id, {
    requestId: result.rows[0].id,
    deletionType
  });

  res.json({
    success: true,
    message: 'Data deletion request submitted. This will be processed within 30 days.',
    data: { requestId: result.rows[0].id }
  });
}));

/**
 * @route   GET /api/gdpr/privacy-info
 * @desc    Get privacy policy and GDPR information
 * @access  Public
 */
router.get('/privacy-info', asyncHandler(async (req, res) => {
  const tenant = await req.db.query(
    'SELECT business_name, gdpr_contact_email, dpo_contact_email, privacy_policy_url FROM tenants WHERE id = $1',
    [req.tenant?.id || req.query.tenantId]
  );

  if (tenant.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Tenant not found'
    });
  }

  res.json({
    success: true,
    data: {
      businessName: tenant.rows[0].business_name,
      gdprContactEmail: tenant.rows[0].gdpr_contact_email || process.env.GDPR_CONTACT_EMAIL,
      dpoContactEmail: tenant.rows[0].dpo_contact_email || process.env.GDPR_DPO_EMAIL,
      privacyPolicyUrl: tenant.rows[0].privacy_policy_url,
      dataRetentionPeriod: '7 years',
      rightsAvailable: [
        'Right to access your data',
        'Right to rectification',
        'Right to erasure (right to be forgotten)',
        'Right to restrict processing',
        'Right to data portability',
        'Right to object to processing'
      ]
    }
  });
}));

module.exports = router;