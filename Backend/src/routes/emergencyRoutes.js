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
  replyToEmergency,
  generateWebStream,
  getEmergencyByToken,
  getEmergencyDetails,
  webReply,
  getReplies,  
} = require('../controllers/emergencyController');

// ============ PROTECTED ROUTES ============
router.post('/start', protect, startEmergency);
router.post('/:id/location', protect, updateLocation);
router.post('/:id/stop', protect, stopEmergency);
router.get('/history', protect, getHistory);
router.get('/:id', protect, getEmergencyStatus);
router.post('/:id/image', protect, addImage);

// ============ RECEIVER ROUTES (protected) ============
router.post('/:id/reply', protect, replyToEmergency);
router.post('/:id/web-stream', protect, generateWebStream);
router.get('/:id/details', protect, getEmergencyDetails);
router.get('/:id/replies', protect, getReplies);
// ============ PUBLIC WEB ROUTES (no auth) ============
router.get('/web/:token', getEmergencyByToken);
router.post('/web/:token/reply', webReply);  

module.exports = router;