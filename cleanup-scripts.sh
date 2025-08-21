#!/bin/bash

# Script Cleanup - Remove Duplicates and Unused Files
echo "🧹 Cleaning up duplicate and unused script files..."
echo "=================================================="

# Function to safely remove files
safe_remove() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "🗑️  Removing: $file"
        rm "$file"
    else
        echo "⚠️  File not found: $file"
    fi
}

# Function to safely remove directories
safe_remove_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "🗑️  Removing directory: $dir"
        rm -rf "$dir"
    else
        echo "⚠️  Directory not found: $dir"
    fi
}

echo "📋 Files to be removed:"
echo ""

# Remove duplicate deployment scripts (keep only the essential ones)
echo "🔄 Removing duplicate deployment scripts..."
safe_remove "deploy-all.sh" 
safe_remove "deploy-fixed.sh"
safe_remove "deploy-gcp.sh"
safe_remove "deploy-optimized.sh"
safe_remove "test-deploy.sh"

# Remove duplicate Docker files
echo "🐳 Removing duplicate Docker files..."
safe_remove "Dockerfile.service"
safe_remove "docker-compose.optimized.yml"

# Remove development/testing scripts that are no longer needed
echo "🧪 Removing development/testing scripts..."
safe_remove "dev.sh"
safe_remove "docker-build-service.sh"
safe_remove "fix-docker-imports.sh"
safe_remove "migrate-services.sh"
safe_remove "status.sh"

# Remove duplicate backup scripts (keep only the essential ones)
echo "💾 Removing duplicate backup scripts..."
safe_remove "scripts/setup-backup-automation.sh"
safe_remove "scripts/setup-backup-cron.sh"
safe_remove "scripts/setup-backup-optimization.sh"
safe_remove "scripts/setup-backup-quick.sh"
safe_remove "scripts/env-manager.sh"

# Remove old/unused scripts
echo "🗂️  Removing old/unused scripts..."
safe_remove "scripts/mongo-init-dev.sh"
safe_remove "scripts/mongo-init.js"
safe_remove "scripts/mongobackup_bashCommand.txt"

# Remove duplicate documentation files
echo "📚 Removing duplicate documentation..."
safe_remove "README-OPTIMIZED.md"
safe_remove "QUICK_START.md"

# Remove empty setup script
safe_remove "setup-gcp-project.sh"

# Remove traefik directory if it exists (not needed for Cloud Run deployment)
safe_remove_dir "traefik"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📋 Remaining essential files:"
echo "=============================="
echo ""
echo "🚀 Deployment Scripts:"
echo "• deploy-production-gcp.sh    (Full production deployment)"
echo "• deploy-simple-gcp.sh        (Simple production deployment)"
echo "• deploy-local.sh             (Local development deployment)"
echo "• docker-compose-local.sh     (Docker Compose local deployment)"
echo "• setup-production.sh         (Interactive setup helper)"
echo ""
echo "🧹 Utility Scripts:"
echo "• cleanup.sh                  (Repository cleanup)"
echo "• test-auth-api.sh           (API testing)"
echo "• test-registration.sh       (Registration testing)"
echo ""
echo "💾 Backup Scripts:"
echo "• scripts/backup-mongodb.sh   (Manual backup)"
echo "• scripts/daily-backup.sh     (Daily automated backup)"
echo "• scripts/docker-daily-backup.sh (Docker backup)"
echo "• scripts/restore-backup.sh   (Backup restoration)"
echo ""
echo "📚 Documentation:"
echo "• PRODUCTION_DEPLOYMENT.md    (Complete deployment guide)"
echo "• QUICK_DEPLOY_GUIDE.md       (Quick deployment guide)"
echo "• SWAGGER_USER_GUIDE.md       (API documentation)"
echo "• API_GUIDE.md               (API usage guide)"
echo "• BACKUP_COST_OPTIMIZATION.md (Backup optimization)"
echo ""
echo "🔧 Configuration:"
echo "• docker-compose.yml          (Local development)"
echo "• Dockerfile.docker           (Production Docker)"
echo "• cloudbuild.yaml            (Google Cloud Build)"
echo "• .env.production.example     (Environment template)"
echo ""
echo "🎉 Your repository is now clean and optimized!"
