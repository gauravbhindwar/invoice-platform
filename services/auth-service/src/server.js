// Using relative path to avoid module resolution issues in Docker
import { ServiceFramework } from '../../../packages/service-framework/src/index.js';
import routes from './routes/index.js';
import swaggerUi from 'swagger-ui-express';
import { swaggerSpec } from './config/swagger.js';

const service = new ServiceFramework({
  serviceName: 'auth-service',
  port: process.env.PORT || 3001,
  requiresAuth: false, // Auth service handles its own auth
});

// Add Swagger documentation
service.app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Auth routes don't require authentication by default
service.addPublicRoutes('/api', routes);

service.start();
