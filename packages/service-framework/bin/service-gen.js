#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SERVICE_TEMPLATE = {
  server: `import ServiceFramework from '@invoice/service-framework';
import routes from './routes/index.js';

const service = new ServiceFramework({
  serviceName: '{{SERVICE_NAME}}',
  port: process.env.PORT || {{PORT}},
});

service.addRoutes('/api', routes);

service.start();
`,
  
  routes: `import { Router } from 'express';
import { BaseController } from '@invoice/service-framework';
import {{MODEL_NAME}} from '../models/{{MODEL_FILE}}.js';

const router = Router();

// Create controller with base CRUD operations
const {{CONTROLLER_NAME}} = new BaseController({{MODEL_NAME}}, {
  userField: '{{USER_FIELD}}', // adjust as needed
  defaultSort: { createdAt: -1 }
});

// Standard CRUD routes
router.use('/', {{CONTROLLER_NAME}}.createRouter('{{RESOURCE_NAME}}'));

// Add custom routes here
// router.get('/{{RESOURCE_NAME}}/custom', async (req, res) => {
//   // Custom endpoint logic
// });

export default router;
`,

  model: `import mongoose from 'mongoose';

const {{SCHEMA_NAME}} = new mongoose.Schema({
  {{USER_FIELD}}: { type: mongoose.Types.ObjectId, required: true, ref: 'User' },
  // Add your fields here
  name: { type: String, required: true },
  description: String,
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

{{SCHEMA_NAME}}.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

export default mongoose.model('{{MODEL_NAME}}', {{SCHEMA_NAME}});
`,

  packageJson: `{
  "name": "{{PACKAGE_NAME}}",
  "version": "1.0.0",
  "description": "{{SERVICE_DESCRIPTION}}",
  "type": "module",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js"
  },
  "dependencies": {
    "@invoice/common": "^1.0.0",
    "@invoice/service-framework": "^1.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
`,

  dockerfile: `FROM node:20-alpine
WORKDIR /app

# Copy shared packages
COPY packages/common /packages/common
COPY packages/service-framework /packages/service-framework

# Install shared packages
RUN npm install --prefix /packages/common --omit=dev
RUN npm install --prefix /packages/service-framework --omit=dev

# Copy service files
COPY services/{{SERVICE_NAME}}/package.json ./
COPY services/{{SERVICE_NAME}}/src ./src

# Install service dependencies
RUN npm install --omit=dev

ENV NODE_ENV=production
EXPOSE {{PORT}}

CMD ["node", "src/server.js"]
`,

  env: `PORT={{PORT}}
NODE_ENV=development
CORS_ORIGIN=http://localhost:5173
`,

  envExample: `PORT={{PORT}}
NODE_ENV=development
CORS_ORIGIN=http://localhost:5173

# Add service-specific environment variables here
`
};

function createService(serviceName, options = {}) {
  const {
    port = 3000,
    resourceName = serviceName.toLowerCase(),
    modelName = capitalize(resourceName),
    userField = 'user'
  } = options;

  const servicePath = path.join(process.cwd(), 'services', serviceName);
  
  // Create directory structure
  const dirs = [
    servicePath,
    path.join(servicePath, 'src'),
    path.join(servicePath, 'src', 'routes'),
    path.join(servicePath, 'src', 'models')
  ];

  dirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });

  // Template variables
  const vars = {
    SERVICE_NAME: serviceName,
    PACKAGE_NAME: serviceName,
    SERVICE_DESCRIPTION: `${capitalize(serviceName)} service for invoice platform`,
    PORT: port,
    RESOURCE_NAME: resourceName,
    MODEL_NAME: modelName,
    MODEL_FILE: resourceName.toLowerCase(),
    SCHEMA_NAME: `${modelName}Schema`,
    CONTROLLER_NAME: `${resourceName}Controller`,
    USER_FIELD: userField
  };

  // Generate files
  const files = {
    'src/server.js': SERVICE_TEMPLATE.server,
    'src/routes/index.js': SERVICE_TEMPLATE.routes,
    [`src/models/${resourceName.toLowerCase()}.model.js`]: SERVICE_TEMPLATE.model,
    'package.json': SERVICE_TEMPLATE.packageJson,
    'Dockerfile': SERVICE_TEMPLATE.dockerfile,
    '.env': SERVICE_TEMPLATE.env,
    '.env.example': SERVICE_TEMPLATE.envExample
  };

  Object.entries(files).forEach(([filePath, content]) => {
    const fullPath = path.join(servicePath, filePath);
    const processedContent = Object.entries(vars).reduce(
      (acc, [key, value]) => acc.replace(new RegExp(`{{${key}}}`, 'g'), value),
      content
    );
    
    fs.writeFileSync(fullPath, processedContent);
  });

  console.log(`✅ Service '${serviceName}' created successfully!`);
  console.log(`📁 Location: ${servicePath}`);
  console.log(`🔧 Port: ${port}`);
  console.log(`📋 Resource: ${resourceName}`);
  console.log(`\n🚀 Next steps:`);
  console.log(`1. cd services/${serviceName}`);
  console.log(`2. npm install`);
  console.log(`3. Customize the model in src/models/${resourceName.toLowerCase()}.model.js`);
  console.log(`4. Add custom routes in src/routes/index.js`);
  console.log(`5. npm run dev`);
}

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

// CLI interface
const [,, command, serviceName, ...args] = process.argv;

if (command === 'create' && serviceName) {
  const options = {};
  
  // Parse arguments
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i]?.replace('--', '');
    const value = args[i + 1];
    if (key && value) {
      options[key] = isNaN(value) ? value : parseInt(value);
    }
  }

  createService(serviceName, options);
} else {
  console.log(`
🛠️  Invoice Platform Service Generator

Usage:
  npx service-gen create <service-name> [options]

Options:
  --port <number>        Port number (default: 3000)
  --resourceName <name>  Resource name (default: service name)
  --modelName <name>     Model name (default: capitalized resource name)
  --userField <field>    User association field (default: 'user')

Examples:
  npx service-gen create orders --port 3010
  npx service-gen create products --port 3011 --resourceName product
  npx service-gen create reports --port 3012 --userField userId
`);
}
