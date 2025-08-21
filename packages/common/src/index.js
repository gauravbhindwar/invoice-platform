import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import logger from './logger.js';
import constants from './constants.js';

export async function connectMongo(uri) {
  // allow caller to pass explicit uri, otherwise choose based on NODE_ENV
  const env = process.env.NODE_ENV || 'development';
  const chosen = uri || (env === 'development' ? process.env.MONGO_URI_DEV : process.env.MONGO_URI);
  if (!chosen) throw new Error('MONGO_URI not set (provide MONGO_URI or MONGO_URI_DEV)');
  uri = chosen;
  if ([1, 2].includes(mongoose.connection.readyState)) return mongoose.connection;
  await mongoose.connect(uri, {
    maxPoolSize: 10,
    serverSelectionTimeoutMS: 5000
  });
  logger('✅ Mongo connected');
  return mongoose.connection;
}

export function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    if (!header.startsWith('Bearer '))
      return res.status(401).json({ success: false, message: 'Missing Bearer token' });

    const token = header.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    req.user = {
      id: payload.sub || payload._id || payload.id,
      email: payload.email,
      role: payload.role
    };
    next();
  } catch (err) {
    logger('Auth error:', err.message);
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
}

export function optionalAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    if (!header.startsWith('Bearer ')) {
      req.user = null;
      return next();
    }

    const token = header.slice(7);
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    req.user = {
      id: payload.sub || payload._id || payload.id,
      email: payload.email,
      role: payload.role
    };
    next();
  } catch (err) {
    req.user = null;
    next();
  }
}

export const ok = (res, data, meta) => res.json({ success: true, data, meta });
export const created = (res, data) => res.status(201).json({ success: true, data });
export const fail = (res, status = 400, message = 'Bad Request') =>
  res.status(status).json({ success: false, message });

export function notFound(_req, res) {
  res.status(404).json({ success: false, message: 'Not Found' });
}

export function errorHandler(err, _req, res, _next) {
  logger('❌', err);
  const status = err.status || res.statusCode !== 200 ? res.statusCode : 500;
  res.status(status).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
}

// Validation helpers
export function validateObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

export function toObjectId(id) {
  return new mongoose.Types.ObjectId(id);
}

// Pagination helper
export function buildPagination(req, defaultLimit = 10, maxLimit = 100) {
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(parseInt(req.query.limit) || defaultLimit, maxLimit);
  const skip = (page - 1) * limit;
  
  return { page, limit, skip };
}

export function formatPaginationResponse(data, pagination, total) {
  return {
    data,
    pagination: {
      ...pagination,
      total,
      totalPages: Math.ceil(total / pagination.limit),
      hasNext: pagination.page * pagination.limit < total,
      hasPrev: pagination.page > 1
    }
  };
}

export { logger, constants };
