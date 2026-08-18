// Format response
const formatResponse = (success, message, data = null) => {
  return {
    success,
    message,
    data
  };
};

// Generate OTP
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Validate email
const isValidEmail = (email) => {
  const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
  return emailRegex.test(email);
};

// Validate phone
const isValidPhone = (phone) => {
  const phoneRegex = /^\+?[0-9]{10,14}$/;
  return phoneRegex.test(phone);
};

// Calculate distance between two coordinates (Haversine formula)
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
};

// Format date
const formatDate = (date) => {
  return new Date(date).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  });
};

// Format time
const formatTime = (date) => {
  return new Date(date).toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
};

// Get current timestamp
const getCurrentTimestamp = () => {
  return new Date().toISOString();
};

// Mask sensitive data
const maskPhone = (phone) => {
  if (!phone || phone.length < 10) return phone;
  return phone.slice(0, 3) + '****' + phone.slice(-4);
};

// Generate random token
const generateToken = () => {
  return require('crypto').randomBytes(32).toString('hex');
};

// Check if array is empty
const isEmpty = (arr) => {
  return !arr || arr.length === 0;
};

// Group array by key
const groupBy = (arr, key) => {
  return arr.reduce((acc, item) => {
    const group = item[key];
    if (!acc[group]) acc[group] = [];
    acc[group].push(item);
    return acc;
  }, {});
};

// Sleep function
const sleep = (ms) => {
  return new Promise(resolve => setTimeout(resolve, ms));
};

module.exports = {
  formatResponse,
  generateOTP,
  isValidEmail,
  isValidPhone,
  calculateDistance,
  formatDate,
  formatTime,
  getCurrentTimestamp,
  maskPhone,
  generateToken,
  isEmpty,
  groupBy,
  sleep
};