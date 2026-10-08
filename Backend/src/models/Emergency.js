const mongoose = require('mongoose');

// ============ SUB-SCHEMAS ============

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
    default: 'Contact',
  },
  message: {
    type: String,
    required: true,
  },
  repliedAt: {
    type: Date,
    default: Date.now,
  },
});

// ✅ Sub-schema for receiver links (one per emergency contact)
const ReceiverLinkSchema = new mongoose.Schema({
  contactId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Contact',
    required: true,
  },
  contactName: {
    type: String,
    required: true,
  },
  contactPhone: {
    type: String,
    required: true,
  },
  token: {
    type: String,
    required: true,
  },
  location: {
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null },
    accuracy: { type: Number, default: 0 },
  },
  lastUpdated: {
    type: Date,
    default: null,
  },
  linkOpened: {
    type: Boolean,
    default: false,
  },
  isSharingLocation: {
    type: Boolean,
    default: false,
  },
}, { _id: false });

// ============ MAIN SCHEMA ============

const EmergencySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User ID is required'],
    },
    startTime: { type: Date, default: Date.now },
    endTime: { type: Date, default: null },
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
      { type: mongoose.Schema.Types.ObjectId, ref: 'Contact' },
    ],
    cameraImages: [EmergencyImageSchema],
    isVideoActive: { type: Boolean, default: false },
    receiverReplies: [ReceiverReplySchema],
    isWebStreamActive: { type: Boolean, default: false },
    webStreamToken: { type: String, default: '' },
    receiverLinks: [ReceiverLinkSchema],
  },
  { timestamps: true }
);

// ============ INDEXES ============
EmergencySchema.index({ userId: 1, status: 1 });
EmergencySchema.index({ startTime: -1 });
EmergencySchema.index({ webStreamToken: 1 });
EmergencySchema.index({ 'receiverLinks.token': 1 });

// ============ VIRTUALS ============
EmergencySchema.virtual('duration').get(function () {
  if (!this.endTime) return null;
  return this.endTime - this.startTime;
});

EmergencySchema.set('toJSON', { virtuals: true });
EmergencySchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Emergency', EmergencySchema);