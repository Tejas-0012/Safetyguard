const admin = require('firebase-admin');
const twilio = require('twilio');

// Initialize Twilio
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

// Send emergency alert to contact
exports.sendEmergencyAlert = async ({ contact, userName, location, emergencyId }) => {
  try {
    // Send Firebase Cloud Message
    const message = {
      notification: {
        title: '⚠️ EMERGENCY ALERT',
        body: `${userName} has activated an SOS alert!`,
      },
      data: {
        type: 'emergency',
        emergencyId: emergencyId.toString(),
        userName,
        latitude: location.latitude.toString(),
        longitude: location.longitude.toString(),
        contactName: contact.name,
      },
      topic: `user_${contact.userId}`,
    };

    await admin.messaging().send(message);

    // Send SMS (if Twilio configured)
    if (process.env.TWILIO_ACCOUNT_SID) {
      const smsMessage = `
🚨 EMERGENCY ALERT

${userName} has activated an SOS alert.

Current Location:
https://www.google.com/maps?q=${location.latitude},${location.longitude}

Please check the app for live updates.
      `;

      await twilioClient.messages.create({
        body: smsMessage,
        from: process.env.TWILIO_PHONE_NUMBER,
        to: contact.phone
      });
    }

    return true;
  } catch (error) {
    console.error('Error sending notification:', error);
    return false;
  }
};