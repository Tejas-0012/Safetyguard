const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const connectDB = require('./src/config/database');

// Import routes
const authRoutes = require('./src/routes/authRoutes');
const userRoutes = require('./src/routes/userRoutes');
const contactRoutes = require('./src/routes/contactRoutes');
const emergencyRoutes = require('./src/routes/emergencyRoutes');
const errorHandler = require('./src/middleware/errorHandler');

const app = express();

// ============ HELMET WITH CSP DISABLED ============
// Google Maps script is blocked by default CSP.
// We disable CSP for development so external scripts load.
app.use(
  helmet({
    contentSecurityPolicy: false,        // ✅ Allow Google Maps
    crossOriginOpenerPolicy: false,      // ✅ Fix COOP warning
    crossOriginEmbedderPolicy: false,    // ✅ Fix COEP warning
    crossOriginResourcePolicy: false,    // ✅ Allow cross-origin
  })
);

// ============ CORS ============
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  credentials: true,
}));
app.options('*', cors());

// ============ BODY PARSER ============
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ============ STATIC FILES ============
// MUST come before API routes so /assets/* works
app.use(express.static(path.join(__dirname, 'public')));

// ============ RATE LIMITING ============
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,  // ✅ Increased for polling from receiver page
});
app.use('/api', limiter);

// ============ API ROUTES ============
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/emergency', emergencyRoutes);

// ============ HEALTH CHECK ============
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'SafeGuard API is running' });
});

// ============ RECEIVER WEB PAGE ============
app.get('/receiver/:token', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'receiver.html'));
});

// ============ ERROR HANDLER ============
app.use(errorHandler);

// ============ START SERVER ============
const PORT = process.env.PORT || 5000;
connectDB().then(() => {
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📁 Static files: ${path.join(__dirname, 'public')}`);
    console.log(`🔗 Web: http://10.127.210.187:${PORT}`);
  });
});