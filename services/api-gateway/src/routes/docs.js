import express from 'express';
import swaggerUi from 'swagger-ui-express';
import { services } from '../config/services.js';
import specs, { generateServiceDocs } from '../config/swagger.js';

// Simple logger
const logger = {
  info: (message) => console.log(`[INFO] ${new Date().toISOString()} - ${message}`),
  error: (message, error) => console.error(`[ERROR] ${new Date().toISOString()} - ${message}`, error || ''),
  warn: (message) => console.warn(`[WARN] ${new Date().toISOString()} - ${message}`)
};

const router = express.Router();

/**
 * @swagger
 * /docs:
 *   get:
 *     tags: [Documentation]
 *     summary: API Documentation Hub
 *     description: Main documentation page with links to all service docs
 *     responses:
 *       200:
 *         description: Documentation hub page
 *         content:
 *           text/html:
 *             schema:
 *               type: string
 */
router.get('/', (req, res) => {
  const serviceDocs = generateServiceDocs();
  
  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Invoice Platform API Documentation</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f8f9fa;
            }
            .header {
                text-align: center;
                margin-bottom: 40px;
                padding: 40px 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border-radius: 10px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            }
            .header h1 {
                margin: 0;
                font-size: 2.5em;
                font-weight: 300;
            }
            .header p {
                margin: 10px 0 0 0;
                font-size: 1.2em;
                opacity: 0.9;
            }
            .services-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-bottom: 40px;
            }
            .service-card {
                background: white;
                padding: 25px;
                border-radius: 10px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                transition: transform 0.2s, box-shadow 0.2s;
                border-left: 4px solid #667eea;
            }
            .service-card:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
            }
            .service-card h3 {
                margin: 0 0 10px 0;
                color: #333;
                font-size: 1.3em;
            }
            .service-card p {
                margin: 0 0 15px 0;
                color: #666;
            }
            .service-links {
                display: flex;
                gap: 10px;
                flex-wrap: wrap;
            }
            .btn {
                display: inline-block;
                padding: 8px 16px;
                background-color: #667eea;
                color: white;
                text-decoration: none;
                border-radius: 5px;
                font-size: 0.9em;
                transition: background-color 0.2s;
            }
            .btn:hover {
                background-color: #5a6fd8;
            }
            .btn-secondary {
                background-color: #6c757d;
            }
            .btn-secondary:hover {
                background-color: #5a6268;
            }
            .main-docs {
                text-align: center;
                margin-bottom: 40px;
                padding: 30px;
                background: white;
                border-radius: 10px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            }
            .endpoint-info {
                background: white;
                padding: 20px;
                border-radius: 10px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                margin-bottom: 20px;
            }
            .endpoint-info h3 {
                margin: 0 0 15px 0;
                color: #333;
            }
            .endpoint-list {
                list-style: none;
                padding: 0;
            }
            .endpoint-list li {
                padding: 8px 0;
                border-bottom: 1px solid #eee;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .endpoint-list li:last-child {
                border-bottom: none;
            }
            .method {
                font-weight: bold;
                padding: 4px 8px;
                border-radius: 4px;
                font-size: 0.8em;
                color: white;
            }
            .method.GET { background-color: #28a745; }
            .method.POST { background-color: #007bff; }
            .method.PUT { background-color: #ffc107; color: #333; }
            .method.DELETE { background-color: #dc3545; }
            .footer {
                text-align: center;
                margin-top: 40px;
                padding: 20px;
                color: #666;
                font-size: 0.9em;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>Invoice Platform API</h1>
            <p>Comprehensive documentation for all microservices</p>
        </div>

        <div class="main-docs">
            <h2>Complete API Documentation</h2>
            <p>Access the unified Swagger documentation for all services</p>
            <a href="/api-docs" class="btn" style="font-size: 1.1em; padding: 12px 24px;">
                📚 Open Complete API Documentation
            </a>
        </div>

        <div class="endpoint-info">
            <h3>🔧 Gateway Endpoints</h3>
            <ul class="endpoint-list">
                <li>
                    <span><span class="method GET">GET</span> /health</span>
                    <span>Gateway health check</span>
                </li>
                <li>
                    <span><span class="method GET">GET</span> /health/services</span>
                    <span>All services health status</span>
                </li>
                <li>
                    <span><span class="method GET">GET</span> /services</span>
                    <span>Service discovery</span>
                </li>
                <li>
                    <span><span class="method GET">GET</span> /docs</span>
                    <span>This documentation hub</span>
                </li>
                <li>
                    <span><span class="method GET">GET</span> /api-docs</span>
                    <span>Swagger UI documentation</span>
                </li>
            </ul>
        </div>

        <h2 style="text-align: center; margin: 40px 0 20px 0; color: #333;">📋 Available Services</h2>
        <div class="services-grid">
            ${Object.entries(services).map(([key, service]) => `
                <div class="service-card">
                    <h3>${service.name}</h3>
                    <p>${service.description}</p>
                    <div class="service-links">
                        <a href="${service.prefix}" class="btn">API Endpoint</a>
                        <a href="${service.prefix}/health" class="btn btn-secondary">Health Check</a>
                    </div>
                </div>
            `).join('')}
        </div>

        <div class="footer">
            <p>Invoice Platform API Gateway v1.0.0 | Built with ❤️ for developers</p>
            <p>For support, contact: <a href="mailto:support@invoiceplatform.com">support@invoiceplatform.com</a></p>
        </div>
    </body>
    </html>
  `;

  res.send(html);
});

/**
 * @swagger
 * /docs/services:
 *   get:
 *     tags: [Documentation]
 *     summary: Service documentation index
 *     description: JSON index of all available service documentation
 *     responses:
 *       200:
 *         description: Service documentation index
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 services:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       name:
 *                         type: string
 *                       key:
 *                         type: string
 *                       description:
 *                         type: string
 *                       docs_url:
 *                         type: string
 *                       api_url:
 *                         type: string
 */
router.get('/services', (req, res) => {
  const serviceList = Object.entries(services).map(([key, service]) => ({
    name: service.name,
    key,
    description: service.description,
    version: service.version,
    docs_url: `${req.protocol}://${req.get('host')}/docs/services/${key}`,
    api_url: `${req.protocol}://${req.get('host')}${service.prefix}`,
    health_url: `${req.protocol}://${req.get('host')}/health/services/${key}`
  }));

  res.json({
    title: 'Invoice Platform API Services',
    description: 'Complete list of available microservices and their documentation',
    timestamp: new Date().toISOString(),
    total_services: serviceList.length,
    services: serviceList
  });
});

/**
 * @swagger
 * /docs/services/{serviceName}:
 *   get:
 *     tags: [Documentation]
 *     summary: Service-specific documentation
 *     description: Swagger documentation for a specific service
 *     parameters:
 *       - in: path
 *         name: serviceName
 *         required: true
 *         schema:
 *           type: string
 *         description: Name of the service
 *         example: auth
 *     responses:
 *       200:
 *         description: Service documentation page
 *         content:
 *           text/html:
 *             schema:
 *               type: string
 *       404:
 *         description: Service not found
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

  try {
    // Try to fetch service-specific swagger docs
    const docsUrl = `${service.url}/docs/swagger.json`;
    let serviceSpecs = null;

    try {
      const response = await fetch(docsUrl, { timeout: 5000 });
      if (response.ok) {
        serviceSpecs = await response.json();
      }
    } catch (error) {
      logger.warn(`Could not fetch docs for ${serviceName}:`, error.message);
    }

    // If no service-specific docs, create basic documentation
    if (!serviceSpecs) {
      const serviceDocs = generateServiceDocs();
      serviceSpecs = serviceDocs[serviceName] || specs;
    }

    // Render Swagger UI for the specific service
    const html = swaggerUi.generateHTML(serviceSpecs, {
      explorer: true,
      customCss: '.swagger-ui .topbar { display: none }',
      customSiteTitle: `${service.name} API Documentation`,
      customfavIcon: '/favicon.ico',
      swaggerOptions: {
        persistAuthorization: true,
        displayRequestDuration: true,
        filter: true,
        tryItOutEnabled: true,
        url: null // Disable URL input
      }
    });

    res.send(html);
  } catch (error) {
    logger.error(`Error generating docs for ${serviceName}:`, error);
    res.status(500).json({
      error: 'Documentation Error',
      message: `Failed to generate documentation for ${service.name}`,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * @swagger
 * /docs/openapi.json:
 *   get:
 *     tags: [Documentation]
 *     summary: OpenAPI specification
 *     description: Raw OpenAPI specification in JSON format
 *     responses:
 *       200:
 *         description: OpenAPI specification
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 */
router.get('/openapi.json', (req, res) => {
  res.json(specs);
});

export default router;
