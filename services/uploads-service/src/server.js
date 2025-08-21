// Using relative path to avoid module resolution issues in Docker
import { ServiceFramework } from '../../../packages/service-framework/src/index.js';
import routes from './routes/index.js';

const service = new ServiceFramework({
  serviceName: 'uploads-service',
  port: process.env.PORT || 3007,
  requiresAuth: true,
});

service.addRoutes('/api', routes);

service.start();
