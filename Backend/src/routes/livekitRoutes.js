const express = require('express');
const router = express.Router();
const { AccessToken } = require('livekit-server-sdk');

// @desc    Generate a LiveKit Token
// @route   GET /api/livekit/token
// @access  Public (but requires knowing the emergencyId)
router.get('/token', async (req, res) => {
  const { emergencyId, participantName, isReceiver } = req.query;

  if (!emergencyId) {
    return res.status(400).json({ error: 'emergencyId is required' });
  }

  try {
    // Create a new token
    const at = new AccessToken(
      process.env.LIVEKIT_API_KEY,
      process.env.LIVEKIT_API_SECRET,
      {
        identity: participantName || 'Anonymous',
        ttl: '2h', // Token is valid for 2 hours
      }
    );

    // Give permissions
    at.addGrant({
      roomJoin: true,
      room: emergencyId, // The room name is the emergency ID
      canPublish: isReceiver !== 'true', // Senders can publish, receivers cannot
      canSubscribe: true,
    });

    const token = await at.toJwt();
    
    // Return the token and the websocket URL to the client
    res.json({ 
        success: true,
        token: token, 
        url: process.env.LIVEKIT_URL 
    });
  } catch (error) {
    console.error('LiveKit Token Error:', error);
    res.status(500).json({ success: false, error: 'Failed to generate token' });
  }
});

module.exports = router;