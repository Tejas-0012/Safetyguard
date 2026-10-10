const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

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
  getReplies,
  uploadAudioChunk,
  uploadEmergencyImage,
} = require('../controllers/emergencyController');

// ============ MULTER CONFIG FOR AUDIO UPLOADS ============
const audioStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../public/uploads/audio');
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const emergencyId = req.params.id;
    const chunkIndex = req.body.chunkIndex || '0';
    cb(
      null,
      `emergency_${emergencyId}_chunk_${chunkIndex}_${Date.now()}.m4a`
    );
  },
});

const audioUpload = multer({
  storage: audioStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB max
});

// ✅ Multer for images
const imageStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../public/uploads/images');
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const emergencyId = req.params.id;
    const camera = req.body.camera || 'unknown';
    const idx = req.body.captureIndex || '0';
    cb(null, `emergency_${emergencyId}_${camera}_${idx}_${Date.now()}.jpg`);
  },
});

const imageUpload = multer({
  storage: imageStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
});

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
router.post('/:id/audio', protect, audioUpload.single('audio'), uploadAudioChunk);
router.post('/:id/stop', protect, stopEmergency);
router.post('/:id/image', protect, addImage);
router.post('/:id/reply', protect, replyToEmergency);
router.post('/:id/web-stream', protect, generateWebStream);
router.get('/:id/details', protect, getEmergencyDetails);
router.get('/:id/replies', protect, getReplies);
router.post(
  '/:id/auto-image',
  protect,
  imageUpload.single('image'),
  uploadEmergencyImage
);

// ============ GENERIC ROUTE (must be LAST) ============
router.get('/:id', protect, getEmergencyStatus);

module.exports = router;