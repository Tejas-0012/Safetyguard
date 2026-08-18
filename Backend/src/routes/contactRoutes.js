const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { addContact, getContacts, updateContact, deleteContact } = require('../controllers/contactController');

router.post('/', protect, addContact);
router.get('/', protect, getContacts);
router.put('/:id', protect, updateContact);
router.delete('/:id', protect, deleteContact);

module.exports = router;