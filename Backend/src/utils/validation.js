const { body, validationResult } = require('express-validator');

// Validation rules
const validateRegister = [
  body('name')
    .notEmpty()
    .withMessage('Name is required')
    .isLength({ max: 50 })
    .withMessage('Name cannot be more than 50 characters'),
  body('phone')
    .notEmpty()
    .withMessage('Phone number is required')
    .custom((value) => {
      // ✅ Accept +91 and 10-digit numbers
      const cleaned = value.replace(/[\s\-\(\)]/g, '');
      const isValid = /^\+?[0-9]{10,14}$/.test(cleaned);
      if (!isValid) {
        throw new Error('Please provide a valid phone number with country code');
      }
      return true;
    }),
    body('email')
    .isEmail()
    .withMessage('Please provide a valid email')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
];

const validateLogin = [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required'),
];

const validateContact = [
  body('name')
    .notEmpty()
    .withMessage('Name is required')
    .isLength({ max: 50 })
    .withMessage('Name cannot be more than 50 characters'),
  body('phone')
    .notEmpty()
    .withMessage('Phone number is required')
    .matches(/^\+?[0-9]{10,14}$/)
    .withMessage('Please provide a valid phone number'),
  body('email')
    .optional()
    .isEmail()
    .withMessage('Please provide a valid email')
    .normalizeEmail(),
  body('relation')
    .optional()
    .isIn(['Parent', 'Spouse', 'Sibling', 'Friend', 'Other'])
    .withMessage('Invalid relation'),
];

const validateEmergency = [
  body('latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Invalid latitude'),
  body('longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Invalid longitude'),
];

// Middleware to handle validation errors
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      errors: errors.array(),
    });
  }
  next();
};

module.exports = {
  validateRegister,
  validateLogin,
  validateContact,
  validateEmergency,
  handleValidationErrors,
};