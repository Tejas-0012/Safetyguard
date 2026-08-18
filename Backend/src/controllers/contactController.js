const Contact = require('../models/Contact');
const User = require('../models/User');

// @desc    Add Emergency Contact
// @route   POST /api/contacts
// @access  Private
exports.addContact = async (req, res) => {
  try {
    const { name, phone, email, relation } = req.body;

    const contact = await Contact.create({
      userId: req.user.id,
      name,
      phone,
      email,
      relation
    });

    // Add contact to user's contacts list
    await User.findByIdAndUpdate(req.user.id, {
      $push: { contacts: contact._id }
    });

    res.status(201).json({
      success: true,
      contact
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Get All Contacts
// @route   GET /api/contacts
// @access  Private
exports.getContacts = async (req, res) => {
  try {
    const contacts = await Contact.find({ userId: req.user.id });

    res.status(200).json({
      success: true,
      contacts
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Update Contact
// @route   PUT /api/contacts/:id
// @access  Private
exports.updateContact = async (req, res) => {
  try {
    const { name, phone, email, relation } = req.body;

    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user.id
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found'
      });
    }

    if (name) contact.name = name;
    if (phone) contact.phone = phone;
    if (email) contact.email = email;
    if (relation) contact.relation = relation;

    await contact.save();

    res.status(200).json({
      success: true,
      contact
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc    Delete Contact
// @route   DELETE /api/contacts/:id
// @access  Private
exports.deleteContact = async (req, res) => {
  try {
    const contact = await Contact.findOne({
      _id: req.params.id,
      userId: req.user.id
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found'
      });
    }

    await contact.deleteOne();

    // Remove from user's contacts list
    await User.findByIdAndUpdate(req.user.id, {
      $pull: { contacts: req.params.id }
    });

    res.status(200).json({
      success: true,
      message: 'Contact deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};