const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  startEmergency,
  updateLocation,
  stopEmergency,
  getEmergencyStatus,
  getHistory,
  addImage
} = require('../controllers/emergencyController');

router.post('/start', protect, startEmergency);
router.post('/:id/location', protect, updateLocation);
router.post('/:id/stop', protect, stopEmergency);
router.get('/history', protect, getHistory);
router.get('/:id', protect, getEmergencyStatus);
router.post('/:id/image', protect, addImage);

module.exports = router;