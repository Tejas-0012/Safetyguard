const Emergency = require('../models/Emergency');
const User = require('../models/User');
const Contact = require('../models/Contact');
const { messaging } = require('../config/firebase');
const crypto = require('crypto');

// ============ START EMERGENCY ============
// @desc    Start emergency
// @route   POST /api/emergency/start
// @access  Private
exports.startEmergency = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Latitude and longitude are required'
      });
    }

    const activeEmergency = await Emergency.findOne({
      userId: req.user.id,
      status: 'active'
    });

    if (activeEmergency) {
      return res.status(400).json({
        success: false,
        message: 'You already have an active emergency',
        emergencyId: activeEmergency._id
      });
    }

    const emergency = await Emergency.create({
      userId: req.user.id,
      currentLocation: { latitude, longitude },
      locationPoints: [{ latitude, longitude }],
      status: 'active'
    });

    await User.findByIdAndUpdate(req.user.id, {
      isEmergencyActive: true,
      emergencyStartTime: new Date()
    });

    const user = await User.findById(req.user.id).populate('contacts');
    const contacts = await Contact.find({
      _id: { $in: user.contacts }
    });

    const notifiedContacts = [];
    for (const contact of contacts) {
      try {
        await sendEmergencyNotification({
          contact,
          userName: user.name,
          location: { latitude, longitude },
          emergencyId: emergency._id
        });
        notifiedContacts.push(contact._id);
      } catch (error) {
        console.error(`Failed to notify ${contact.name}:`, error.message);
      }
    }

    emergency.notifiedContacts = notifiedContacts;
    await emergency.save();

    res.status(201).json({
      success: true,
      emergency: {
        id: emergency._id,
        status: emergency.status,
        startTime: emergency.startTime,
        currentLocation: emergency.currentLocation,
        notifiedContacts: notifiedContacts
      }
    });

  } catch (error) {
    console.error('Start emergency error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error starting emergency',
      error: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};

// ============ UPDATE LOCATION ============
// @desc    Update emergency location
// @route   POST /api/emergency/:id/location
// @access  Private
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    const { id } = req.params;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Latitude and longitude are required',
      });
    }

    const emergency = await Emergency.findOne({
      _id: id,
      userId: req.user.id,
      status: 'active',
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Active emergency not found',
      });
    }

    emergency.locationPoints.push({ latitude, longitude });
    emergency.currentLocation = { latitude, longitude };
    await emergency.save();

    await User.findByIdAndUpdate(req.user.id, {
      'currentLocation.latitude': latitude,
      'currentLocation.longitude': longitude,
      'currentLocation.updatedAt': new Date(),
    });

    res.status(200).json({
      success: true,
      location: emergency.currentLocation,
      pointCount: emergency.locationPoints.length,
    });
  } catch (error) {
    console.error('Update location error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error updating location',
    });
  }
};

// ============ STOP EMERGENCY ============
// @desc    Stop emergency
// @route   POST /api/emergency/:id/stop
// @access  Private
exports.stopEmergency = async (req, res) => {
  try {
    const { id } = req.params;

    const emergency = await Emergency.findOne({
      _id: id,
      userId: req.user.id,
      status: 'active',
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Active emergency not found',
      });
    }

    emergency.status = 'resolved';
    emergency.endTime = new Date();
    await emergency.save();

    await User.findByIdAndUpdate(req.user.id, {
      isEmergencyActive: false,
      emergencyStartTime: null,
    });

    res.status(200).json({
      success: true,
      message: 'Emergency stopped successfully',
      emergency,
    });
  } catch (error) {
    console.error('Stop emergency error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error stopping emergency',
    });
  }
};

// ============ GET EMERGENCY STATUS ============
// @desc    Get emergency status
// @route   GET /api/emergency/:id
// @access  Private
exports.getEmergencyStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const emergency = await Emergency.findById(id)
      .populate('userId', 'name phone email')
      .populate('notifiedContacts', 'name phone');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found',
      });
    }

    // Check if user is the sender OR a notified contact
    const isSender = emergency.userId._id.toString() === req.user.id;
    const isContact = emergency.notifiedContacts.some(
      contact => contact._id.toString() === req.user.id
    );

    if (!isSender && !isContact) {
      return res.status(403).json({
        success: false,
        message: 'You do not have access to this emergency',
      });
    }

    res.status(200).json({
      success: true,
      emergency,
      role: isSender ? 'sender' : 'receiver'
    });
  } catch (error) {
    console.error('Get emergency error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error getting emergency',
    });
  }
};

// ============ GET EMERGENCY HISTORY ============
// @desc    Get emergency history for user
// @route   GET /api/emergency/history
// @access  Private
exports.getHistory = async (req, res) => {
  try {
    const emergencies = await Emergency.find({
      userId: req.user.id,
      status: { $ne: 'active' },
    })
      .sort({ startTime: -1 })
      .limit(50)
      .populate('notifiedContacts', 'name phone');

    res.status(200).json({
      success: true,
      emergencies,
    });
  } catch (error) {
    console.error('Get history error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error getting history',
    });
  }
};

// ============ ADD IMAGE ============
// @desc    Add emergency image
// @route   POST /api/emergency/:id/image
// @access  Private
exports.addImage = async (req, res) => {
  try {
    const { id } = req.params;
    const { imageUrl } = req.body;

    if (!imageUrl) {
      return res.status(400).json({
        success: false,
        message: 'Image URL is required',
      });
    }

    const emergency = await Emergency.findOne({
      _id: id,
      userId: req.user.id,
      status: 'active',
    });

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Active emergency not found',
      });
    }

    emergency.cameraImages.push({ url: imageUrl });
    await emergency.save();

    res.status(200).json({
      success: true,
      image: emergency.cameraImages[emergency.cameraImages.length - 1],
    });
  } catch (error) {
    console.error('Add image error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error adding image',
    });
  }
};

// ============ ✅ NEW: RECEIVER REPLY ============
// @desc    Receiver replies to emergency
// @route   POST /api/emergency/:id/reply
// @access  Private
exports.replyToEmergency = async (req, res) => {
  try {
    const { id } = req.params;
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Reply message is required'
      });
    }

    const emergency = await Emergency.findById(id);
    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found'
      });
    }

    // Check if user is a notified contact
    const isContact = emergency.notifiedContacts.some(
      contactId => contactId.toString() === req.user.id
    );

    if (!isContact && emergency.userId.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to reply'
      });
    }

    // Get user name
    const user = await User.findById(req.user.id);
    const contactName = user ? user.name : 'Contact';

    // Add reply
    emergency.receiverReplies.push({
      contactId: req.user.id,
      contactName: contactName,
      message: message
    });
    await emergency.save();

    // ✅ Notify the sender via FCM
    const sender = await User.findById(emergency.userId);
    if (sender) {
      try {
        await messaging.send({
          notification: {
            title: '📩 Reply from Contact',
            body: `${contactName} says: "${message}"`,
          },
          data: {
            type: 'reply',
            emergencyId: emergency._id.toString(),
            contactName: contactName,
            message: message
          },
          topic: `user_${sender._id}`
        });
      } catch (fcmError) {
        console.log('FCM notify sender error:', fcmError.message);
      }
    }

    res.status(200).json({
      success: true,
      reply: {
        contactName: contactName,
        message: message,
        repliedAt: new Date()
      }
    });
  } catch (error) {
    console.error('Reply error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ============ ✅ NEW: GENERATE WEB STREAM URL ============
// @desc    Generate web stream URL for non-app users
// @route   POST /api/emergency/:id/web-stream
// @access  Private (Contact only)
exports.generateWebStream = async (req, res) => {
  try {
    const { id } = req.params;

    const emergency = await Emergency.findById(id)
      .populate('userId', 'name phone email')
      .populate('notifiedContacts', 'name phone');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found'
      });
    }

    // Check if user is a notified contact
    const isContact = emergency.notifiedContacts.some(
      contact => contact._id.toString() === req.user.id
    );

    if (!isContact) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to view this emergency'
      });
    }

    // Generate unique token for web access
    const token = crypto.randomBytes(32).toString('hex');
    emergency.webStreamToken = token;
    emergency.isWebStreamActive = true;
    await emergency.save();

    const baseUrl = process.env.FRONTEND_URL || 'http://localhost:3000';
    const webUrl = `${baseUrl}/receiver/${token}`;

    res.status(200).json({
      success: true,
      webUrl: webUrl,
      token: token
    });
  } catch (error) {
    console.error('Web stream error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ============ ✅ NEW: GET EMERGENCY DETAILS FOR WEB ============
// @desc    Get emergency details for web viewer
// @route   GET /api/emergency/web/:token
// @access  Public (via token)
exports.getEmergencyByToken = async (req, res) => {
  try {
    const { token } = req.params;

    const emergency = await Emergency.findOne({ webStreamToken: token })
      .populate('userId', 'name phone')
      .populate('notifiedContacts', 'name phone');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Invalid or expired link'
      });
    }

    if (emergency.status !== 'active') {
      return res.status(400).json({
        success: false,
        message: 'Emergency has ended'
      });
    }

    res.status(200).json({
      success: true,
      emergency: {
        id: emergency._id,
        userName: emergency.userId ? emergency.userId.name : 'Unknown',
        userPhone: emergency.userId ? emergency.userId.phone : 'No phone',
        startTime: emergency.startTime,
        status: emergency.status,
        currentLocation: emergency.currentLocation,
        locationPoints: emergency.locationPoints.slice(-30),
        cameraImages: emergency.cameraImages,
        isVideoActive: emergency.isVideoActive,
        receiverReplies: emergency.receiverReplies || []
      }
    });
  } catch (error) {
    console.error('Web details error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ============ ✅ NEW: GET EMERGENCY DETAILS FOR APP ============
// @desc    Get emergency details for app user
// @route   GET /api/emergency/:id/details
// @access  Private
exports.getEmergencyDetails = async (req, res) => {
  try {
    const { id } = req.params;

    const emergency = await Emergency.findById(id)
      .populate('userId', 'name phone email')
      .populate('notifiedContacts', 'name phone')
      .populate('receiverReplies.contactId', 'name phone');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found'
      });
    }

    // Check if user is the sender or a notified contact
    const isSender = emergency.userId._id.toString() === req.user.id;
    const isContact = emergency.notifiedContacts.some(
      contact => contact._id.toString() === req.user.id
    );

    if (!isSender && !isContact) {
      return res.status(403).json({
        success: false,
        message: 'You are not authorized to view this emergency'
      });
    }

    res.status(200).json({
      success: true,
      emergency,
      role: isSender ? 'sender' : 'receiver'
    });
  } catch (error) {
    console.error('Get details error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// ============ HELPER: Send Emergency Notification ============
async function sendEmergencyNotification({
  contact,
  userName,
  location,
  emergencyId,
}) {
  try {
    const message = {
      notification: {
        title: '⚠️ EMERGENCY ALERT',
        body: `${userName} has activated an SOS alert!`,
      },
      data: {
        type: 'emergency',
        emergencyId: emergencyId.toString(),
        userName: userName,
        latitude: location.latitude.toString(),
        longitude: location.longitude.toString(),
        contactName: contact.name,
      },
      topic: `user_${contact.userId}`,
    };

    await messaging.send(message);
    console.log(`✅ FCM notification sent to ${contact.name}`);
    return true;
  } catch (error) {
    console.error('Error sending FCM notification:', error.message);
    // Don't throw - just log the error
    return false;
  }
}