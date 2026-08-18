const express = require('express');
const router = express.Router();
const { register, login, verifyFirebase } = require('../controllers/authController');

router.post('/register', register);
router.post('/login', login);
router.post('/verify-firebase', verifyFirebase);

module.exports = router;