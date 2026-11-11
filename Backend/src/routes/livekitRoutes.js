const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { AccessToken } = require('livekit-server-sdk');
const Emergency = require('../models/Emergency');

// @desc    Generate a LiveKit Token
// @route   GET /api/livekit/token
// @access  Protected (Requires Bearer JWT for Victim or receiverToken for Contact)
router.get('/token', async (req, res) => {
  const { emergencyId, participantName, isReceiver, receiverToken } = req.query;

  if (!emergencyId) {
    return res.status(400).json({ success: false, error: 'emergencyId is required' });
  }

  try {
    let isAuthorized = false;
    let canPublishStream = false;

    // Check 1: Victim / App Sender authenticated via Bearer JWT token
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const jwtToken = authHeader.split(' ')[1];
      try {
        const decoded = jwt.verify(jwtToken, process.env.JWT_SECRET);
        const emergency = await Emergency.findById(emergencyId);
        if (emergency && emergency.userId.toString() === decoded.id) {
          isAuthorized = true;
          canPublishStream = isReceiver !== 'true'; // Only verified victim can publish video/audio
        }
      } catch (err) {
        // Invalid or expired JWT
      }
    }

    // Check 2: Receiver authenticated via valid cryptographic receiverToken
    if (!isAuthorized && receiverToken) {
      const emergency = await Emergency.findOne({
        _id: emergencyId,
        'receiverLinks.token': receiverToken,
      });
      if (emergency) {
        isAuthorized = true;
        canPublishStream = false; // Receivers can NEVER publish video/audio
      }
    }

    if (!isAuthorized) {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You do not have permission to access this live stream',
      });
    }

    // Create LiveKit token
    const at = new AccessToken(
      process.env.LIVEKIT_API_KEY,
      process.env.LIVEKIT_API_SECRET,
      {
        identity: participantName || (canPublishStream ? 'Victim' : 'Receiver'),
        ttl: '2h',
      }
    );

    // Give permissions
    at.addGrant({
      roomJoin: true,
      room: emergencyId,
      canPublish: canPublishStream,
      canPublishData: true,
      canSubscribe: true,
    });

    const token = await at.toJwt();

    res.json({
      success: true,
      token: token,
      url: process.env.LIVEKIT_URL,
    });
  } catch (error) {
    console.error('LiveKit Token Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate token' });
  }
});

module.exports = router;
