#!/bin/bash

# Invoice Platform - Automated MongoDB Backup Script
# Runs at midnight to create backups and manage retention
echo "🌙 Starting midnight MongoDB backup process..."

# Configuration
BACKUP_DIR="/app/backups"
TEMP_DIR="/tmp/mongodb-backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="invoice-platform-backup-$DATE"

# Retention settings (cost optimization)
KEEP_DAILY_BACKUPS=7      # Keep 7 daily backups
KEEP_WEEKLY_BACKUPS=4     # Keep 4 weekly backups (1 month)
KEEP_MONTHLY_BACKUPS=3    # Keep 3 monthly backups

# MongoDB connection (from environment variables)
MONGO_URI=${DATABASE_URL:-"mongodb://localhost:27017/invoice-platform"}
DATABASE_NAME="invoice-platform"

# Google Cloud Storage settings (for cost-effective storage)
GCS_BUCKET="invoice-platform-backups"
GCS_PROJECT=${PROJECT_ID:-"invoice-platform-prod"}

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to create local backup
create_local_backup() {
    log "📦 Creating local MongoDB backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Create backup using mongodump
    if command -v mongodump &> /dev/null; then
        mongodump --uri="$MONGO_URI" --out="$TEMP_DIR/$BACKUP_NAME" --gzip
    else
        # If mongodump is not available, use docker
        docker run --rm -v "$TEMP_DIR:/backup" mongo:6.0 \
            mongodump --uri="$MONGO_URI" --out="/backup/$BACKUP_NAME" --gzip
    fi
    
    if [ $? -eq 0 ]; then
        log "✅ Local backup created successfully"
        
        # Compress the backup for storage efficiency
        cd "$TEMP_DIR"
        tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
        
        # Calculate backup size
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
        log "📊 Backup size: $BACKUP_SIZE"
        
        # Cleanup temp directory
        rm -rf "$TEMP_DIR/$BACKUP_NAME"
        
        return 0
    else
        log "❌ Local backup failed"
        return 1
    fi
}

# Function to upload to Google Cloud Storage (cost-effective)
upload_to_gcs() {
    local backup_file="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    
    log "☁️ Uploading backup to Google Cloud Storage..."
    
    # Check if gsutil is available
    if ! command -v gsutil &> /dev/null; then
        log "⚠️ gsutil not found, skipping cloud upload"
        return 1
    fi
    
    # Create bucket if it doesn't exist (with cost-optimized settings)
    gsutil ls -b gs://$GCS_BUCKET &>/dev/null || {
        log "📂 Creating GCS bucket with cost-optimized settings..."
        gsutil mb -p "$GCS_PROJECT" -c STANDARD -l asia-south1 gs://$GCS_BUCKET
        
        # Set lifecycle policy for automatic cleanup (cost optimization)
        cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 7}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 30}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "ARCHIVE"},
        "condition": {"age": 90}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365}
      }
    ]
  }
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json gs://$GCS_BUCKET
        rm /tmp/lifecycle.json
    }
    
    # Upload with compression and metadata
    gsutil -m cp "$backup_file" gs://$GCS_BUCKET/daily/ \
        -h "Content-Encoding:gzip" \
        -h "x-goog-meta-database:$DATABASE_NAME" \
        -h "x-goog-meta-backup-type:automated" \
        -h "x-goog-meta-created:$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    if [ $? -eq 0 ]; then
        log "✅ Backup uploaded to gs://$GCS_BUCKET/daily/$BACKUP_NAME.tar.gz"
        return 0
    else
        log "❌ Cloud upload failed"
        return 1
    fi
}

# Function to cleanup old local backups (cost optimization)
cleanup_local_backups() {
    log "🧹 Cleaning up old local backups..."
    
    # Keep only the last N daily backups
    ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +$((KEEP_DAILY_BACKUPS + 1)) | xargs -r rm -f
    
    local removed_count=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +$((KEEP_DAILY_BACKUPS + 1)) | wc -l)
    if [ $removed_count -gt 0 ]; then
        log "🗑️ Removed $removed_count old local backups"
    fi
}

# Function to manage cloud backup retention (cost optimization)
manage_cloud_retention() {
    log "📅 Managing cloud backup retention..."
    
    if ! command -v gsutil &> /dev/null; then
        log "⚠️ gsutil not found, skipping cloud retention management"
        return 1
    fi
    
    local current_date=$(date +%Y%m%d)
    local day_of_week=$(date +%u)  # 1=Monday, 7=Sunday
    local day_of_month=$(date +%d)
    
    # Weekly backup management (every Sunday)
    if [ "$day_of_week" -eq 7 ]; then
        log "📦 Creating weekly backup copy..."
        gsutil cp "gs://$GCS_BUCKET/daily/$BACKUP_NAME.tar.gz" "gs://$GCS_BUCKET/weekly/"
        
        # Clean old weekly backups
        gsutil ls gs://$GCS_BUCKET/weekly/ | head -n -$KEEP_WEEKLY_BACKUPS | xargs -r gsutil rm
    fi
    
    # Monthly backup management (first day of month)
    if [ "$day_of_month" -eq "01" ]; then
        log "📦 Creating monthly backup copy..."
        gsutil cp "gs://$GCS_BUCKET/daily/$BACKUP_NAME.tar.gz" "gs://$GCS_BUCKET/monthly/"
        
        # Clean old monthly backups
        gsutil ls gs://$GCS_BUCKET/monthly/ | head -n -$KEEP_MONTHLY_BACKUPS | xargs -r gsutil rm
    fi
}

# Function to optimize backup for cost
optimize_backup() {
    log "⚡ Optimizing backup for cost efficiency..."
    
    # Check if backup is necessary (skip if no changes since last backup)
    local last_backup_date=""
    if [ -f "$BACKUP_DIR/.last_backup_date" ]; then
        last_backup_date=$(cat "$BACKUP_DIR/.last_backup_date")
    fi
    
    # Get MongoDB last modified time (if oplog is available)
    local current_oplog_time=""
    if command -v mongo &> /dev/null; then
        current_oplog_time=$(mongo "$MONGO_URI" --quiet --eval "
            db = db.getSiblingDB('local');
            var latest = db.oplog.rs.find().sort({ts: -1}).limit(1).toArray()[0];
            if (latest) print(latest.ts.getTime());
        " 2>/dev/null)
    fi
    
    # Skip backup if no changes detected
    if [ -n "$current_oplog_time" ] && [ -n "$last_backup_date" ]; then
        if [ "$current_oplog_time" -eq "$last_backup_date" ]; then
            log "ℹ️ No changes detected since last backup, skipping..."
            return 0
        fi
    fi
    
    # Record current timestamp for next comparison
    echo "$current_oplog_time" > "$BACKUP_DIR/.last_backup_date"
    return 1  # Proceed with backup
}

# Function to send backup notifications (optional)
send_notification() {
    local status=$1
    local message=$2
    
    # You can integrate with Slack, email, or other notification services
    log "📱 Notification: $message"
    
    # Example: Send to webhook (uncomment and configure)
    # curl -X POST -H 'Content-type: application/json' \
    #     --data "{\"text\":\"MongoDB Backup: $message\"}" \
    #     "$SLACK_WEBHOOK_URL"
}

# Function to get backup statistics
get_backup_stats() {
    log "📊 Backup Statistics:"
    
    # Local backup count and size
    local local_count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    local local_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    log "   Local backups: $local_count files, $local_size total"
    
    # Cloud backup info (if available)
    if command -v gsutil &> /dev/null; then
        local cloud_daily=$(gsutil ls gs://$GCS_BUCKET/daily/ 2>/dev/null | wc -l)
        local cloud_weekly=$(gsutil ls gs://$GCS_BUCKET/weekly/ 2>/dev/null | wc -l)
        local cloud_monthly=$(gsutil ls gs://$GCS_BUCKET/monthly/ 2>/dev/null | wc -l)
        log "   Cloud backups: $cloud_daily daily, $cloud_weekly weekly, $cloud_monthly monthly"
    fi
}

# Main backup process
main() {
    log "🚀 Starting automated MongoDB backup process"
    
    # Check if optimization allows backup to proceed
    if optimize_backup; then
        log "✅ Backup optimization complete - no backup needed"
        return 0
    fi
    
    # Create local backup
    if create_local_backup; then
        send_notification "SUCCESS" "Local backup created: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
        
        # Upload to cloud storage
        if upload_to_gcs; then
            send_notification "SUCCESS" "Backup uploaded to cloud storage"
        else
            send_notification "WARNING" "Cloud upload failed, backup stored locally only"
        fi
        
        # Manage retention policies
        cleanup_local_backups
        manage_cloud_retention
        
        # Show statistics
        get_backup_stats
        
        log "✅ Backup process completed successfully"
        send_notification "SUCCESS" "Midnight backup completed successfully"
    else
        log "❌ Backup process failed"
        send_notification "ERROR" "Backup process failed - please check logs"
        exit 1
    fi
}

# Run the backup process
main "$@"
