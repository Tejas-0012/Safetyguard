const User = require('../models/User');
const jwt = require('jsonwebtoken');
const { firebaseAuth } = require('../config/firebase');

// Generate JWT Token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE
  });
};

// @desc    Register User
// @route   POST /api/auth/register
// @access  Public
exports.register = async (req, res) => {
  try {
    const { name, phone, email, password } = req.body;

    // Check if user exists
    const existingUser = await User.findOne({ $or: [{ email }, { phone }] });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email or phone'
      });
    }

    // Create user
    const user = await User.create({
      name,
      phone,
      email,
      password
    });

    // Generate token
    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        isEmergencyActive: user.isEmergencyActive
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Login User
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Check if user exists
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check password
    const isPasswordMatch = await user.comparePassword(password);
    if (!isPasswordMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Generate token
    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        isEmergencyActive: user.isEmergencyActive
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Check if a phone number is already registered
// @route   POST /api/auth/check-phone
// @access  Public
exports.checkPhone = async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({
        success: false,
        message: 'Phone number is required'
      });
    }

    const user = await User.findOne({ phone });
    res.status(200).json({
      success: true,
      exists: !!user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Log in a user via a phone number that's already been verified
//          through Firebase OTP on the client. Requires the Firebase ID
//          token (not just a bare phone number) so the server can verify
//          the phone was actually proven, not just claimed.
// @route   POST /api/auth/user-by-phone
// @access  Public (but requires a valid, freshly-issued Firebase ID token)
exports.getUserByPhone = async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({
        success: false,
        message: 'Firebase ID token is required'
      });
    }

    const decodedToken = await firebaseAuth.verifyIdToken(idToken);
    const { uid, phone_number } = decodedToken;

    if (!phone_number) {
      return res.status(400).json({
        success: false,
        message: 'Verified token has no associated phone number'
      });
    }

    // Match by firebaseUid first (returning user), then fall back to
    // matching by the verified phone number and linking the firebaseUid
    // (e.g. a user who originally registered with email/password logging
    // in by phone for the first time) - avoids creating a duplicate account.
    let user = await User.findOne({ firebaseUid: uid });
    if (!user) {
      user = await User.findOne({ phone: phone_number });
      if (user && !user.firebaseUid) {
        user.firebaseUid = uid;
        await user.save();
      }
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'No account found for this phone number. Please register first.'
      });
    }

    const token = generateToken(user._id);
    res.status(200).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        isEmergencyActive: user.isEmergencyActive
      }
    });
  } catch (error) {
    // Covers expired/invalid/tampered ID tokens
    res.status(401).json({
      success: false,
      message: 'Invalid or expired verification. Please try again.'
    });
  }
};

// @desc    Verify Firebase Token
// @route   POST /api/auth/verify-firebase
// @access  Public
exports.verifyFirebase = async (req, res) => {
  try {
    const { firebaseToken } = req.body;

    // Verify Firebase token
    const decodedToken = await firebaseAuth.verifyIdToken(firebaseToken);
    const { uid, email, phone_number, name } = decodedToken;

    // Check if user exists by firebaseUid, then fall back to matching by
    // phone/email (links this Firebase identity to an existing account
    // instead of creating a duplicate one).
    let user = await User.findOne({ firebaseUid: uid });

    if (!user && phone_number) {
      user = await User.findOne({ phone: phone_number });
    }
    if (!user && email) {
      user = await User.findOne({ email });
    }

    if (user && !user.firebaseUid) {
      user.firebaseUid = uid;
      await user.save();
    }

    if (!user) {
      // Create new user
      user = await User.create({
        firebaseUid: uid,
        name: name || 'User',
        email: email || '',
        phone: phone_number || '',
        password: Math.random().toString(36).slice(-8) // Random password
      });
    }

    // Generate JWT
    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        isEmergencyActive: user.isEmergencyActive
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};