const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const {
  register,
  login,
  checkPhone,
  getUserByPhone,
  verifyFirebase,
} = require('../controllers/authController');

// ============ VALIDATION RULES ============

const validateRegister = [
  body('name').notEmpty().withMessage('Name is required'),
  body('phone').notEmpty().withMessage('Phone number is required'),
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
];

const validateLogin = [
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('password').notEmpty().withMessage('Password is required'),
];

// express-validator's body() checks only collect errors on req; nothing
// rejects the request unless something reads validationResult(req) and
// responds. This middleware is that missing step - without it the rules
// above are declared but never enforced.
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: errors.array()[0].msg,
      errors: errors.array(),
    });
  }
  next();
};

// ============ ROUTES ============

router.post('/register', validateRegister, validate, register);
router.post('/login', validateLogin, validate, login);
router.post('/verify-firebase', verifyFirebase);
router.post('/check-phone', checkPhone);
router.post('/user-by-phone', getUserByPhone);

module.exports = router;
