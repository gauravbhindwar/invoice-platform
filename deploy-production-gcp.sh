#!/bin/bash

# Invoice Platform Production Deployment Script
echo "🚀 Starting Invoice Platform microservices deployment to GCP..."

# Set project and region
export PROJECT_ID="invoicebackend"  # Change this to your actual GCP project ID
export REGION="asia-south1"
export CLUSTER_NAME="invoice-platform-cluster"

# Database and environment configuration
export DATABASE_URL="mongodb://mongodb-user:mongodb-password@localhost:27017/invoice-platform?authSource=admin"
export JWT_SECRET="your-super-secure-jwt-secret-key-here"
export NODE_ENV="production"

# CORS settings for production
export CORS_ORIGIN="https://your-frontend-domain.com,https://www.your-frontend-domain.com"

# API Gateway configuration
export API_GATEWAY_PORT="3000"

# Service definitions with their ports
declare -A SERVICES=(
    ["api-gateway"]="3000"
    ["auth-service"]="3001"
    ["customers-service"]="3002"
    ["invoices-service"]="3003"
    ["inventory-service"]="3004"
    ["expenses-service"]="3005"
    ["tax-service"]="3006"
    ["uploads-service"]="3007"
    ["dashboard-service"]="3008"
    ["ai-service"]="3009"
)

# Create optimized Dockerfile for each service
create_dockerfile() {
    local service_name=$1
    local service_port=$2
    
    echo "📝 Creating Dockerfile for $service_name..."
    
    cat > "services/$service_name/Dockerfile.production" << DOCKERFILE
# Multi-stage build for production optimization
FROM node:20-alpine AS base

# Install system dependencies
RUN apk add --no-cache dumb-init

# Set working directory
WORKDIR /app

# Copy package files for dependency installation
COPY package*.json ./
COPY packages/service-framework/package*.json ./packages/service-framework/
COPY packages/common/package*.json ./packages/common/

# Copy source code
COPY packages/ ./packages/
COPY services/$service_name/ ./services/$service_name/

# Production stage
FROM base AS production

# Install dependencies
RUN cd packages/service-framework && npm ci --only=production
RUN cd packages/common && npm ci --only=production
RUN cd services/$service_name && npm ci --only=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S nodeapp -u 1001 && \\
    chown -R nodeapp:nodejs /app

# Switch to non-root user
USER nodeapp

# Expose port
EXPOSE $service_port

# Set environment variables
ENV NODE_ENV=production
ENV PORT=$service_port
ENV SERVICE_NAME=$service_name

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:$service_port/healthz || exit 1

# Start application with dumb-init
CMD ["dumb-init", "node", "services/$service_name/src/server.js"]
DOCKERFILE
}

# Create Cloud Build configuration
create_cloudbuild_config() {
    echo "📝 Creating Cloud Build configuration..."
    
    cat > "cloudbuild.yaml" << 'CLOUDBUILD'
steps:
  # Build all services in parallel
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/api-gateway/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/api-gateway:$BUILD_ID', '.']
    id: 'build-api-gateway'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/auth-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/auth-service:$BUILD_ID', '.']
    id: 'build-auth-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/customers-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/customers-service:$BUILD_ID', '.']
    id: 'build-customers-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/invoices-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/invoices-service:$BUILD_ID', '.']
    id: 'build-invoices-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/inventory-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/inventory-service:$BUILD_ID', '.']
    id: 'build-inventory-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/expenses-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/expenses-service:$BUILD_ID', '.']
    id: 'build-expenses-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/tax-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/tax-service:$BUILD_ID', '.']
    id: 'build-tax-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/uploads-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/uploads-service:$BUILD_ID', '.']
    id: 'build-uploads-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/dashboard-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/dashboard-service:$BUILD_ID', '.']
    id: 'build-dashboard-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-f', 'services/ai-service/Dockerfile.production', '-t', 'gcr.io/$PROJECT_ID/ai-service:$BUILD_ID', '.']
    id: 'build-ai-service'

# Push all images to Google Container Registry
images:
  - 'gcr.io/$PROJECT_ID/api-gateway:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/auth-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/customers-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/invoices-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/inventory-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/expenses-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/tax-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/uploads-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/dashboard-service:$BUILD_ID'
  - 'gcr.io/$PROJECT_ID/ai-service:$BUILD_ID'

options:
  machineType: 'E2_HIGHCPU_8'
  diskSizeGb: 100
timeout: 1800s
CLOUDBUILD
}

# Deploy a service to Cloud Run
deploy_service() {
    local service_name=$1
    local service_port=$2
    
    echo "🚀 Deploying $service_name to Cloud Run..."
    
    # Determine memory and CPU requirements based on service
    local memory="512Mi"
    local cpu="1"
    local max_instances="10"
    
    # API Gateway and AI Service need more resources
    if [[ "$service_name" == "api-gateway" || "$service_name" == "ai-service" ]]; then
        memory="1Gi"
        cpu="2"
        max_instances="20"
    fi
    
    gcloud run deploy "$service_name" \
        --image="gcr.io/$PROJECT_ID/$service_name:latest" \
        --platform=managed \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --allow-unauthenticated \
        --port="$service_port" \
        --set-env-vars="NODE_ENV=$NODE_ENV" \
        --set-env-vars="PORT=$service_port" \
        --set-env-vars="SERVICE_NAME=$service_name" \
        --set-env-vars="DATABASE_URL=$DATABASE_URL" \
        --set-env-vars="JWT_SECRET=$JWT_SECRET" \
        --set-env-vars="CORS_ORIGIN=$CORS_ORIGIN" \
        --cpu="$cpu" \
        --memory="$memory" \
        --max-instances="$max_instances" \
        --timeout=300 \
        --concurrency=100 \
        --min-instances=0
    
    if [ $? -eq 0 ]; then
        echo "✅ $service_name deployed successfully!"
        
        # Get the service URL
        local service_url=$(gcloud run services describe "$service_name" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")
        echo "🌐 $service_name URL: $service_url"
        
        # Store URL for later use
        export "${service_name//-/_}_URL"="$service_url"
    else
        echo "❌ Failed to deploy $service_name"
        exit 1
    fi
}

# Create environment configuration file
create_env_config() {
    echo "📝 Creating environment configuration..."
    
    cat > ".env.production" << ENV
# Production Environment Configuration
NODE_ENV=production
PROJECT_ID=$PROJECT_ID
REGION=$REGION

# Database
DATABASE_URL=$DATABASE_URL

# Security
JWT_SECRET=$JWT_SECRET
CORS_ORIGIN=$CORS_ORIGIN

# Service URLs (will be updated after deployment)
API_GATEWAY_URL=https://api-gateway-PROJECT_SUFFIX.asia-south1.run.app
AUTH_SERVICE_URL=https://auth-service-PROJECT_SUFFIX.asia-south1.run.app
CUSTOMERS_SERVICE_URL=https://customers-service-PROJECT_SUFFIX.asia-south1.run.app
INVOICES_SERVICE_URL=https://invoices-service-PROJECT_SUFFIX.asia-south1.run.app
INVENTORY_SERVICE_URL=https://inventory-service-PROJECT_SUFFIX.asia-south1.run.app
EXPENSES_SERVICE_URL=https://expenses-service-PROJECT_SUFFIX.asia-south1.run.app
TAX_SERVICE_URL=https://tax-service-PROJECT_SUFFIX.asia-south1.run.app
UPLOADS_SERVICE_URL=https://uploads-service-PROJECT_SUFFIX.asia-south1.run.app
DASHBOARD_SERVICE_URL=https://dashboard-service-PROJECT_SUFFIX.asia-south1.run.app
AI_SERVICE_URL=https://ai-service-PROJECT_SUFFIX.asia-south1.run.app
ENV
}

# Setup MongoDB Atlas (recommended for production)
setup_mongodb_atlas() {
    echo "📝 Setting up MongoDB Atlas connection..."
    echo ""
    echo "🔧 IMPORTANT: For production, it's recommended to use MongoDB Atlas instead of self-hosted MongoDB."
    echo ""
    echo "Please follow these steps:"
    echo "1. Create a MongoDB Atlas cluster: https://cloud.mongodb.com"
    echo "2. Whitelist Google Cloud Run IP ranges"
    echo "3. Create a database user with appropriate permissions"
    echo "4. Update the DATABASE_URL in this script with your Atlas connection string"
    echo ""
    echo "Example Atlas connection string:"
    echo "mongodb+srv://username:password@cluster.mongodb.net/invoice-platform?retryWrites=true&w=majority"
    echo ""
    read -p "Have you updated the DATABASE_URL? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⚠️  Please update the DATABASE_URL and run the script again."
        exit 1
    fi
}

# Main deployment process
main() {
    echo "🎯 Invoice Platform Production Deployment"
    echo "=========================================="
    echo ""
    
    # Validate prerequisites
    echo "🔍 Checking prerequisites..."
    
    # Check if gcloud is installed and authenticated
    if ! command -v gcloud &> /dev/null; then
        echo "❌ gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        echo "❌ You are not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    # Set project
    gcloud config set project "$PROJECT_ID"
    
    # Enable required APIs
    echo "🔧 Enabling required APIs..."
    gcloud services enable cloudbuild.googleapis.com
    gcloud services enable run.googleapis.com
    gcloud services enable containerregistry.googleapis.com
    
    # Setup database
    setup_mongodb_atlas
    
    # Create configuration files
    create_env_config
    create_cloudbuild_config
    
    # Create Dockerfiles for all services
    echo "📦 Creating production Dockerfiles..."
    for service_name in "${!SERVICES[@]}"; do
        create_dockerfile "$service_name" "${SERVICES[$service_name]}"
    done
    
    # Build all images using Cloud Build
    echo "🏗️  Building all service images with Cloud Build..."
    gcloud builds submit --config=cloudbuild.yaml .
    
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Please check the logs and try again."
        exit 1
    fi
    
    # Deploy all services
    echo "🚀 Deploying all services to Cloud Run..."
    for service_name in "${!SERVICES[@]}"; do
        deploy_service "$service_name" "${SERVICES[$service_name]}"
        sleep 5  # Small delay between deployments
    done
    
    echo ""
    echo "🎉 Deployment Complete!"
    echo "======================="
    echo ""
    echo "📋 Service URLs:"
    echo "• API Gateway: $api_gateway_URL"
    echo "• Auth Service: $auth_service_URL"
    echo "• Customers Service: $customers_service_URL"
    echo "• Invoices Service: $invoices_service_URL"
    echo "• Inventory Service: $inventory_service_URL"
    echo "• Expenses Service: $expenses_service_URL"
    echo "• Tax Service: $tax_service_URL"
    echo "• Uploads Service: $uploads_service_URL"
    echo "• Dashboard Service: $dashboard_service_URL"
    echo "• AI Service: $ai_service_URL"
    echo ""
    echo "🔧 Next Steps:"
    echo "1. Update your frontend to use the API Gateway URL"
    echo "2. Configure your domain and SSL certificates"
    echo "3. Set up monitoring and logging"
    echo "4. Configure CI/CD pipelines"
    echo ""
    echo "📊 Monitor your services:"
    echo "gcloud run services list --region=$REGION"
    echo ""
    echo "🎯 Your Invoice Platform is now live in production!"
}

# Run the main deployment process
main "$@"
