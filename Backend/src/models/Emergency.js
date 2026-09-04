const mongoose = require('mongoose');

// Sub-schema for location points
const LocationPointSchema = new mongoose.Schema({
  latitude: {
    type: Number,
    required: [true, 'Latitude is required'],
    min: -90,
    max: 90,
  },
  longitude: {
    type: Number,
    required: [true, 'Longitude is required'],
    min: -180,
    max: 180,
  },
  accuracy: {
    type: Number,
    default: 0,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

// Sub-schema for camera images
const EmergencyImageSchema = new mongoose.Schema({
  url: {
    type: String,
    required: [true, 'Image URL is required'],
  },
  capturedAt: {
    type: Date,
    default: Date.now,
  },
});

// ✅ Sub-schema for receiver replies
const ReceiverReplySchema = new mongoose.Schema({
  contactId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Contact',
  },
  contactName: {
    type: String,
    default: '',
  },
  message: {
    type: String,
    required: [true, 'Reply message is required'],
  },
  repliedAt: {
    type: Date,
    default: Date.now,
  },
});

const EmergencySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User ID is required'],
    },
    startTime: {
      type: Date,
      default: Date.now,
    },
    endTime: {
      type: Date,
      default: null,
    },
    status: {
      type: String,
      enum: ['active', 'resolved', 'cancelled'],
      default: 'active',
    },
    locationPoints: [LocationPointSchema],
    currentLocation: {
      latitude: { type: Number, default: 0 },
      longitude: { type: Number, default: 0 },
    },
    notifiedContacts: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Contact',
      },
    ],
    cameraImages: [EmergencyImageSchema],
    isVideoActive: {
      type: Boolean,
      default: false,
    },
    // ✅ NEW FIELDS
    receiverReplies: [ReceiverReplySchema],
    isWebStreamActive: {
      type: Boolean,
      default: false,
    },
    webStreamToken: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for better performance
EmergencySchema.index({ userId: 1, status: 1 });
EmergencySchema.index({ startTime: -1 });
EmergencySchema.index({ webStreamToken: 1 });

// Virtual for duration
EmergencySchema.virtual('duration').get(function () {
  if (!this.endTime) return null;
  return this.endTime - this.startTime;
});

// Ensure virtuals are included in JSON output
EmergencySchema.set('toJSON', { virtuals: true });
EmergencySchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Emergency', EmergencySchema);