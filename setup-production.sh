#!/bin/bash

# Invoice Platform Production Setup Helper
echo "🔧 Invoice Platform Production Setup Helper"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "Google Cloud CLI is not installed."
        echo "Please install it from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    print_success "Google Cloud CLI is installed"
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed."
        echo "Please install it from: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"
    
    # Check if user is authenticated with gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_warning "You are not authenticated with Google Cloud."
        echo "Please run: gcloud auth login"
        read -p "Press enter after authentication..."
    fi
    print_success "Google Cloud authentication verified"
}

# Configure project
configure_project() {
    print_step "Configuring Google Cloud project..."
    
    # Get current project
    current_project=$(gcloud config get-value project 2>/dev/null)
    
    if [ -z "$current_project" ]; then
        echo "No project is currently set."
        read -p "Enter your Google Cloud Project ID: " project_id
        gcloud config set project "$project_id"
    else
        echo "Current project: $current_project"
        read -p "Use this project? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your Google Cloud Project ID: " project_id
            gcloud config set project "$project_id"
        fi
    fi
    
    project_id=$(gcloud config get-value project)
    print_success "Project set to: $project_id"
    
    # Enable required APIs
    print_step "Enabling required Google Cloud APIs..."
    gcloud services enable cloudbuild.googleapis.com
    gcloud services enable run.googleapis.com
    gcloud services enable containerregistry.googleapis.com
    print_success "APIs enabled successfully"
}

# Generate JWT secret
generate_jwt_secret() {
    print_step "Generating JWT secret..."
    
    # Generate a random 64-character string
    jwt_secret=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64 | tr -d "=+/" | cut -c1-32)
    
    if [ ${#jwt_secret} -lt 32 ]; then
        jwt_secret="invoice-platform-jwt-secret-$(date +%s)-$(shuf -i 1000-9999 -n 1)"
    fi
    
    print_success "JWT secret generated"
    echo "JWT_SECRET: $jwt_secret"
}

# Configure environment
configure_environment() {
    print_step "Creating production environment configuration..."
    
    project_id=$(gcloud config get-value project)
    
    # Get MongoDB Atlas connection string
    echo ""
    echo "🍃 MongoDB Atlas Configuration"
    echo "==============================="
    echo ""
    echo "For production, we recommend using MongoDB Atlas."
    echo "If you haven't set it up yet:"
    echo "1. Go to: https://cloud.mongodb.com"
    echo "2. Create a new cluster"
    echo "3. Create a database user"
    echo "4. Whitelist IP addresses (use 0.0.0.0/0 for Cloud Run)"
    echo "5. Get your connection string"
    echo ""
    
    read -p "Enter your MongoDB Atlas connection string: " database_url
    
    # Get frontend domain
    echo ""
    read -p "Enter your frontend domain (e.g., https://yourapp.com): " frontend_domain
    
    # Create .env.production file
    cat > .env.production << EOF
# Production Environment Variables for Invoice Platform
PROJECT_ID=$project_id
REGION=asia-south1
NODE_ENV=production

# Database Configuration
DATABASE_URL=$database_url

# Security Configuration
JWT_SECRET=$jwt_secret

# CORS Configuration
CORS_ORIGIN=$frontend_domain

# Service Ports
API_GATEWAY_PORT=3000
AUTH_SERVICE_PORT=3001
CUSTOMERS_SERVICE_PORT=3002
INVOICES_SERVICE_PORT=3003
INVENTORY_SERVICE_PORT=3004
EXPENSES_SERVICE_PORT=3005
TAX_SERVICE_PORT=3006
UPLOADS_SERVICE_PORT=3007
DASHBOARD_SERVICE_PORT=3008
AI_SERVICE_PORT=3009

# Additional Configuration
LOG_LEVEL=info
MAX_REQUEST_SIZE=10mb
REQUEST_TIMEOUT=30000
EOF
    
    print_success "Environment configuration created: .env.production"
}

# Update deployment script
update_deployment_script() {
    print_step "Updating deployment script with your configuration..."
    
    project_id=$(gcloud config get-value project)
    
    # Update the PROJECT_ID in the deployment script
    if [ -f "deploy-production-gcp.sh" ]; then
        # Create a backup
        cp deploy-production-gcp.sh deploy-production-gcp.sh.backup
        
        # Update PROJECT_ID
        sed -i.bak "s/export PROJECT_ID=\"invoice-platform-prod\"/export PROJECT_ID=\"$project_id\"/" deploy-production-gcp.sh
        
        # Make sure it's executable
        chmod +x deploy-production-gcp.sh
        
        print_success "Deployment script updated with your project ID"
    else
        print_error "deploy-production-gcp.sh not found"
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo "🎉 Setup Complete!"
    echo "=================="
    echo ""
    print_success "Your Invoice Platform is ready for production deployment!"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. Review and update .env.production with your specific values"
    echo "2. Ensure your MongoDB Atlas cluster is properly configured"
    echo "3. Run the deployment script:"
    echo "   ./deploy-production-gcp.sh"
    echo ""
    echo "4. After deployment, configure your custom domain:"
    echo "   gcloud run domain-mappings create --service=api-gateway --domain=api.yourdomain.com"
    echo ""
    echo "5. Set up monitoring and logging in Google Cloud Console"
    echo ""
    print_warning "Important: Keep your .env.production file secure and never commit it to version control!"
    echo ""
    echo "📚 For detailed instructions, see: PRODUCTION_DEPLOYMENT.md"
}

# Main execution
main() {
    echo "This script will help you set up Invoice Platform for production deployment on Google Cloud Platform."
    echo ""
    
    check_prerequisites
    configure_project
    generate_jwt_secret
    configure_environment
    update_deployment_script
    show_next_steps
}

# Run the setup
main "$@"
