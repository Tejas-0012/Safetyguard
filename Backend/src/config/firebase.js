const admin = require('firebase-admin');

const requiredVars = ['FIREBASE_PROJECT_ID', 'FIREBASE_PRIVATE_KEY', 'FIREBASE_CLIENT_EMAIL'];
const missing = requiredVars.filter((key) => !process.env[key]);
if (missing.length > 0) {
  throw new Error(
    `Missing required Firebase environment variable(s): ${missing.join(', ')}. ` +
    `Check your .env file (these are usually shared separately by whoever set up the Firebase project).`
  );
}

const serviceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const firebaseAuth = admin.auth();
const firestore = admin.firestore();
const messaging = admin.messaging();

module.exports = { admin, firebaseAuth, firestore, messaging };