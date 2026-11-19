const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { AccessToken } = require('livekit-server-sdk');
const Emergency = require('../models/Emergency');

// @desc    Generate a LiveKit Token
// @route   GET /api/livekit/token
// @access  Protected (Requires Bearer JWT for Victim or receiverToken for Contact)
router.get('/token', async (req, res) => {
  let { emergencyId, participantName, isReceiver, receiverToken } = req.query;

  if (!emergencyId && !receiverToken) {
    return res.status(400).json({ success: false, error: 'emergencyId or receiverToken is required' });
  }

  try {
    let isAuthorized = false;
    let canPublishStream = false;

    // Check 1: Victim / App Sender authenticated via Bearer JWT token (header or query)
    let jwtToken = req.query.token;
    const authHeader = req.headers.authorization;
    if (authHeader) {
      jwtToken = authHeader.replace(/^Bearer\s+/i, '').trim();
    }

    if (jwtToken && emergencyId) {
      try {
        const decoded = jwt.verify(jwtToken, process.env.JWT_SECRET);
        const emergency = await Emergency.findById(emergencyId);
        if (emergency && emergency.userId.toString() === decoded.id) {
          isAuthorized = true;
          canPublishStream = isReceiver !== 'true'; // Only verified victim can publish video/audio
        }
      } catch (err) {
        console.warn('LiveKit JWT verify error:', err.message);
      }
    }

    // Check 2: Receiver authenticated via valid cryptographic receiverToken
    if (!isAuthorized && receiverToken) {
      const orConditions = [
        { 'receiverLinks.token': receiverToken },
        { webStreamToken: receiverToken },
      ];
      const query = { $or: orConditions };
      if (emergencyId && mongoose.Types.ObjectId.isValid(emergencyId)) {
        query._id = emergencyId;
      }

      const emergency = await Emergency.findOne(query);
      if (emergency) {
        isAuthorized = true;
        canPublishStream = false; // Receivers can NEVER publish video/audio
        emergencyId = emergency._id.toString(); // Enforce verified emergency ID room
      }
    }

    if (!isAuthorized) {
      console.warn(`LiveKit Auth Denied for emergencyId: ${emergencyId}, receiverToken: ${receiverToken ? receiverToken.substring(0, 6) + '...' : 'none'}`);
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You do not have permission to access this live stream',
      });
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;
    const livekitUrl = process.env.LIVEKIT_URL;

    if (!apiKey || !apiSecret || !livekitUrl) {
      console.error('LiveKit credentials missing in environment variables (LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL)');
      return res.status(500).json({ success: false, error: 'LiveKit server configuration missing on server' });
    }

    // Create LiveKit token
    const at = new AccessToken(
      apiKey,
      apiSecret,
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
      url: livekitUrl,
    });
  } catch (error) {
    console.error('LiveKit Token Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate token: ' + error.message });
  }
});

module.exports = router;
