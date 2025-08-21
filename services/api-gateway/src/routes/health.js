import express from 'express';
import { services } from '../config/services.js';

// Simple logger
const logger = {
  info: (message) => console.log(`[INFO] ${new Date().toISOString()} - ${message}`),
  error: (message, error) => console.error(`[ERROR] ${new Date().toISOString()} - ${message}`, error || ''),
  warn: (message) => console.warn(`[WARN] ${new Date().toISOString()} - ${message}`)
};

const router = express.Router();

/**
 * @swagger
 * /health:
 *   get:
 *     tags: [Health]
 *     summary: Gateway health check
 *     description: Check the health status of the API Gateway
 *     responses:
 *       200:
 *         description: Gateway is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   example: healthy
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *                 uptime:
 *                   type: number
 *                   description: Uptime in seconds
 *                 version:
 *                   type: string
 *                   example: 1.0.0
 *                 environment:
 *                   type: string
 *                   example: development
 */
router.get('/', (req, res) => {
  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    gateway: {
      name: 'Invoice Platform API Gateway',
      memory: process.memoryUsage(),
      pid: process.pid
    }
  };

  res.json(healthData);
});

/**
 * @swagger
 * /health/services:
 *   get:
 *     tags: [Health]
 *     summary: Check all services health
 *     description: Check the health status of all configured microservices
 *     responses:
 *       200:
 *         description: Service health status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 overall:
 *                   type: string
 *                   enum: [healthy, degraded, unhealthy]
 *                 services:
 *                   type: object
 *                   additionalProperties:
 *                     type: object
 *                     properties:
 *                       status:
 *                         type: string
 *                         enum: [healthy, unhealthy, timeout]
 *                       responseTime:
 *                         type: number
 *                       lastChecked:
 *                         type: string
 *                         format: date-time
 *                       error:
 *                         type: string
 */
router.get('/services', async (req, res) => {
  const serviceHealthPromises = Object.entries(services).map(async ([key, service]) => {
    const startTime = Date.now();
    
    try {
      const healthUrl = `${service.url}${service.healthCheck}`;
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout
      
      const response = await fetch(healthUrl, {
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          'X-Health-Check': 'true'
        }
      });
      
      clearTimeout(timeoutId);
      const responseTime = Date.now() - startTime;
      
      if (response.ok) {
        const healthData = await response.json();
        return {
          [key]: {
            status: 'healthy',
            responseTime,
            lastChecked: new Date().toISOString(),
            data: healthData
          }
        };
      } else {
        return {
          [key]: {
            status: 'unhealthy',
            responseTime,
            lastChecked: new Date().toISOString(),
            error: `HTTP ${response.status}: ${response.statusText}`
          }
        };
      }
    } catch (error) {
      const responseTime = Date.now() - startTime;
      
      return {
        [key]: {
          status: error.name === 'AbortError' ? 'timeout' : 'unhealthy',
          responseTime,
          lastChecked: new Date().toISOString(),
          error: error.message
        }
      };
    }
  });

  try {
    const serviceHealthResults = await Promise.all(serviceHealthPromises);
    const serviceHealth = serviceHealthResults.reduce((acc, result) => ({ ...acc, ...result }), {});
    
    // Determine overall health
    const healthyCount = Object.values(serviceHealth).filter(s => s.status === 'healthy').length;
    const totalCount = Object.keys(serviceHealth).length;
    
    let overallStatus;
    if (healthyCount === totalCount) {
      overallStatus = 'healthy';
    } else if (healthyCount > totalCount / 2) {
      overallStatus = 'degraded';
    } else {
      overallStatus = 'unhealthy';
    }

    const result = {
      overall: overallStatus,
      timestamp: new Date().toISOString(),
      summary: {
        total: totalCount,
        healthy: healthyCount,
        unhealthy: totalCount - healthyCount
      },
      services: serviceHealth
    };

    res.json(result);
  } catch (error) {
    logger.error('Error checking service health:', error);
    res.status(500).json({
      overall: 'error',
      timestamp: new Date().toISOString(),
      error: 'Failed to check service health',
      message: error.message
    });
  }
});

/**
 * @swagger
 * /health/services/{serviceName}:
 *   get:
 *     tags: [Health]
 *     summary: Check specific service health
 *     description: Check the health status of a specific microservice
 *     parameters:
 *       - in: path
 *         name: serviceName
 *         required: true
 *         schema:
 *           type: string
 *         description: Name of the service to check
 *         example: auth
 *     responses:
 *       200:
 *         description: Service health status
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthCheck'
 *       404:
 *         description: Service not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/services/:serviceName', async (req, res) => {
  const { serviceName } = req.params;
  const service = services[serviceName];

  if (!service) {
    return res.status(404).json({
      error: 'Service not found',
      message: `Service '${serviceName}' is not configured`,
      availableServices: Object.keys(services),
      timestamp: new Date().toISOString()
    });
  }

  const startTime = Date.now();

  try {
    const healthUrl = `${service.url}${service.healthCheck}`;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);
    
    const response = await fetch(healthUrl, {
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'X-Health-Check': 'true'
      }
    });
    
    clearTimeout(timeoutId);
    const responseTime = Date.now() - startTime;
    
    if (response.ok) {
      const healthData = await response.json();
      res.json({
        service: serviceName,
        status: 'healthy',
        responseTime,
        lastChecked: new Date().toISOString(),
        data: healthData
      });
    } else {
      res.status(response.status).json({
        service: serviceName,
        status: 'unhealthy',
        responseTime,
        lastChecked: new Date().toISOString(),
        error: `HTTP ${response.status}: ${response.statusText}`
      });
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    
    res.status(503).json({
      service: serviceName,
      status: error.name === 'AbortError' ? 'timeout' : 'unhealthy',
      responseTime,
      lastChecked: new Date().toISOString(),
      error: error.message
    });
  }
});

export default router;
