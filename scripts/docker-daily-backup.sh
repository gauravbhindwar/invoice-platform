#!/bin/bash

# Invoice Platform - Docker Daily Backup Script
# Optimized for containerized environments

echo "🐳 Starting containerized daily backup at $(date)"

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
MAX_BACKUPS=${MAX_BACKUPS:-7}  # Keep only 7 days
DATE=$(date +%Y%m%d)
BACKUP_FILE="invoice-platform-backup-$DATE.gz"

# MongoDB connection from environment
MONGO_URI=${DATABASE_URL:-$MONGO_URI}
DB_NAME=${DB_NAME:-"invoice-platform"}

# Check if running in container
if [ -f /.dockerenv ]; then
    echo "🐳 Running in Docker container"
    CONTAINER_MODE=true
else
    echo "💻 Running on host system"
    CONTAINER_MODE=false
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to get MongoDB connection details from URI
parse_mongo_uri() {
    if [[ $MONGO_URI == mongodb+srv://* ]]; then
        echo "☁️ Using MongoDB Atlas connection"
        # For Atlas, we'll use mongodump with the full URI
        DUMP_COMMAND="mongodump --uri='$MONGO_URI'"
    elif [[ $MONGO_URI == mongodb://* ]]; then
        echo "🏠 Using MongoDB connection"
        DUMP_COMMAND="mongodump --uri='$MONGO_URI'"
    else
        echo "❌ Invalid MongoDB URI format"
        exit 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    echo "🧹 Cleaning up old backups (keeping last $MAX_BACKUPS days)..."
    
    cd "$BACKUP_DIR" || exit 1
    
    # Remove backups older than MAX_BACKUPS days
    if ls invoice-platform-backup-*.gz 1> /dev/null 2>&1; then
        # Keep only the most recent MAX_BACKUPS files
        ls -t invoice-platform-backup-*.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
        
        REMAINING=$(ls invoice-platform-backup-*.gz 2>/dev/null | wc -l)
        echo "✅ Cleanup completed. Backups remaining: $REMAINING"
    else
        echo "ℹ️ No existing backups found"
    fi
}

# Create backup
create_backup() {
    echo "📦 Creating MongoDB backup for database: $DB_NAME"
    
    # Check if backup already exists for today
    if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
        echo "ℹ️ Backup for today already exists: $BACKUP_FILE"
        echo "   Size: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
        return 0
    fi
    
    # Create temporary directory
    TEMP_DIR="$BACKUP_DIR/temp-$DATE-$$"
    mkdir -p "$TEMP_DIR"
    
    # Parse MongoDB URI and create dump command
    parse_mongo_uri
    
    # Execute backup
    echo "🔄 Executing: $DUMP_COMMAND"
    if eval "$DUMP_COMMAND --out='$TEMP_DIR' --quiet"; then
        echo "✅ MongoDB dump completed"
        
        # Compress the backup
        echo "🗜️ Compressing backup..."
        if tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$TEMP_DIR" .; then
            # Get file size
            BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
            echo "✅ Backup compressed: $BACKUP_FILE (Size: $BACKUP_SIZE)"
            
            # Verify backup
            if tar -tzf "$BACKUP_DIR/$BACKUP_FILE" >/dev/null 2>&1; then
                echo "✅ Backup integrity verified"
                rm -rf "$TEMP_DIR"
                return 0
            else
                echo "❌ Backup integrity check failed"
                rm -f "$BACKUP_DIR/$BACKUP_FILE"
                rm -rf "$TEMP_DIR"
                return 1
            fi
        else
            echo "❌ Backup compression failed"
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        echo "❌ MongoDB dump failed"
        rm -rf "$TEMP_DIR"
        return 1
    fi
}

# Check disk space and optimize if needed
optimize_storage() {
    echo "💾 Checking storage optimization..."
    
    # Get available space in MB
    AVAILABLE_MB=$(df "$BACKUP_DIR" | awk 'NR==2 {print int($4/1024)}')
    echo "📊 Available space: ${AVAILABLE_MB}MB"
    
    # If less than 500MB available, be more aggressive with cleanup
    if [ "$AVAILABLE_MB" -lt 500 ]; then
        echo "⚠️ Low disk space detected. Aggressive cleanup..."
        MAX_BACKUPS=3  # Keep only 3 days when space is low
        cleanup_old_backups
        
        # Also clean any temp files
        find "$BACKUP_DIR" -name "temp-*" -type d -mtime +1 -exec rm -rf {} \; 2>/dev/null || true
        find "$BACKUP_DIR" -name "*.tmp" -type f -mtime +1 -delete 2>/dev/null || true
    fi
}

# Main function
main() {
    echo "🌙 Invoice Platform Daily Backup"
    echo "================================"
    echo "📅 Date: $(date)"
    echo "🗄️ Database: $DB_NAME"
    echo "📁 Backup Directory: $BACKUP_DIR"
    echo "🔄 Retention: $MAX_BACKUPS days"
    echo ""
    
    # Validate MongoDB URI
    if [ -z "$MONGO_URI" ]; then
        echo "❌ Error: DATABASE_URL or MONGO_URI environment variable not set"
        exit 1
    fi
    
    # Check if mongodump is available
    if ! command -v mongodump &> /dev/null; then
        echo "❌ Error: mongodump not found. Please install MongoDB tools"
        exit 1
    fi
    
    # Optimize storage first
    optimize_storage
    
    # Clean up old backups
    cleanup_old_backups
    
    # Create new backup
    if create_backup; then
        echo ""
        echo "🎉 Daily backup completed successfully!"
        echo "📊 Backup Summary:"
        echo "   • File: $BACKUP_FILE"
        echo "   • Size: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1 2>/dev/null || echo 'Unknown')"
        echo "   • Total backups: $(ls -1 "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | wc -l)"
        echo "   • Storage used: $(du -sh "$BACKUP_DIR" | cut -f1)"
        
        # Show backup schedule info
        echo ""
        echo "⏰ Next backup: Tomorrow at midnight"
        echo "🗂️ Retention policy: $MAX_BACKUPS days"
        
        exit 0
    else
        echo "❌ Daily backup failed!"
        exit 1
    fi
}

# Execute main function
main "$@"
