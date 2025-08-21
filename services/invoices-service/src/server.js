// Using relative path to avoid module resolution issues in Docker
import { ServiceFramework } from '../../../packages/service-framework/src/index.js';
import routes from './routes/index.js';

const service = new ServiceFramework({
  serviceName: 'invoices-service',
  port: process.env.PORT || 3002,
});

service.addRoutes('/api', routes);

service.start();
