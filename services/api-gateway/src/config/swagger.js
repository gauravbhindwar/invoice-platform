import swaggerJsdoc from 'swagger-jsdoc';
import { services } from './services.js';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Invoice Platform API',
      version: '1.0.0',
      description: 'Comprehensive API documentation for the Invoice Platform microservices accessed via Traefik',
      contact: {
        name: 'API Support',
        email: 'support@invoiceplatform.com'
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT'
      }
    },
    servers: [
      {
        url: 'http://localhost',
        description: 'Development server via Traefik'
      },
      {
        url: 'https://api.invoiceplatform.com',
        description: 'Production server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
              example: false
            },
            message: {
              type: 'string',
              example: 'Error message'
            },
            error: {
              type: 'object'
            }
          }
        },
        Success: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
              example: true
            },
            data: {
              type: 'object'
            }
          }
        },
        User: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: '507f1f77bcf86cd799439011'
            },
            email: {
              type: 'string',
              format: 'email',
              example: 'user@example.com'
            },
            name: {
              type: 'string',
              example: 'John Doe'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Invoice: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: '507f1f77bcf86cd799439011'
            },
            invoiceNumber: {
              type: 'string',
              example: 'INV-2024-001'
            },
            customerId: {
              type: 'string',
              example: '507f1f77bcf86cd799439012'
            },
            amount: {
              type: 'number',
              example: 1500.50
            },
            status: {
              type: 'string',
              enum: ['draft', 'sent', 'paid', 'overdue'],
              example: 'sent'
            },
            dueDate: {
              type: 'string',
              format: 'date'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Customer: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: '507f1f77bcf86cd799439011'
            },
            name: {
              type: 'string',
              example: 'ABC Company'
            },
            email: {
              type: 'string',
              format: 'email',
              example: 'contact@abccompany.com'
            },
            phone: {
              type: 'string',
              example: '+1-555-123-4567'
            },
            address: {
              type: 'object',
              properties: {
                street: { type: 'string' },
                city: { type: 'string' },
                state: { type: 'string' },
                zipCode: { type: 'string' },
                country: { type: 'string' }
              }
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Expense: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: '507f1f77bcf86cd799439011'
            },
            description: {
              type: 'string',
              example: 'Office supplies'
            },
            amount: {
              type: 'number',
              example: 125.50
            },
            category: {
              type: 'string',
              example: 'office'
            },
            date: {
              type: 'string',
              format: 'date'
            },
            receiptUrl: {
              type: 'string',
              example: 'https://example.com/receipt.pdf'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Item: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: '507f1f77bcf86cd799439011'
            },
            name: {
              type: 'string',
              example: 'Laptop'
            },
            description: {
              type: 'string',
              example: 'High-performance laptop'
            },
            price: {
              type: 'number',
              example: 999.99
            },
            quantity: {
              type: 'number',
              example: 10
            },
            sku: {
              type: 'string',
              example: 'LAP-001'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Tax: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              example: '507f1f77bcf86cd799439011'
            },
            name: {
              type: 'string',
              example: 'Sales Tax'
            },
            rate: {
              type: 'number',
              example: 8.25
            },
            type: {
              type: 'string',
              enum: ['percentage', 'fixed'],
              example: 'percentage'
            },
            region: {
              type: 'string',
              example: 'CA'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        }
      }
    },
    tags: [
      {
        name: 'Authentication',
        description: 'User authentication and authorization endpoints'
      },
      {
        name: 'Invoices',
        description: 'Invoice management endpoints'
      },
      {
        name: 'Customers',
        description: 'Customer management endpoints'
      },
      {
        name: 'Expenses',
        description: 'Expense tracking endpoints'
      },
      {
        name: 'Inventory',
        description: 'Inventory management endpoints'
      },
      {
        name: 'Tax',
        description: 'Tax configuration endpoints'
      },
      {
        name: 'Uploads',
        description: 'File upload endpoints'
      },
      {
        name: 'Dashboard',
        description: 'Dashboard and analytics endpoints'
      },
      {
        name: 'AI',
        description: 'AI-powered features endpoints'
      }
    ]
  },
  apis: ['./src/routes/*.js', './src/docs/*.js'], // paths to files containing OpenAPI definitions
};

export const specs = swaggerJsdoc(options);

// Generate service-specific documentation
export const generateServiceDocs = () => {
  const serviceDocs = {};
  
  Object.entries(services).forEach(([key, service]) => {
    serviceDocs[key] = {
      ...options.definition,
      info: {
        ...options.definition.info,
        title: `${service.name} API`,
        description: service.description
      },
      servers: [
        {
          url: `http://localhost${service.prefix}`,
          description: `${service.name} via Traefik`
        }
      ]
    };
  });
  
  return serviceDocs;
};

export default specs;
