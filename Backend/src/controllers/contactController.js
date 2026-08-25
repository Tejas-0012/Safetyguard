const Contact = require('../models/Contact');
const User = require('../models/User');

// ============ ADD CONTACT ============
// @desc    Add emergency contact
// @route   POST /api/contacts
// @access  Private
exports.addContact = async (req, res) => {
  try {
    const { name, phone, email, relation } = req.body;

    // Check if contact already exists
    const existingContact = await Contact.findOne({
      userId: req.user.id,
      phone,
    });

    if (existingContact) {
      return res.status(400).json({
        success: false,
        message: 'Contact already exists with this phone number',
      });
    }

    const contact = await Contact.create({
      userId: req.user.id,
      name,
      phone,
      email,
      relation,
    });

    // Add contact to user's contacts list
    await User.findByIdAndUpdate(req.user.id, {
      $push: { contacts: contact._id },
    });

    res.status(201).json({
      success: true,
      contact,
    });
  } catch (error) {
    console.error('Add contact error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error adding contact',
    });
  }
};

// ============ GET ALL CONTACTS ============
// @desc    Get all emergency contacts
// @route   GET /api/contacts
// @access  Private
exports.getContacts = async (req, res) => {
  try {
    const contacts = await Contact.find({ userId: req.user.id }).sort({
      createdAt: -1,
    });

    res.status(200).json({
      success: true,
      contacts,
    });
  } catch (error) {
    console.error('Get contacts error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error getting contacts',
    });
  }
};

// ============ UPDATE CONTACT ============
// @desc    Update emergency contact
// @route   PUT /api/contacts/:id
// @access  Private
exports.updateContact = async (req, res) => {
  try {
    const { name, phone, email, relation } = req.body;

    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found',
      });
    }

    // Check if phone is taken by another contact
    if (phone) {
      const existingContact = await Contact.findOne({
        userId: req.user.id,
        phone,
        _id: { $ne: req.params.id },
      });
      if (existingContact) {
        return res.status(400).json({
          success: false,
          message: 'Another contact has this phone number',
        });
      }
    }

    if (name) contact.name = name;
    if (phone) contact.phone = phone;
    if (email) contact.email = email;
    if (relation) contact.relation = relation;

    await contact.save();

    res.status(200).json({
      success: true,
      contact,
    });
  } catch (error) {
    console.error('Update contact error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error updating contact',
    });
  }
};

// ============ DELETE CONTACT ============
// @desc    Delete emergency contact
// @route   DELETE /api/contacts/:id
// @access  Private
exports.deleteContact = async (req, res) => {
  try {
    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found',
      });
    }

    await contact.deleteOne();

    // Remove from user's contacts list
    await User.findByIdAndUpdate(req.user.id, {
      $pull: { contacts: req.params.id },
    });

    res.status(200).json({
      success: true,
      message: 'Contact deleted successfully',
    });
  } catch (error) {
    console.error('Delete contact error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Server error deleting contact',
    });
  }
};