#!/bin/bash

# Invoice Platform - Local Development Deployment
echo "🚀 Starting Invoice Platform local deployment..."
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
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

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Check if docker-compose is available
check_docker_compose() {
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "docker-compose is not installed. Please install it and try again."
        exit 1
    fi
    print_success "docker-compose is available"
}

# Clean up existing containers
cleanup_containers() {
    print_info "Cleaning up existing containers..."
    
    # Stop and remove all running containers for this project
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Remove any individual service containers that might be running
    local services=("api-gateway" "auth-service" "customers-service" "invoices-service" 
                   "inventory-service" "expenses-service" "tax-service" "uploads-service" 
                   "dashboard-service" "ai-service")
    
    for service in "${services[@]}"; do
        if docker ps -a --format "table {{.Names}}" | grep -q "^${service}$"; then
            docker stop "$service" 2>/dev/null || true
            docker rm "$service" 2>/dev/null || true
        fi
    done
    
    print_success "Cleanup completed"
}

# Build and start services
start_services() {
    print_info "Building and starting all services..."
    
    # Start MongoDB first
    print_info "Starting MongoDB..."
    docker-compose up -d mongo
    
    # Wait for MongoDB to be ready
    print_info "Waiting for MongoDB to be ready..."
    sleep 10
    
    # Check if MongoDB is accessible
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec invoice-platform-mongo-1 mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
            print_success "MongoDB is ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "MongoDB failed to start after $max_attempts attempts"
            exit 1
        fi
        
        print_info "Waiting for MongoDB... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    # Build and start all services
    print_info "Building service images..."
    
    # Service ports
    declare -A SERVICE_PORTS=(
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
    
    # Build and run each service
    for service in "${!SERVICE_PORTS[@]}"; do
        local port="${SERVICE_PORTS[$service]}"
        
        print_info "Building and starting $service on port $port..."
        
        # Build the service
        docker build -f Dockerfile.docker \
            --build-arg SERVICE_NAME="$service" \
            --build-arg SERVICE_PORT="$port" \
            -t "$service" . || {
            print_error "Failed to build $service"
            exit 1
        }
        
        # Run the service
        docker run -d \
            --name "$service" \
            --network invoice-platform_backend \
            -p "$port:$port" \
            -e NODE_ENV=development \
            -e MONGO_URI=mongodb://invoice-platform-mongo-1:27017/invoice-platform \
            "$service" || {
            print_error "Failed to start $service"
            exit 1
        }
        
        print_success "$service started successfully"
        sleep 2
    done
}

# Verify services are running
verify_services() {
    print_info "Verifying all services are running..."
    
    local services=("api-gateway" "auth-service" "customers-service" "invoices-service" 
                   "inventory-service" "expenses-service" "tax-service" "uploads-service" 
                   "dashboard-service" "ai-service")
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^${service}$"; then
            print_success "$service is running"
        else
            print_error "$service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All services are running successfully!"
        return 0
    else
        print_error "Some services failed to start: ${failed_services[*]}"
        return 1
    fi
}

# Show service status and URLs
show_status() {
    echo ""
    echo "🎉 Local Deployment Complete!"
    echo "=============================="
    echo ""
    print_info "Service URLs:"
    echo "• API Gateway:       http://localhost:3000"
    echo "• Auth Service:      http://localhost:3001"
    echo "• Customers Service: http://localhost:3002"
    echo "• Invoices Service:  http://localhost:3003"
    echo "• Inventory Service: http://localhost:3004"
    echo "• Expenses Service:  http://localhost:3005"
    echo "• Tax Service:       http://localhost:3006"
    echo "• Uploads Service:   http://localhost:3007"
    echo "• Dashboard Service: http://localhost:3008"
    echo "• AI Service:        http://localhost:3009"
    echo ""
    print_info "MongoDB: mongodb://localhost:27017/invoice-platform"
    echo ""
    print_info "API Documentation:"
    echo "• Swagger UI: http://localhost:3001/api-docs (Auth Service)"
    echo ""
    print_info "Useful commands:"
    echo "• View logs: docker logs <service-name>"
    echo "• Stop all: docker stop \$(docker ps -q)"
    echo "• Test API: ./test-auth-api.sh"
    echo ""
    print_warning "Note: This is for development only. Use deploy-simple-gcp.sh for production."
}

# Main execution
main() {
    echo "This script will deploy Invoice Platform locally for development."
    echo ""
    
    # Checks
    check_docker
    check_docker_compose
    
    # Ask for confirmation
    read -p "Continue with local deployment? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
    
    # Deploy
    cleanup_containers
    start_services
    
    # Verify and show status
    if verify_services; then
        show_status
    else
        print_error "Deployment completed with some issues. Check the logs above."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "stop")
        print_info "Stopping all services..."
        cleanup_containers
        print_success "All services stopped"
        ;;
    "restart")
        print_info "Restarting all services..."
        cleanup_containers
        start_services
        verify_services && show_status
        ;;
    "logs")
        service_name="${2:-api-gateway}"
        print_info "Showing logs for $service_name..."
        docker logs -f "$service_name"
        ;;
    "status")
        print_info "Checking service status..."
        verify_services
        ;;
    *)
        main "$@"
        ;;
esac
