const Emergency = require('../models/Emergency');
const User = require('../models/User');
const Contact = require('../models/Contact');
const { sendEmergencyAlert } = require('../utils/notificationHelper');

// @desc    Start Emergency
// @route   POST /api/emergency/start
// @access  Private
exports.startEmergency = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;

    // Check if user already has active emergency
    const activeEmergency = await Emergency.findOne({
      userId: req.user.id,
      status: 'active'
    });

    if (activeEmergency) {
      return res.status(400).json({
        success: false,
        message: 'You already have an active emergency'
      });
    }

    // Create emergency record
    const emergency = await Emergency.create({
      userId: req.user.id,
      currentLocation: { latitude, longitude },
      locationPoints: [{ latitude, longitude }]
    });

    // Update user status
    await User.findByIdAndUpdate(req.user.id, {
      isEmergencyActive: true,
      emergencyStartTime: new Date()
    });

    // Get user's contacts
    const user = await User.findById(req.user.id).populate('contacts');
    const contacts = await Contact.find({
      _id: { $in: user.contacts }
    });

    // Send alerts to contacts
    const notifiedContacts = [];
    for (const contact of contacts) {
      await sendEmergencyAlert({
        contact,
        userName: user.name,
        location: { latitude, longitude },
        emergencyId: emergency._id
      });
      notifiedContacts.push(contact._id);
    }

    // Update emergency with notified contacts
    emergency.notifiedContacts = notifiedContacts;
    await emergency.save();

    res.status(201).json({
      success: true,
      emergency: {
        id: emergency._id,
        status: emergency.status,
        startTime: emergency.startTime,
        currentLocation: emergency.currentLocation,
        notifiedContacts: notifiedContacts.length
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Update Emergency Location
// @route   POST /api/emergency/:id/location
// @access  Private
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    const { id } = req.params;

    const emergency = await Emergency.findOne({
      _id: id,
      userId: req.user.id,
      status: 'active'
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Active emergency not found'
      });
    }

    // Add location point
    emergency.locationPoints.push({ latitude, longitude });
    emergency.currentLocation = { latitude, longitude };
    await emergency.save();

    // Update user location
    await User.findByIdAndUpdate(req.user.id, {
      'currentLocation.latitude': latitude,
      'currentLocation.longitude': longitude,
      'currentLocation.updatedAt': new Date()
    });

    res.status(200).json({
      success: true,
      location: emergency.currentLocation
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Stop Emergency
// @route   POST /api/emergency/:id/stop
// @access  Private
exports.stopEmergency = async (req, res) => {
  try {
    const { id } = req.params;

    const emergency = await Emergency.findOne({
      _id: id,
      userId: req.user.id,
      status: 'active'
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Active emergency not found'
      });
    }

    emergency.status = 'resolved';
    emergency.endTime = new Date();
    await emergency.save();

    // Update user status
    await User.findByIdAndUpdate(req.user.id, {
      isEmergencyActive: false,
      emergencyStartTime: null
    });

    res.status(200).json({
      success: true,
      message: 'Emergency stopped successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Get Emergency Status
// @route   GET /api/emergency/:id
// @access  Private
exports.getEmergencyStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const emergency = await Emergency.findById(id)
      .populate('userId', 'name phone email')
      .populate('notifiedContacts', 'name phone email');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found'
      });
    }

    res.status(200).json({
      success: true,
      emergency
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Get Emergency History
// @route   GET /api/emergency/history
// @access  Private
exports.getHistory = async (req, res) => {
  try {
    const emergencies = await Emergency.find({
      userId: req.user.id,
      status: { $ne: 'active' }
    })
    .sort({ startTime: -1 })
    .limit(50);

    res.status(200).json({
      success: true,
      emergencies
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Add Emergency Image
// @route   POST /api/emergency/:id/image
// @access  Private
exports.addImage = async (req, res) => {
  try {
    const { id } = req.params;
    const { imageUrl } = req.body;

    const emergency = await Emergency.findOne({
      _id: id,
      userId: req.user.id,
      status: 'active'
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Active emergency not found'
      });
    }

    emergency.cameraImages.push({ url: imageUrl });
    await emergency.save();

    res.status(200).json({
      success: true,
      image: emergency.cameraImages[emergency.cameraImages.length - 1]
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};