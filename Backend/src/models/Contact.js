const mongoose = require('mongoose');

const ContactSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User ID is required'],
    },
    name: {
      type: String,
      required: [true, 'Please provide a contact name'],
      trim: true,
      maxlength: [50, 'Name cannot be more than 50 characters'],
    },
    phone: {
      type: String,
      required: [true, 'Please provide a phone number'],
      trim: true,
      match: [/^\+?[0-9]{10,14}$/, 'Please provide a valid phone number'],
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      match: [
        /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/,
        'Please provide a valid email',
      ],
    },
    relation: {
      type: String,
      enum: ['Parent', 'Spouse', 'Sibling', 'Friend', 'Other'],
      default: 'Other',
    },
    isNotified: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Index for faster queries
ContactSchema.index({ userId: 1 });

module.exports = mongoose.model('Contact', ContactSchema);