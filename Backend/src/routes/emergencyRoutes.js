const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  startEmergency,
  updateLocation,
  stopEmergency,
  getEmergencyStatus,
  getHistory,
  addImage,
  replyToEmergency,          // ✅ NEW
  generateWebStream,         // ✅ NEW
  getEmergencyByToken,       // ✅ NEW
  getEmergencyDetails        // ✅ NEW
} = require('../controllers/emergencyController');

// Existing routes
router.post('/start', protect, startEmergency);
router.post('/:id/location', protect, updateLocation);
router.post('/:id/stop', protect, stopEmergency);
router.get('/history', protect, getHistory);
router.get('/:id', protect, getEmergencyStatus);
router.post('/:id/image', protect, addImage);

// ✅ NEW ROUTES
router.post('/:id/reply', protect, replyToEmergency);
router.post('/:id/web-stream', protect, generateWebStream);
router.get('/web/:token', getEmergencyByToken);  // Public - no auth needed
router.get('/:id/details', protect, getEmergencyDetails);

module.exports = router;