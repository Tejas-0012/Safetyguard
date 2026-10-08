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
} = require('../controllers/emergencyController');

// ============ PUBLIC ROUTES (no auth) ============
router.get('/receiver/:token', getReceiverByToken);
router.post('/receiver/:token/location', updateReceiverLocation);
router.post('/receiver/:token/stop-sharing', stopReceiverSharing);

router.get('/web/:token', getEmergencyByToken);
router.post('/web/:token/reply', webReply);

// ============ PROTECTED ROUTES ============
router.get('/active', protect, getActiveEmergency);
router.post('/start', protect, startEmergency);
router.post('/:id/location', protect, updateLocation);
router.post('/:id/stop', protect, stopEmergency);
router.get('/history', protect, getHistory);
router.get('/:id', protect, getEmergencyStatus);
router.post('/:id/image', protect, addImage);
router.post('/:id/reply', protect, replyToEmergency);
router.post('/:id/web-stream', protect, generateWebStream);
router.get('/:id/details', protect, getEmergencyDetails);

module.exports = router;