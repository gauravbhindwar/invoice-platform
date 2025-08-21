// Using relative path to avoid module resolution issues in Docker
import { ServiceFramework } from '../../../packages/service-framework/src/index.js';
import { createProxyMiddleware } from 'http-proxy-middleware';
import swaggerUi from 'swagger-ui-express';
import { services } from './config/services.js';
import specs from './config/swagger.js';
import healthRoutes from './routes/health.js';
import docsRoutes from './routes/docs.js';

// Create API Gateway service
const gateway = new ServiceFramework({
  serviceName: 'api-gateway',
  port: process.env.PORT || 3000,
  requiresAuth: false,
  requiresMongo: false
});

// Get the Express app instance
const app = gateway.getApp();

// Swagger documentation
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(specs, {
  explorer: true,
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Invoice Platform API Documentation',
  swaggerOptions: {
    persistAuthorization: true,
    displayRequestDuration: true,
    filter: true,
    tryItOutEnabled: true
  }
}));

// Health and docs routes
app.use('/health', healthRoutes);
app.use('/docs', docsRoutes);

// Service proxies
console.log('🔧 Starting proxy configuration...');
console.log('📋 Available services:', Object.keys(services));
Object.entries(services).forEach(([serviceName, config]) => {
  const envVarName = `${serviceName.toUpperCase().replace('-', '_')}_SERVICE_URL_INTERNAL`;
  const envUrl = process.env[envVarName];
  const serviceUrl = envUrl || config.url;
  
  console.log(`🔍 Service: ${serviceName}`);
  console.log(`   Env var: ${envVarName} = ${envUrl || 'undefined'}`);
  console.log(`   Config URL: ${config.url}`);
  console.log(`   Final URL: ${serviceUrl}`);
  
  const proxyOptions = {
    target: serviceUrl,
    changeOrigin: true,
    pathRewrite: config.pathRewrite || {
      [`^${config.prefix}`]: config.target || '/api'
    },
    timeout: 30000,
    proxyTimeout: 30000,
    onProxyReq: (proxyReq, req) => {
      proxyReq.setHeader('X-Forwarded-Service', serviceName);
      proxyReq.setHeader('X-Gateway-Version', '2.0.0');
      console.log(`📡 Proxying ${req.method} ${req.path} to ${serviceUrl}`);
    },
    onError: (err, req, res) => {
      console.error(`❌ Proxy error for ${serviceName}:`, err.message);
      res.status(503).json({ 
        error: 'Service temporarily unavailable',
        service: serviceName,
        message: `${config.name} is currently unavailable`
      });
    }
  };
  
  const proxy = createProxyMiddleware(proxyOptions);
  app.use(config.prefix, proxy);
  console.log(`✅ Proxy configured: ${config.prefix} -> ${serviceUrl}`);
});

// Root API route
app.get('/api', (req, res) => {
  res.json({
    message: 'Invoice Platform API Gateway',
    version: '2.0.0',
    services: Object.keys(services),
    documentation: '/api/docs',
    health: '/health'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    path: req.originalUrl,
    availableEndpoints: ['/api', '/api/docs', '/health']
  });
});

gateway.start();
