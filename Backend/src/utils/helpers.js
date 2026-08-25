// ============ FORMAT RESPONSE ============
const formatResponse = (success, message, data = null) => {
  return {
    success,
    message,
    data,
    timestamp: new Date().toISOString(),
  };
};

// ============ GENERATE OTP ============
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// ============ VALIDATE EMAIL ============
const isValidEmail = (email) => {
  const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
  return emailRegex.test(email);
};

// ============ VALIDATE PHONE ============
const isValidPhone = (phone) => {
  const phoneRegex = /^\+?[0-9]{10,14}$/;
  return phoneRegex.test(phone);
};

// ============ CALCULATE DISTANCE (Haversine formula) ============
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

// ============ FORMAT DATE ============
const formatDate = (date) => {
  return new Date(date).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
};

// ============ FORMAT TIME ============
const formatTime = (date) => {
  return new Date(date).toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });
};

// ============ GET CURRENT TIMESTAMP ============
const getCurrentTimestamp = () => {
  return new Date().toISOString();
};

// ============ MASK PHONE ============
const maskPhone = (phone) => {
  if (!phone || phone.length < 10) return phone;
  return phone.slice(0, 3) + '****' + phone.slice(-4);
};

// ============ GENERATE RANDOM TOKEN ============
const generateToken = () => {
  return require('crypto').randomBytes(32).toString('hex');
};

// ============ CHECK IF ARRAY IS EMPTY ============
const isEmpty = (arr) => {
  return !arr || arr.length === 0;
};

// ============ GROUP BY KEY ============
const groupBy = (arr, key) => {
  return arr.reduce((acc, item) => {
    const group = item[key];
    if (!acc[group]) acc[group] = [];
    acc[group].push(item);
    return acc;
  }, {});
};

// ============ SLEEP FUNCTION ============
const sleep = (ms) => {
  return new Promise(resolve => setTimeout(resolve, ms));
};

// ============ GET PAGINATION ============
const getPagination = (page = 1, limit = 10) => {
  const pageNum = Math.max(1, parseInt(page));
  const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
  const skip = (pageNum - 1) * limitNum;
  return { page: pageNum, limit: limitNum, skip };
};

// ============ GENERATE SLUG ============
const generateSlug = (text) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
};

// ============ TRUNCATE TEXT ============
const truncateText = (text, maxLength = 100) => {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
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
  sleep,
  getPagination,
  generateSlug,
  truncateText,
};