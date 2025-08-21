# Use Node.js LTS version
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package.json files
COPY packages/common /packages/common
COPY services/api-gateway/package.json ./

# Install dependencies for common package
RUN npm install --prefix /packages/common --omit=dev

# Copy and install service-framework package required by ServiceFramework import
COPY packages/service-framework /packages/service-framework
# Install local dependency @invoice/common from the monorepo into service-framework
# This prevents npm from trying to fetch @invoice/common from the public registry
RUN if [ -d /packages/common ]; then npm install --prefix /packages/service-framework /packages/common --no-audit --no-fund || true; fi
RUN npm install --prefix /packages/service-framework --omit=dev || true

# Install dependencies for api-gateway
RUN npm install --omit=dev

# Copy source code
COPY packages/common/ /app/packages/common/
COPY services/api-gateway/src ./src

# Create a non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "src/server.js"]
