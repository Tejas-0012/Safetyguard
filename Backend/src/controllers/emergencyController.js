const Emergency = require('../models/Emergency');
const User = require('../models/User');
const Contact = require('../models/Contact');
const { messaging } = require('../config/firebase');

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
      .populate('notifiedContacts', 'name phone email userId');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found',
      });
    }

    // Access allowed if: the requester owns this emergency, OR the
    // requester is one of the notified contacts *and* that contact record
    // is linked to the requester's own account (contact.userId is the
    // contact-list owner's id, not the contact's own account - so this only
    // grants access when the contact itself has a SafeGuard account whose
    // id happens to match, which most contacts won't have. This mirrors
    // the ownership check used everywhere else; a full "contacts who are
    // also users" linkage isn't implemented, so in practice only the
    // emergency's owner can view it right now.)
    const isOwner = emergency.userId._id.toString() === req.user.id;
    if (!isOwner) {
      return res.status(403).json({
        success: false,
        message: 'You do not have access to this emergency',
      });
    }

    res.status(200).json({
      success: true,
      emergency,
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
    return true;
  } catch (error) {
    // NOTE: this will fail for every contact right now, since nothing in
    // this codebase ever calls FirebaseMessaging.subscribeToTopic() on the
    // client for a `user_<contactUserId>` topic - so `messaging.send()`
    // is sending to a topic with zero subscribers. It won't throw (FCM
    // topic sends succeed even with no subscribers), it just silently
    // reaches nobody. SMS (via SmsService on the device) is your real
    // notification path right now, not this.
    console.error('Error sending FCM notification:', error.message);
    throw error;
  }
}