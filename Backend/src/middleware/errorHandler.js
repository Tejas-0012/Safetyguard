const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  // Log error
  console.error('Error:', err);

  // Mongoose duplicate key error
  if (err.code === 11000) {
    const field = Object.keys(err.keyPattern)[0];
    const message = `${field} already exists`;
    error = { message, status: 400 };
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map((val) => val.message);
    error = { message: messages.join(', '), status: 400 };
  }

  // Mongoose CastError (invalid ObjectId)
  if (err.name === 'CastError') {
    error = { message: 'Invalid ID format', status: 400 };
  }

  // JWT error
  if (err.name === 'JsonWebTokenError') {
    error = { message: 'Invalid token', status: 401 };
  }

  // Token expired
  if (err.name === 'TokenExpiredError') {
    error = { message: 'Token expired', status: 401 };
  }

  const statusCode = error.status || 500;
  const message = error.message || 'Server Error';

  res.status(statusCode).json({
    success: false,
    message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });
};

module.exports = errorHandler;