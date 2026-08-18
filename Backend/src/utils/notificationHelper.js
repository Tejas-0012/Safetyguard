const admin = require('firebase-admin');


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
    await admin.firestore().collection('pending_sms').add({
      contactId: contact.id,
      contactPhone: contact.phone,
      contactName: contact.name,
      userName: userName,
      latitude: location.latitude,
      longitude: location.longitude,
      emergencyId: emergencyId,
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (error) {
    console.error('Error sending notification:', error);
    return false;
  }
};