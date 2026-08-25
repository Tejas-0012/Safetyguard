const User = require('../models/User');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const { firebaseAuth } = require('../config/firebase');

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || '7d',
  });
};

// ============ REGISTER ============
// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public
exports.register = async (req, res) => {
  try {
    // ✅ LOG FULL REQUEST
    console.log('📝 ===== REGISTRATION ATTEMPT =====');
    console.log('📝 Request Body:', JSON.stringify(req.body, null, 2));
    console.log('📝 Headers:', req.headers);

    // Validate input
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('❌ Validation Errors:', JSON.stringify(errors.array(), null, 2));
      return res.status(400).json({
        success: false,
        errors: errors.array(),
      });
    }

    const { name, phone, email, password } = req.body;

    // ✅ LOG CLEANED DATA
    console.log('📝 Cleaned Data:', { name, phone, email, password: '***' });

    // Check if user already exists
    const existingUser = await User.findOne({
      $or: [{ email }, { phone }],
    });

    if (existingUser) {
      console.log('❌ User already exists:', { email, phone });
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email or phone',
      });
    }

    // Create user
    const user = await User.create({
      name,
      phone,
      email: email.toLowerCase(),
      password,
    });

    console.log('✅ User created successfully:', user._id);

    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      token,
      user,
    });
  } catch (error) {
    console.error('❌ ===== REGISTRATION ERROR =====');
    console.error('❌ Error:', error);
    console.error('❌ Error Stack:', error.stack);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error during registration',
    });
  }
};
// ============ LOGIN ============
// @desc    Login user
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        errors: errors.array(),
      });
    }

    const { email, password } = req.body;

    // Find user with password
    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    // Check password
    const isPasswordMatch = await user.comparePassword(password);
    if (!isPasswordMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    // Generate token
    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      token,
      user,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error during login',
    });
  }
};

// ============ VERIFY FIREBASE ============
// @desc    Verify Firebase token
// @route   POST /api/auth/verify-firebase
// @access  Public
exports.verifyFirebase = async (req, res) => {
  try {
    const { firebaseToken } = req.body;

    if (!firebaseToken) {
      return res.status(400).json({
        success: false,
        message: 'Firebase token is required',
      });
    }

    // Verify Firebase token
    const decodedToken = await firebaseAuth.verifyIdToken(firebaseToken);
    const { uid, email, phone_number, name } = decodedToken;

    // Check if user exists
    let user = await User.findOne({ firebaseUid: uid });

    if (!user) {
      // Create new user
      user = await User.create({
        firebaseUid: uid,
        name: name || 'User',
        email: email || '',
        phone: phone_number || '',
        password: Math.random().toString(36).slice(-8), // Random password
      });
    }

    // Generate JWT
    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      token,
      user,
    });
  } catch (error) {
    console.error('Firebase verification error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Firebase verification failed',
    });
  }
};