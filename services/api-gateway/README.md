# Invoice Platform API Gateway

The API Gateway serves as the central entry point for all Invoice Platform microservices, providing unified access, documentation, and routing via Traefik.

## Features

- **Unified API Access**: Single entry point for all microservices
- **Comprehensive Documentation**: Auto-generated Swagger/OpenAPI documentation
- **Health Monitoring**: Real-time health checks for all services
- **Service Discovery**: Automatic service registration and discovery
- **Traefik Integration**: Seamless integration with Traefik reverse proxy
- **CORS Support**: Configurable CORS for cross-origin requests
- **Request/Response Logging**: Detailed logging for debugging and monitoring
- **Error Handling**: Centralized error handling and formatting

## Quick Start

### Development Mode (Local)

```bash
# Install dependencies
npm install

# Start the API Gateway
npm run dev
```

### Production Mode (Docker + Traefik)

```bash
# Build and start all services with Traefik
docker compose up --build
```

## API Endpoints

### Gateway Endpoints

- `GET /` - API Gateway information and service discovery
- `GET /health` - Gateway health check
- `GET /health/services` - All services health status
- `GET /health/services/{serviceName}` - Specific service health
- `GET /services` - Service discovery endpoint
- `GET /docs` - Interactive documentation hub
- `GET /api-docs` - Swagger UI for complete API documentation

### Service Endpoints (via Proxy)

All service endpoints are accessible through their configured prefixes:

- `POST /api/auth/login` - User authentication
- `GET /api/customers` - Customer management
- `GET /api/invoices` - Invoice operations
- `GET /api/inventory` - Inventory management
- `GET /api/expenses` - Expense tracking
- `GET /api/tax` - Tax calculations
- `GET /api/uploads` - File uploads
- `GET /api/ai` - AI-powered features
- `GET /api/dashboard` - Analytics and dashboard data

## Configuration

### Environment Variables

```bash
# Gateway Configuration
PORT=3000
NODE_ENV=development
LOG_LEVEL=debug
CORS_ORIGIN=*

# Service URLs (Docker networking)
AUTH_SERVICE_URL=http://auth:3001
INVOICES_SERVICE_URL=http://invoices:3002
CUSTOMERS_SERVICE_URL=http://customers:3003
# ... other service URLs

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Proxy Timeouts
PROXY_TIMEOUT=30000
PROXY_CONNECT_TIMEOUT=5000
```

### Service Configuration

Services are configured in `src/config/services.js`. Each service includes:

- **name**: Human-readable service name
- **url**: Internal service URL (Docker networking)
- **prefix**: API path prefix (e.g., `/api/auth`)
- **target**: Target path on the service (e.g., `/api`)
- **healthCheck**: Health check endpoint path
- **description**: Service description for documentation
- **version**: Service version

## Traefik Integration

The API Gateway is configured to work with Traefik reverse proxy:

### Labels in docker-compose.override.yml

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api-gateway.rule=PathPrefix(`/`)"
  - "traefik.http.routers.api-gateway.priority=1"
  - "traefik.http.services.api-gateway.loadbalancer.server.port=3000"
```

### Access Points

With Traefik running:

- **Gateway**: http://localhost (main entry point)
- **Documentation**: http://localhost/docs
- **Swagger UI**: http://localhost/api-docs
- **Traefik Dashboard**: http://localhost:8081

## Documentation

### Swagger/OpenAPI

The API Gateway automatically generates comprehensive API documentation:

1. **Complete API Docs**: `/api-docs` - All services in one interface
2. **Service-specific Docs**: `/docs/services/{serviceName}` - Individual service docs
3. **Interactive Hub**: `/docs` - Beautiful documentation portal

### Adding Documentation

Documentation is defined in `src/docs/` directory:

- `auth.js` - Authentication endpoints
- `customers.js` - Customer management endpoints
- Add new files for additional services

## Health Monitoring

### Gateway Health

```bash
curl http://localhost/health
```

### All Services Health

```bash
curl http://localhost/health/services
```

### Specific Service Health

```bash
curl http://localhost/health/services/auth
```

## Development

### Adding a New Service

1. **Update Service Configuration** (`src/config/services.js`):

```javascript
newService: {
  name: 'New Service',
  url: process.env.NEW_SERVICE_URL || 'http://new-service:3010',
  prefix: '/api/new-service',
  target: '/api',
  healthCheck: '/health',
  description: 'Description of the new service',
  version: '1.0.0'
}
```

2. **Add to Docker Compose**:

```yaml
new-service:
  build:
    context: .
    dockerfile: services/new-service/Dockerfile
  expose:
    - "3010"
  # ... other configuration
```

3. **Create Documentation** (`src/docs/new-service.js`):

```javascript
/**
 * @swagger
 * /api/new-service:
 *   get:
 *     tags: [New Service]
 *     summary: Get new service data
 *     # ... OpenAPI specification
 */
```

### Running Tests

```bash
# Unit tests
npm test

# Integration tests
npm run test:integration

# Health check tests
npm run test:health
```

## Monitoring and Logging

### Request Logging

All requests are logged with:
- HTTP method and path
- Response time
- Status code
- Source IP
- User agent

### Error Handling

Centralized error handling provides:
- Consistent error format
- Request ID tracking
- Stack traces in development
- Sanitized errors in production

### Metrics

Health check endpoints provide:
- Service response times
- Service availability
- Gateway uptime
- Memory usage

## Security

### Authentication

The gateway supports multiple authentication methods:
- **Bearer Token**: JWT tokens via `Authorization: Bearer <token>`
- **API Key**: Service-to-service via `X-API-Key` header

### CORS

Configurable CORS settings:
- Origins whitelist
- Allowed methods
- Allowed headers
- Credentials support

### Rate Limiting

Built-in rate limiting:
- Window-based limiting
- Per-IP restrictions
- Configurable limits

## Deployment

### Docker Production

```bash
# Build production image
docker build -t invoice-platform/api-gateway .

# Run with Traefik
docker compose -f docker-compose.yml -f docker-compose.prod.yml up
```

### Environment-specific Configuration

- **Development**: Local service URLs (localhost:300X)
- **Production**: Docker service names (service-name:port)
- **Staging**: External service URLs

## Troubleshooting

### Common Issues

1. **Service Unavailable (502)**
   - Check if target service is running
   - Verify service URLs in configuration
   - Check Docker networking

2. **Authentication Errors (401)**
   - Verify JWT token validity
   - Check authentication service status
   - Validate API key configuration

3. **CORS Errors**
   - Update `CORS_ORIGIN` configuration
   - Check preflight request handling
   - Verify allowed headers

### Debug Mode

Enable debug logging:

```bash
LOG_LEVEL=debug npm run dev
```

### Health Check Debugging

```bash
# Check gateway health
curl -v http://localhost/health

# Check all services
curl -v http://localhost/health/services

# Check specific service
curl -v http://localhost/health/services/auth
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Update documentation
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
