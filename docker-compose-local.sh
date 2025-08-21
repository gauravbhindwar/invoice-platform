#!/bin/bash

# Invoice Platform - Docker Compose Local Deployment
echo "🐳 Starting Invoice Platform with Docker Compose..."
echo "==================================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Check prerequisites
check_prerequisites() {
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "docker-compose is not installed"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Main deployment function
deploy() {
    print_info "Stopping any existing services..."
    docker-compose down --remove-orphans
    
    print_info "Building and starting services..."
    docker-compose up -d --build
    
    print_info "Waiting for services to be ready..."
    sleep 15
    
    # Check service health
    local services=("mongo")
    local healthy=true
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            print_success "$service is running"
        else
            print_error "$service failed to start"
            healthy=false
        fi
    done
    
    if [ "$healthy" = true ]; then
        print_success "All services started successfully!"
        show_urls
    else
        print_error "Some services failed to start. Check logs with: docker-compose logs"
        exit 1
    fi
}

# Show service URLs
show_urls() {
    echo ""
    echo "🎉 Local Development Environment Ready!"
    echo "======================================"
    echo ""
    print_info "Available Services:"
    echo "• MongoDB:        mongodb://localhost:27017/invoice-platform"
    echo "• MongoDB Admin:  http://localhost:8081 (if mongo-express is configured)"
    echo ""
    print_info "Next Steps:"
    echo "1. Use individual service deployment: ./deploy-local.sh"
    echo "2. Or manually start services for development"
    echo ""
    print_info "Useful Commands:"
    echo "• View logs:     docker-compose logs -f [service]"
    echo "• Stop services: docker-compose down"
    echo "• Restart:       docker-compose restart [service]"
    echo ""
}

# Handle different commands
case "${1:-}" in
    "down"|"stop")
        print_info "Stopping all services..."
        docker-compose down
        print_success "All services stopped"
        ;;
    "logs")
        service_name="${2:-}"
        if [ -n "$service_name" ]; then
            docker-compose logs -f "$service_name"
        else
            docker-compose logs -f
        fi
        ;;
    "restart")
        print_info "Restarting services..."
        docker-compose restart
        ;;
    "build")
        print_info "Rebuilding services..."
        docker-compose build --no-cache
        ;;
    "status")
        print_info "Service status:"
        docker-compose ps
        ;;
    *)
        check_prerequisites
        deploy
        ;;
esac
