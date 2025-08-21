// Service configuration mapping for local Docker setup
export const services = {
  auth: {
    name: 'Authentication Service',
    url: process.env.AUTH_SERVICE_URL || 'http://auth-service:3001',
    prefix: '/api/auth',
    target: '/api',
    healthCheck: '/healthz',
    description: 'User authentication and authorization',
    version: '1.0.0'
  },
  invoices: {
    name: 'Invoices Service',
    url: process.env.INVOICES_SERVICE_URL || 'http://invoices-service:3003',
    prefix: '/api/invoices',
    target: '/api',
    healthCheck: '/healthz',
    description: 'Invoice management and generation',
    version: '1.0.0'
  },
  customers: {
    name: 'Customers Service',
    url: process.env.CUSTOMERS_SERVICE_URL || 'http://customers-service:3002',
    prefix: '/api/customers',
    target: '/api',
    healthCheck: '/healthz',
    description: 'Customer data management',
    version: '1.0.0'
  },
  inventory: {
    name: 'Inventory Service',
    url: process.env.INVENTORY_SERVICE_URL || 'http://inventory-service:3004',
    prefix: '/api/inventory',
    target: '/api',
    healthCheck: '/healthz',
    description: 'Inventory and item management',
    version: '1.0.0'
  },
  tax: {
    name: 'Tax Service',
    url: process.env.TAX_SERVICE_URL || 'http://tax-service:3006',
    prefix: '/api/tax',
    target: '/api',
    healthCheck: '/healthz',
    description: 'Tax calculation and management',
    version: '1.0.0'
  },
  uploads: {
    name: 'Uploads Service',
    url: process.env.UPLOADS_SERVICE_URL || 'http://uploads-service:3007',
    prefix: '/api/uploads',
    target: '/api',
    healthCheck: '/healthz',
    description: 'File upload and management',
    version: '1.0.0'
  },
  ai: {
    name: 'AI Service',
    url: process.env.AI_SERVICE_URL || 'http://ai-service:3009',
    prefix: '/api/ai',
    target: '/api',
    healthCheck: '/healthz',
    description: 'AI-powered features and automation',
    version: '1.0.0'
  },
  expenses: {
    name: 'Expenses Service',
    url: process.env.EXPENSES_SERVICE_URL || 'http://expenses-service:3005',
    prefix: '/api/expenses',
    target: '/api',
    healthCheck: '/healthz',
    description: 'Expense tracking and management',
    version: '1.0.0'
  },
  dashboard: {
    name: 'Dashboard Service',
    url: process.env.DASHBOARD_SERVICE_URL || 'http://dashboard-service:3008',
    prefix: '/api/dashboard',
    target: '/api',
    healthCheck: '/healthz',
    description: 'Analytics and dashboard data',
    version: '1.0.0'
  }
};

export default services;
