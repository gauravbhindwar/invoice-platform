import 'dotenv/config';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import { connectMongo, notFound, errorHandler, logger, requireAuth } from '@invoice/common';

export class ServiceFramework {
  constructor(options = {}) {
    this.app = express();
    this.serviceName = options.serviceName || 'unknown-service';
    this.port = options.port || process.env.PORT || 3000;
    this.middlewares = options.middlewares || [];
    this.routes = options.routes || [];
    this.requiresAuth = options.requiresAuth !== false; // default true
    this.requiresMongo = options.requiresMongo !== false; // default true
    this.environment = process.env.NODE_ENV || 'development';
    
    this.setupMiddleware();
  }

  setupMiddleware() {
    // Security & middleware
    this.app.use(helmet({
      contentSecurityPolicy: this.environment === 'production' ? undefined : false
    }));

    // CORS — supports comma-separated origins
    const allowedOrigins = process.env.CORS_ORIGIN?.split(',').map(o => o.trim()) || 
      (this.environment === 'development' ? ['http://localhost:3000', 'http://localhost:5173'] : '*');
    
    this.app.use(cors({
      origin: allowedOrigins,
      credentials: true
    }));

    this.app.use(express.json({ limit: '4mb' }));
    this.app.use(express.urlencoded({ extended: true }));
    this.app.use(compression());

    // Logging — skip in test env
    if (this.environment !== 'test') {
      this.app.use(morgan(this.environment === 'production' ? 'combined' : 'dev'));
    }

    // Request ID middleware for tracing
    this.app.use((req, res, next) => {
      req.requestId = Math.random().toString(36).substr(2, 9);
      res.setHeader('X-Request-ID', req.requestId);
      next();
    });

    // Health check endpoints
    this.app.get('/healthz', (_req, res) => res.json({ 
      status: 'ok', 
      service: this.serviceName,
      environment: this.environment,
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    }));
    
    this.app.get('/health', (_req, res) => res.json({ 
      status: 'ok', 
      service: this.serviceName,
      environment: this.environment,
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    }));

    // Ready check (for Kubernetes)
    this.app.get('/ready', (_req, res) => res.json({ 
      status: 'ready',
      service: this.serviceName 
    }));

    // Add custom middlewares
    this.middlewares.forEach(middleware => {
      this.app.use(middleware);
    });
  }

  addRoutes(path, router, options = {}) {
    if (options.requireAuth !== false && this.requiresAuth) {
      this.app.use(path, requireAuth, router);
    } else {
      this.app.use(path, router);
    }
  }

  addPublicRoutes(path, router) {
    this.app.use(path, router);
  }

  async start() {
    try {
      // Connect to MongoDB if required
      if (this.requiresMongo) {
        const mongoUri = this.getMongoUri();
        if (!mongoUri) {
          throw new Error(`❌ MONGO_URI is not set for ${this.serviceName}`);
        }
        await connectMongo(mongoUri);
      }

      // Add service routes
      this.routes.forEach(({ path, router, options }) => {
        this.addRoutes(path, router, options);
      });

      // Error handling
      this.app.use(notFound);
      this.app.use(errorHandler);

      // Graceful shutdown handling
      this.setupGracefulShutdown();

      // Start server
      const server = this.app.listen(this.port, () => {
        logger(`🚀 ${this.serviceName} listening on port ${this.port} (${this.environment})`);
      });

      // Store server reference for graceful shutdown
      this.server = server;

    } catch (err) {
      logger(`❌ ${this.serviceName} startup error:`, err.message);
      process.exit(1);
    }
  }

  getMongoUri() {
    // Choose URI based on environment
    if (this.environment === 'production') {
      return process.env.MONGO_URI;
    }
    
    // Development: prefer DEV URI, fallback to main URI
    return process.env.MONGO_URI_DEV || process.env.MONGO_URI;
  }

  setupGracefulShutdown() {
    const shutdown = (signal) => {
      logger(`📴 ${this.serviceName} received ${signal}, shutting down gracefully...`);
      
      if (this.server) {
        this.server.close(() => {
          logger(`✅ ${this.serviceName} HTTP server closed`);
          process.exit(0);
        });

        // Force close after 10 seconds
        setTimeout(() => {
          logger(`❌ ${this.serviceName} forced shutdown`);
          process.exit(1);
        }, 10000);
      } else {
        process.exit(0);
      }
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  }

  getApp() {
    return this.app;
  }
}

export { BaseController } from './BaseController.js';
export default ServiceFramework;
