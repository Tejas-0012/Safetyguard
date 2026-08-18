const mongoose = require('mongoose');

const LocationPointSchema = new mongoose.Schema({
  latitude: { type: Number, required: true },
  longitude: { type: Number, required: true },
  accuracy: { type: Number, default: 0 },
  timestamp: { type: Date, default: Date.now }
});

const EmergencySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  startTime: {
    type: Date,
    default: Date.now
  },
  endTime: {
    type: Date,
    default: null
  },
  status: {
    type: String,
    enum: ['active', 'resolved', 'cancelled'],
    default: 'active'
  },
  locationPoints: [LocationPointSchema],
  currentLocation: {
    latitude: { type: Number, default: 0 },
    longitude: { type: Number, default: 0 }
  },
  notifiedContacts: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Contact'
  }],
  cameraImages: [{
    url: { type: String },
    capturedAt: { type: Date, default: Date.now }
  }],
  isVideoActive: {
    type: Boolean,
    default: false
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Emergency', EmergencySchema);