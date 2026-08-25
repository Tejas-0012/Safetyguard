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

    console.log('📝 ===== START EMERGENCY =====');
    console.log('📝 User ID:', req.user.id);
    console.log('📝 Request Body:', req.body);
    console.log('📝 Latitude:', latitude, 'Type:', typeof latitude);
    console.log('📝 Longitude:', longitude, 'Type:', typeof longitude);

    // ✅ ADD THESE CHECKS
    if (latitude === undefined || longitude === undefined) {
      console.log('❌ Missing latitude or longitude');
      return res.status(400).json({
        success: false,
        message: 'Latitude and longitude are required'
      });
    }

    // ✅ CHECK IF USER ALREADY HAS ACTIVE EMERGENCY
    console.log('🔍 Checking for active emergency...');
    const activeEmergency = await Emergency.findOne({
      userId: req.user.id,
      status: 'active'
    });

    if (activeEmergency) {
      console.log('⚠️ User already has active emergency:', activeEmergency._id);
      return res.status(400).json({
        success: false,
        message: 'You already have an active emergency',
        emergencyId: activeEmergency._id
      });
    }

    console.log('✅ No active emergency found. Creating new...');

    // ✅ CREATE EMERGENCY RECORD
    console.log('📝 Creating emergency record...');
    const emergency = await Emergency.create({
      userId: req.user.id,
      currentLocation: { latitude, longitude },
      locationPoints: [{ latitude, longitude }],
      status: 'active'
    });

    console.log('✅ Emergency created:', emergency._id);

    // ✅ UPDATE USER STATUS
    console.log('📝 Updating user status...');
    await User.findByIdAndUpdate(req.user.id, {
      isEmergencyActive: true,
      emergencyStartTime: new Date()
    });
    console.log('✅ User updated');

    // ✅ GET USER'S CONTACTS
    console.log('📝 Getting user contacts...');
    const user = await User.findById(req.user.id);
    const contacts = await Contact.find({
      _id: { $in: user.contacts }
    });
    console.log(`✅ Found ${contacts.length} contacts`);

    // ✅ SEND NOTIFICATIONS
    console.log('📝 Sending notifications...');
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
        console.log(`✅ Notified: ${contact.name}`);
      } catch (error) {
        console.error(`❌ Failed to notify ${contact.name}:`, error);
      }
    }

    // ✅ UPDATE EMERGENCY WITH NOTIFIED CONTACTS
    emergency.notifiedContacts = notifiedContacts;
    await emergency.save();
    console.log('✅ Emergency updated with notified contacts');

    // ✅ SEND SUCCESS RESPONSE
    console.log('✅ Sending success response');
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
    console.error('❌ ===== START EMERGENCY ERROR =====');
    console.error('❌ Error:', error);
    console.error('❌ Stack:', error.stack);
    
    // ✅ SEND DETAILED ERROR
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

    // Add location point
    emergency.locationPoints.push({ latitude, longitude });
    emergency.currentLocation = { latitude, longitude };
    await emergency.save();

    // Update user location
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

    // Update user status
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
      .populate('notifiedContacts', 'name phone email');

    if (!emergency) {
      return res.status(404).json({
        success: false,
        message: 'Emergency not found',
      });
    }

    // Check if user has access
    if (emergency.userId._id.toString() !== req.user.id) {
      // Check if user is a contact
      const isContact = emergency.notifiedContacts.some(
        (contact) => contact._id.toString() === req.user.id
      );
      if (!isContact) {
        return res.status(403).json({
          success: false,
          message: 'You do not have access to this emergency',
        });
      }
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
    // Send FCM notification
    const message = {
      notification: {
        title: '⚠️ EMERGENCY ALERT',
        body: `${userName} has activated an SOS alert!`,
      },
      data: {
        type: 'emergency',
        emergencyId: emergencyId.toString(),
        userName,
        latitude: location.latitude.toString(),
        longitude: location.longitude.toString(),
        contactName: contact.name,
      },
      topic: `user_${contact.userId}`,
    };

    await messaging.send(message);

    // Store notification in Firestore for history
    const { firestore } = require('../config/firebase');
    await firestore.collection('notifications').add({
      userId: contact.userId,
      emergencyId: emergencyId.toString(),
      type: 'emergency',
      title: '⚠️ EMERGENCY ALERT',
      body: `${userName} has activated an SOS alert!`,
      location: {
        latitude: location.latitude,
        longitude: location.longitude,
      },
      read: false,
      createdAt: new Date().toISOString(),
    });

    return true;
  } catch (error) {
    console.error('Error sending notification:', error);
    throw error;
  }
}