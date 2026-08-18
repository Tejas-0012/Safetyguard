const User = require('../models/User');

// @desc    Get User Profile
// @route   GET /api/users/profile
// @access  Private
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id)
      .select('-password')
      .populate('contacts');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.status(200).json({
      success: true,
      user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Update User Profile
// @route   PUT /api/users/profile
// @access  Private
exports.updateProfile = async (req, res) => {
  try {
    const { name, phone, email, profileImage } = req.body;

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Update fields
    if (name) user.name = name;
    if (phone) user.phone = phone;
    if (email) user.email = email;
    if (profileImage) user.profileImage = profileImage;

    await user.save();

    res.status(200).json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        profileImage: user.profileImage,
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

// @desc    Update User Location
// @route   PUT /api/users/location
// @access  Private
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;

    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    user.currentLocation = {
      latitude,
      longitude,
      updatedAt: new Date()
    };

    await user.save();

    res.status(200).json({
      success: true,
      location: user.currentLocation
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};