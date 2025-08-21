#!/bin/bash

# Invoice Platform Production Deployment Script
echo "🚀 Starting Invoice Platform deployment to Google Clo        --set-env-vars="DATABASE_URL=$DATABASE_URL" \
        --set-env-vars="JWT_SECRET=$JWT_SECRET" \
        --set-env-vars="CORS_ORIGIN=$CORS_ORIGIN" \
        --set-env-vars="GCS_BUCKET=$GCS_BUCKET" \
        --set-env-vars="BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS" \Run..."

# Set project and region - UPDATE THESE VALUES
export PROJECT_ID="invoice-platform-prod"  # Change to your GCP project ID
export REGION="asia-south1"

# Database and environment configuration - UPDATE THESE VALUES
export DATABASE_URL="mongodb+srv://username:password@cluster.mongodb.net/invoice-platform?retryWrites=true&w=majority"
export JWT_SECRET="your-super-secure-jwt-secret-minimum-32-characters"
export CORS_ORIGIN="https://your-frontend-domain.com"

# Backup configuration
export GCS_BUCKET="invoice-platform-backups"
export BACKUP_RETENTION_DAYS="7"

# Service configuration
export NODE_ENV="production"

# Service definitions
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

# Function to create Dockerfile for each service
create_dockerfile() {
    local service_name=$1
    local service_port=$2
    
    echo "📝 Creating Dockerfile for $service_name..."
    
    cat > "services/$service_name/Dockerfile" << DOCKERFILE
# Use the official Node.js 20 image
FROM node:20-alpine

# Install system dependencies
RUN apk add --no-cache dumb-init curl

# Set the working directory
WORKDIR /app

# Copy entire project
COPY . .

# Install dependencies for packages
RUN cd packages/service-framework && npm install --only=production
RUN cd packages/common && npm install --only=production

# Install dependencies for the service
RUN cd services/$service_name && npm install --only=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S nodeapp -u 1001 && \\
    chown -R nodeapp:nodejs /app

# Switch to non-root user
USER nodeapp

# Expose the port
EXPOSE $service_port

# Set environment variables
ENV NODE_ENV=production
ENV PORT=$service_port
ENV SERVICE_NAME=$service_name

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:$service_port/healthz || exit 1

# Start the application
CMD ["dumb-init", "node", "services/$service_name/src/server.js"]
DOCKERFILE
}

# Function to deploy a service
deploy_service() {
    local service_name=$1
    local service_port=$2
    
    echo "🚀 Deploying $service_name to Cloud Run..."
    
    # Create Dockerfile for the service
    create_dockerfile "$service_name" "$service_port"
    
    # Determine memory and CPU requirements
    local memory="512Mi"
    local cpu="1"
    local max_instances="10"
    
    # API Gateway and AI Service need more resources
    if [[ "$service_name" == "api-gateway" || "$service_name" == "ai-service" ]]; then
        memory="1Gi"
        cpu="2"
        max_instances="20"
    fi
    
    # Deploy to Cloud Run using source deployment
    gcloud run deploy "$service_name" \\
        --source="services/$service_name" \\
        --platform=managed \\
        --region="$REGION" \\
        --project="$PROJECT_ID" \\
        --allow-unauthenticated \\
        --port="$service_port" \\
        --set-env-vars="NODE_ENV=$NODE_ENV" \\
        --set-env-vars="PORT=$service_port" \\
        --set-env-vars="SERVICE_NAME=$service_name" \\
        --set-env-vars="DATABASE_URL=$DATABASE_URL" \\
        --set-env-vars="JWT_SECRET=$JWT_SECRET" \\
        --set-env-vars="CORS_ORIGIN=$CORS_ORIGIN" \\
        --cpu="$cpu" \\
        --memory="$memory" \\
        --max-instances="$max_instances" \\
        --timeout=300 \\
        --concurrency=100 \\
        --min-instances=0
    
    if [ $? -eq 0 ]; then
        echo "✅ $service_name deployed successfully!"
        
        # Get the service URL
        local service_url=$(gcloud run services describe "$service_name" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)")
        echo "🌐 $service_name URL: $service_url"
        
        # Store in array for final summary
        SERVICE_URLS["$service_name"]="$service_url"
    else
        echo "❌ Failed to deploy $service_name"
        exit 1
    fi
}

# Initialize service URLs array
declare -A SERVICE_URLS

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
echo "🔧 Setting up project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

echo "🚀 Starting deployment of all services..."
echo ""

# Deploy all services
for service_name in "${!SERVICES[@]}"; do
    deploy_service "$service_name" "${SERVICES[$service_name]}"
    echo ""
    sleep 2  # Small delay between deployments
done

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo ""
echo "📋 Service URLs:"
for service_name in "${!SERVICE_URLS[@]}"; do
    echo "• $service_name: ${SERVICE_URLS[$service_name]}"
done

echo ""
echo "🔧 Next Steps:"
echo "1. Configure your frontend to use the API Gateway URL: ${SERVICE_URLS[api-gateway]}"
echo "2. Set up custom domain mapping if needed"
echo "3. Configure monitoring and alerting"
echo "4. Test all endpoints"
echo ""
echo "📊 Monitor your services:"
echo "gcloud run services list --region=$REGION --project=$PROJECT_ID"
echo ""
echo "🎯 Your Invoice Platform is now live in production!"
echo "API Gateway: ${SERVICE_URLS[api-gateway]}"
