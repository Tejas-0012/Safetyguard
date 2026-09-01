const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const connectDB = require('./src/config/database');

// Import routes
const authRoutes = require('./src/routes/authRoutes');
const userRoutes = require('./src/routes/userRoutes');
const contactRoutes = require('./src/routes/contactRoutes');
const emergencyRoutes = require('./src/routes/emergencyRoutes');
const errorHandler = require('./src/middleware/errorHandler');

const app = express();

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api', limiter);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/emergency', emergencyRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'SafeGuard API is running' });
});

// Global error handler - catches anything that slips past a controller's
// own try/catch (must be registered after all routes)
app.use(errorHandler);

// Connect to MongoDB, then start the server once the connection is ready
// (previously the server started listening immediately, so requests could
// arrive before the DB connection was established).
const PORT = process.env.PORT || 5000;
connectDB().then(() => {
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
});