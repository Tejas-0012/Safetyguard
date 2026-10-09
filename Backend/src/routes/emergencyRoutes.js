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
  getActiveEmergency,
  getReceiverByToken,
  updateReceiverLocation,
  stopReceiverSharing,
  replyFromReceiver,
  getReplies,  // ✅ ADD THIS IMPORT
} = require('../controllers/emergencyController');

// ============ PUBLIC ROUTES (no auth) ============
router.get('/receiver/:token', getReceiverByToken);
router.post('/receiver/:token/location', updateReceiverLocation);
router.post('/receiver/:token/stop-sharing', stopReceiverSharing);
router.post('/receiver/:token/reply', replyFromReceiver);

router.get('/web/:token', getEmergencyByToken);
router.post('/web/:token/reply', webReply);

// ============ SPECIFIC PROTECTED ROUTES ============
router.get('/active', protect, getActiveEmergency);
router.get('/history', protect, getHistory);
router.post('/start', protect, startEmergency);

// ============ /:id SUB-ROUTES (must come BEFORE generic /:id) ============
router.post('/:id/location', protect, updateLocation);
router.post('/:id/stop', protect, stopEmergency);
router.post('/:id/image', protect, addImage);
router.post('/:id/reply', protect, replyToEmergency);
router.post('/:id/web-stream', protect, generateWebStream);
router.get('/:id/details', protect, getEmergencyDetails);
router.get('/:id/replies', protect, getReplies);   // ✅ ADD THIS ROUTE

// ============ GENERIC ROUTE (must be LAST) ============
router.get('/:id', protect, getEmergencyStatus);

module.exports = router;