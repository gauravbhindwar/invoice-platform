#!/bin/bash

# Invoice Platform - Daily MongoDB Backup Script
# Runs once per day at midnight with cost optimization

echo "🌙 Starting daily MongoDB backup at $(date)"

# Configuration
BACKUP_DIR="/app/backups"
MAX_BACKUPS=7  # Keep only 7 days of backups
DATE=$(date +%Y%m%d)
BACKUP_FILE="invoice-platform-backup-$DATE.gz"

# MongoDB connection (use environment variables)
MONGO_URI=${DATABASE_URL:-"mongodb://localhost:27017/invoice-platform"}
DB_NAME="invoice-platform"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to cleanup old backups (keep only last 7 days)
cleanup_old_backups() {
    echo "🧹 Cleaning up old backups (keeping last $MAX_BACKUPS days)..."
    
    # Find and delete backup files older than MAX_BACKUPS days
    find "$BACKUP_DIR" -name "invoice-platform-backup-*.gz" -type f -mtime +$MAX_BACKUPS -delete
    
    # Also clean up any backup folders older than MAX_BACKUPS days
    find "$BACKUP_DIR" -name "backup-*" -type d -mtime +$MAX_BACKUPS -exec rm -rf {} \; 2>/dev/null || true
    
    echo "✅ Cleanup completed"
}

# Function to create compressed backup
create_backup() {
    echo "📦 Creating MongoDB backup..."
    
    # Create temporary directory for this backup
    TEMP_DIR="$BACKUP_DIR/temp-$DATE"
    mkdir -p "$TEMP_DIR"
    
    # Create MongoDB dump
    if mongodump --uri="$MONGO_URI" --db="$DB_NAME" --out="$TEMP_DIR" --quiet; then
        echo "✅ MongoDB dump created successfully"
        
        # Compress the backup
        echo "🗜️ Compressing backup..."
        tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$TEMP_DIR" .
        
        # Remove temporary directory
        rm -rf "$TEMP_DIR"
        
        # Get backup file size
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        echo "✅ Backup created: $BACKUP_FILE (Size: $BACKUP_SIZE)"
        
        return 0
    else
        echo "❌ MongoDB dump failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi
}

# Function to check available disk space
check_disk_space() {
    # Check if backup directory has enough space (at least 1GB free)
    AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=1048576  # 1GB in KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        echo "⚠️ Warning: Low disk space. Available: $(($AVAILABLE_SPACE/1024))MB"
        echo "🧹 Performing aggressive cleanup..."
        
        # Keep only last 3 backups if space is low
        find "$BACKUP_DIR" -name "invoice-platform-backup-*.gz" -type f | sort | head -n -3 | xargs rm -f
    fi
}

# Function to verify backup integrity
verify_backup() {
    local backup_file="$1"
    
    echo "🔍 Verifying backup integrity..."
    
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        echo "✅ Backup integrity verified"
        return 0
    else
        echo "❌ Backup integrity check failed"
        return 1
    fi
}

# Main backup process
main() {
    echo "🚀 Invoice Platform Daily Backup"
    echo "================================"
    echo "Date: $(date)"
    echo "Database: $DB_NAME"
    echo "Backup Directory: $BACKUP_DIR"
    echo ""
    
    # Check if backup already exists for today
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        echo "ℹ️ Backup for today already exists: $BACKUP_FILE"
        echo "✅ Daily backup completed (existing)"
        exit 0
    fi
    
    # Check disk space before starting
    check_disk_space
    
    # Clean up old backups first to free space
    cleanup_old_backups
    
    # Create the backup
    if create_backup; then
        # Verify the backup
        if verify_backup "$BACKUP_DIR/$BACKUP_FILE"; then
            echo "✅ Daily backup completed successfully"
            echo "📊 Backup Summary:"
            echo "   - File: $BACKUP_FILE"
            echo "   - Size: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
            echo "   - Location: $BACKUP_DIR"
            echo "   - Total backups: $(ls -1 "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | wc -l)"
        else
            echo "❌ Backup verification failed, removing corrupted backup"
            rm -f "$BACKUP_DIR/$BACKUP_FILE"
            exit 1
        fi
    else
        echo "❌ Backup creation failed"
        exit 1
    fi
}

# Run main function
main "$@"
