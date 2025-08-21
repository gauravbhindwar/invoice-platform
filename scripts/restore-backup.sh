#!/bin/bash

# Invoice Platform - Backup Restore Script
echo "🔄 Invoice Platform Backup Restore Utility"
echo "==========================================="

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
MONGO_URI=${DATABASE_URL:-$MONGO_URI}
DB_NAME=${DB_NAME:-"invoice-platform"}

# Function to list available backups
list_backups() {
    echo "📂 Available backups in $BACKUP_DIR:"
    echo ""
    
    if ls "$BACKUP_DIR"/invoice-platform-backup-*.gz 1> /dev/null 2>&1; then
        echo "Date       | Size    | File"
        echo "-----------|---------|------------------"
        
        for backup in "$BACKUP_DIR"/invoice-platform-backup-*.gz; do
            filename=$(basename "$backup")
            date_part=$(echo "$filename" | sed 's/invoice-platform-backup-\([0-9]\{8\}\)\.gz/\1/')
            formatted_date=$(echo "$date_part" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
            size=$(du -h "$backup" | cut -f1)
            echo "$formatted_date | $size   | $filename"
        done
    else
        echo "❌ No backups found in $BACKUP_DIR"
        exit 1
    fi
    echo ""
}

# Function to restore from a specific backup
restore_backup() {
    local backup_file="$1"
    local backup_path="$BACKUP_DIR/$backup_file"
    
    # Validate backup file exists
    if [ ! -f "$backup_path" ]; then
        echo "❌ Backup file not found: $backup_path"
        exit 1
    fi
    
    # Verify backup integrity
    echo "🔍 Verifying backup integrity..."
    if ! tar -tzf "$backup_path" >/dev/null 2>&1; then
        echo "❌ Backup file is corrupted: $backup_file"
        exit 1
    fi
    echo "✅ Backup integrity verified"
    
    # Create temporary directory for extraction
    TEMP_DIR="/tmp/restore-$(date +%s)"
    mkdir -p "$TEMP_DIR"
    
    echo "📦 Extracting backup..."
    if tar -xzf "$backup_path" -C "$TEMP_DIR"; then
        echo "✅ Backup extracted successfully"
    else
        echo "❌ Failed to extract backup"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Confirm restore operation
    echo ""
    echo "⚠️  WARNING: This will replace all data in database '$DB_NAME'"
    echo "📂 Backup file: $backup_file"
    echo "🗄️ Target database: $DB_NAME"
    echo "🔗 MongoDB URI: ${MONGO_URI:0:50}..."
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "❌ Restore cancelled by user"
        rm -rf "$TEMP_DIR"
        exit 0
    fi
    
    # Drop existing database (optional, comment out if you want to merge)
    echo "🗑️ Dropping existing database..."
    mongosh "$MONGO_URI" --eval "db.dropDatabase()" --quiet
    
    # Restore from backup
    echo "🔄 Restoring database from backup..."
    if mongorestore --uri="$MONGO_URI" --db="$DB_NAME" "$TEMP_DIR/$DB_NAME" --quiet; then
        echo "✅ Database restored successfully!"
        
        # Cleanup
        rm -rf "$TEMP_DIR"
        
        # Show restore summary
        echo ""
        echo "🎉 Restore completed!"
        echo "📊 Restore Summary:"
        echo "   • Source: $backup_file"
        echo "   • Target: $DB_NAME"
        echo "   • Date: $(date)"
        
    else
        echo "❌ Database restore failed"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

# Function to show latest backup info
show_latest_backup() {
    local latest_backup=$(ls -t "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | head -1)
    
    if [ -n "$latest_backup" ]; then
        echo "📊 Latest Backup Information:"
        echo "   • File: $(basename "$latest_backup")"
        echo "   • Size: $(du -h "$latest_backup" | cut -f1)"
        echo "   • Date: $(stat -c %y "$latest_backup" | cut -d' ' -f1)"
        echo "   • Age: $(find "$latest_backup" -mtime -1 >/dev/null && echo "< 1 day" || echo "> 1 day")"
    else
        echo "❌ No backups found"
    fi
}

# Function to verify MongoDB connection
test_connection() {
    echo "🔌 Testing MongoDB connection..."
    
    if mongosh "$MONGO_URI" --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
        echo "✅ MongoDB connection successful"
        return 0
    else
        echo "❌ MongoDB connection failed"
        echo "Please check your DATABASE_URL or MONGO_URI"
        return 1
    fi
}

# Main menu
show_menu() {
    echo "🔧 Backup Restore Options:"
    echo "1. List all available backups"
    echo "2. Restore from latest backup"
    echo "3. Restore from specific backup"
    echo "4. Show latest backup info"
    echo "5. Test MongoDB connection"
    echo "6. Exit"
    echo ""
}

# Main function
main() {
    # Validate environment
    if [ -z "$MONGO_URI" ]; then
        echo "❌ Error: DATABASE_URL or MONGO_URI environment variable not set"
        exit 1
    fi
    
    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    # If backup file provided as argument, restore it directly
    if [ $# -eq 1 ]; then
        restore_backup "$1"
        exit 0
    fi
    
    # Interactive mode
    while true; do
        show_menu
        read -p "Select an option (1-6): " choice
        echo ""
        
        case $choice in
            1)
                list_backups
                ;;
            2)
                latest_backup=$(ls -t "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | head -1)
                if [ -n "$latest_backup" ]; then
                    restore_backup "$(basename "$latest_backup")"
                else
                    echo "❌ No backups found"
                fi
                ;;
            3)
                list_backups
                read -p "Enter backup filename: " backup_name
                restore_backup "$backup_name"
                ;;
            4)
                show_latest_backup
                ;;
            5)
                test_connection
                ;;
            6)
                echo "👋 Goodbye!"
                exit 0
                ;;
            *)
                echo "❌ Invalid option. Please select 1-6."
                ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Run main function
main "$@"
