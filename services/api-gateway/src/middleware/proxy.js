import { createProxyMiddleware } from 'http-proxy-middleware';
import { logger } from '@invoice/common';

export const createServiceProxy = (service) => {
  return createProxyMiddleware({
    target: service.url,
    changeOrigin: true,
    pathRewrite: {
      [`^${service.prefix}`]: service.target
    },
    onError: (err, req, res) => {
      logger(`Proxy error for ${service.name}: ${err.message}`);
      res.status(503).json({
        success: false,
        message: `${service.name} is currently unavailable`,
        error: process.env.NODE_ENV === 'development' ? err.message : 'Service unavailable'
      });
    },
    onProxyReq: (proxyReq, req, res) => {
      logger(`Proxying ${req.method} ${req.originalUrl} to ${service.name}`);
    },
    onProxyRes: (proxyRes, req, res) => {
      logger(`Response from ${service.name}: ${proxyRes.statusCode}`);
    }
  });
};

export const rateLimitMiddleware = (req, res, next) => {
  // Basic rate limiting placeholder
  // In production, use a proper rate limiting library like express-rate-limit
  next();
};

export const authMiddleware = (req, res, next) => {
  // Skip auth for health checks and public endpoints
  if (req.path.includes('/healthz') || req.path.includes('/docs') || req.path.includes('/api-docs')) {
    return next();
  }

  // Skip auth for login/register endpoints
  if (req.path.includes('/auth/login') || req.path.includes('/auth/register')) {
    return next();
  }

  // Basic auth validation placeholder
  // In production, implement proper JWT validation
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({
      success: false,
      message: 'Authorization header required'
    });
  }

  // For now, just pass through
  // In production, validate JWT token here
  next();
};
