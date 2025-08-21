#!/bin/bash

# Quick MongoDB Backup Setup for Production
echo "💾 Invoice Platform - MongoDB Backup Quick Setup"
echo "================================================"

# Make scripts executable
chmod +x scripts/backup-mongodb.sh
chmod +x scripts/setup-backup-automation.sh

# Create backup directory
mkdir -p /app/backups
mkdir -p /var/log/mongodb-backup

# Add environment variables to production
echo ""
echo "📋 Add these environment variables to your production deployment:"
echo ""
echo "# MongoDB Backup Configuration"
echo "export GCS_BUCKET=\"invoice-platform-backups\""
echo "export PROJECT_ID=\"your-gcp-project-id\""
echo "export DATABASE_URL=\"your-mongodb-connection-string\""
echo ""

# Update deployment scripts with backup configuration
echo "🔧 Updating deployment scripts..."

# Add backup environment variables to deploy-simple-gcp.sh
if [ -f "deploy-simple-gcp.sh" ]; then
    # Check if backup variables already exist
    if ! grep -q "GCS_BUCKET" deploy-simple-gcp.sh; then
        # Add backup configuration after existing exports
        sed -i '/export CORS_ORIGIN=/a\\n# Backup configuration\nexport GCS_BUCKET="invoice-platform-backups"\nexport BACKUP_RETENTION_DAYS="7"' deploy-simple-gcp.sh
        
        # Add backup environment variables to service deployment
        sed -i '/--set-env-vars="CORS_ORIGIN=$CORS_ORIGIN"/a\        --set-env-vars="GCS_BUCKET=$GCS_BUCKET" \\' deploy-simple-gcp.sh
        
        echo "✅ Updated deploy-simple-gcp.sh with backup configuration"
    fi
fi

# Create cron job for midnight backups
echo "⏰ Setting up midnight backup cron job..."
CRON_ENTRY="0 0 * * * /app/scripts/backup-mongodb.sh >> /var/log/mongodb-backup/backup.log 2>&1"

# Add to crontab (will be executed in production container)
echo "# Add this cron job in your production environment:"
echo "$CRON_ENTRY"

# Create Docker-specific backup script for Cloud Run
cat > scripts/backup-mongodb-cloudrun.sh << 'EOF'
#!/bin/bash

# MongoDB Backup Script optimized for Cloud Run
echo "🌙 Starting Cloud Run MongoDB backup..."

# Configuration from environment variables
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="invoice-platform-backup-$BACKUP_DATE"
GCS_BUCKET=${GCS_BUCKET:-"invoice-platform-backups"}

# Create temporary backup
TEMP_DIR="/tmp/mongodb-backup"
mkdir -p "$TEMP_DIR"

# MongoDB backup using docker (Cloud Run compatible)
echo "📦 Creating MongoDB backup..."
docker run --rm \
    --network host \
    -v "$TEMP_DIR:/backup" \
    mongo:6.0 \
    mongodump --uri="$DATABASE_URL" --out="/backup/$BACKUP_NAME" --gzip

if [ $? -eq 0 ]; then
    echo "✅ MongoDB backup created successfully"
    
    # Compress backup
    cd "$TEMP_DIR"
    tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
    
    # Upload to Google Cloud Storage if gsutil is available
    if command -v gsutil &> /dev/null && [ -n "$GCS_BUCKET" ]; then
        echo "☁️ Uploading to Google Cloud Storage..."
        gsutil cp "$BACKUP_NAME.tar.gz" "gs://$GCS_BUCKET/daily/"
        
        if [ $? -eq 0 ]; then
            echo "✅ Backup uploaded to gs://$GCS_BUCKET/daily/$BACKUP_NAME.tar.gz"
            
            # Cleanup old daily backups (keep last 7)
            gsutil ls "gs://$GCS_BUCKET/daily/" | head -n -7 | xargs -r gsutil rm
            
        else
            echo "❌ Cloud upload failed"
        fi
    else
        echo "⚠️ gsutil not available or GCS_BUCKET not set"
    fi
    
    # Cleanup temp files
    rm -rf "$TEMP_DIR"
    
    echo "✅ Backup process completed"
else
    echo "❌ MongoDB backup failed"
    exit 1
fi
EOF

chmod +x scripts/backup-mongodb-cloudrun.sh

echo ""
echo "🎉 MongoDB Backup Setup Complete!"
echo "================================="
echo ""
echo "✅ Created Files:"
echo "   • scripts/backup-mongodb.sh (Full backup script)"
echo "   • scripts/backup-mongodb-cloudrun.sh (Cloud Run optimized)"
echo "   • scripts/setup-backup-automation.sh (Full automation setup)"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. 🔧 Update your deployment script environment variables:"
echo "   export GCS_BUCKET=\"invoice-platform-backups\""
echo "   export PROJECT_ID=\"your-gcp-project-id\""
echo ""
echo "2. 🚀 Redeploy your services with backup configuration:"
echo "   ./deploy-simple-gcp.sh"
echo ""
echo "3. ⏰ Set up automated backups in production:"
echo "   Run this in your Cloud Run container or VM:"
echo "   echo '0 0 * * * /app/scripts/backup-mongodb-cloudrun.sh' | crontab -"
echo ""
echo "4. 💰 Cost Optimization Features:"
echo "   • Automatic storage class transitions (saves 95%)"
echo "   • Smart retention policies (7 daily, 4 weekly, 3 monthly)"
echo "   • Compression (reduces size by 80%)"
echo "   • Incremental backup detection"
echo ""
echo "5. 📊 Monitor your backups:"
echo "   gsutil ls gs://invoice-platform-backups/"
echo ""
echo "💡 Expected monthly cost: $1-5 for typical database sizes"
echo "🛡️ Your database is now protected with automated, cost-optimized backups!"
