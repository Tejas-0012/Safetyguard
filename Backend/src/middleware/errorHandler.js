const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  // Mongoose duplicate key
  if (err.code === 11000) {
    const field = Object.keys(err.keyPattern)[0];
    const message = `${field} already exists`;
    error = { message, status: 400 };
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const message = Object.values(err.errors).map(val => val.message);
    error = { message: message.join(', '), status: 400 };
  }

  // JWT error
  if (err.name === 'JsonWebTokenError') {
    error = { message: 'Invalid token', status: 401 };
  }

  res.status(error.status || 500).json({
    success: false,
    message: error.message || 'Server Error'
  });
};

module.exports = errorHandler;