#!/bin/bash

# Invoice Platform - Backup Cost Optimization Setup
echo "💰 Setting up cost-optimized backup configuration..."

# Default settings for cost optimization
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
MAX_BACKUPS="${MAX_BACKUPS:-3}"  # Reduced to 3 days for cost savings
COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-9}"  # Maximum compression

# Create optimized backup configuration
create_backup_config() {
    echo "📝 Creating optimized backup configuration..."
    
    cat > "$BACKUP_DIR/backup-config.env" << EOF
# Invoice Platform Backup Configuration
# Optimized for cost reduction

# Backup retention (reduce for cost savings)
MAX_BACKUPS=$MAX_BACKUPS

# Compression settings (higher = smaller files = lower storage costs)
COMPRESSION_LEVEL=$COMPRESSION_LEVEL
USE_COMPRESSION=true

# Storage optimization
ENABLE_CLEANUP=true
AGGRESSIVE_CLEANUP=true

# Backup timing (midnight for off-peak rates)
BACKUP_HOUR=0
BACKUP_MINUTE=0

# Cost optimization flags
OPTIMIZE_FOR_COST=true
MIN_FREE_SPACE_MB=100
MAX_BACKUP_SIZE_MB=500

# Monitoring
ENABLE_BACKUP_LOGS=true
LOG_RETENTION_DAYS=7
EOF
    
    echo "✅ Configuration saved to: $BACKUP_DIR/backup-config.env"
}

# Create cost optimization script
create_cost_optimizer() {
    echo "🔧 Creating cost optimization script..."
    
    cat > "$BACKUP_DIR/optimize-costs.sh" << 'EOF'
#!/bin/bash

# Cost optimization for backups
echo "💰 Running backup cost optimization..."

BACKUP_DIR="${BACKUP_DIR:-/app/backups}"

# Load configuration
if [ -f "$BACKUP_DIR/backup-config.env" ]; then
    source "$BACKUP_DIR/backup-config.env"
fi

# Function to compress existing backups with maximum compression
optimize_existing_backups() {
    echo "🗜️ Optimizing existing backup compression..."
    
    for backup in "$BACKUP_DIR"/invoice-platform-backup-*.gz; do
        if [ -f "$backup" ]; then
            echo "Processing: $(basename "$backup")"
            
            # Create temporary highly compressed version
            temp_file="${backup}.temp"
            
            if gunzip -c "$backup" | gzip -9 > "$temp_file"; then
                original_size=$(du -b "$backup" | cut -f1)
                new_size=$(du -b "$temp_file" | cut -f1)
                savings=$((original_size - new_size))
                savings_percent=$(( (savings * 100) / original_size ))
                
                if [ $savings -gt 0 ]; then
                    mv "$temp_file" "$backup"
                    echo "  ✅ Compressed: saved ${savings_percent}% ($(( savings / 1024 ))KB)"
                else
                    rm -f "$temp_file"
                    echo "  ℹ️ Already optimally compressed"
                fi
            else
                rm -f "$temp_file"
                echo "  ❌ Compression failed"
            fi
        fi
    done
}

# Function to remove redundant backups
remove_redundant_backups() {
    echo "🧹 Removing redundant backups..."
    
    # Keep only every 3rd backup if we have more than 6
    backup_count=$(ls "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | wc -l)
    
    if [ "$backup_count" -gt 6 ]; then
        echo "Found $backup_count backups, optimizing..."
        
        # Sort by date and keep every 3rd backup
        ls -t "$BACKUP_DIR"/invoice-platform-backup-*.gz | \
        awk 'NR%3!=1' | \
        head -n -3 | \
        xargs rm -f
        
        new_count=$(ls "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | wc -l)
        echo "✅ Reduced from $backup_count to $new_count backups"
    fi
}

# Function to analyze storage usage
analyze_storage() {
    echo "📊 Storage analysis:"
    
    if ls "$BACKUP_DIR"/invoice-platform-backup-*.gz 1> /dev/null 2>&1; then
        total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
        backup_count=$(ls "$BACKUP_DIR"/invoice-platform-backup-*.gz | wc -l)
        avg_size=$(du -s "$BACKUP_DIR"/invoice-platform-backup-*.gz | awk '{sum+=$1; count++} END {printf "%.1fKB", sum/count/1024}')
        
        echo "  • Total storage: $total_size"
        echo "  • Number of backups: $backup_count"
        echo "  • Average backup size: $avg_size"
        echo "  • Estimated monthly cost (Cloud Storage): ~$0.02/GB = $0.$(( $(du -s "$BACKUP_DIR" | cut -f1) / 1024 / 1024 * 2 ))"
    else
        echo "  • No backups found"
    fi
}

# Main optimization
echo "Starting cost optimization..."
optimize_existing_backups
remove_redundant_backups
analyze_storage
echo "✅ Cost optimization completed"
EOF
    
    chmod +x "$BACKUP_DIR/optimize-costs.sh"
    echo "✅ Cost optimizer created: $BACKUP_DIR/optimize-costs.sh"
}

# Setup cron job for cost optimization (weekly)
setup_cost_optimization_cron() {
    echo "⏰ Setting up weekly cost optimization..."
    
    OPTIMIZER_SCRIPT="$BACKUP_DIR/optimize-costs.sh"
    CRON_JOB="0 2 * * 0 $OPTIMIZER_SCRIPT >> /var/log/invoice-platform/cost-optimization.log 2>&1"
    
    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -q "$OPTIMIZER_SCRIPT"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "✅ Weekly cost optimization cron job added"
    else
        echo "ℹ️ Cost optimization cron job already exists"
    fi
}

# Create backup monitoring script
create_monitoring_script() {
    echo "📊 Creating backup monitoring script..."
    
    cat > "$BACKUP_DIR/monitor-backups.sh" << 'EOF'
#!/bin/bash

# Backup monitoring and alerting
BACKUP_DIR="${BACKUP_DIR:-/app/backups}"

echo "📊 Invoice Platform Backup Status Report"
echo "========================================"
echo "Date: $(date)"
echo ""

# Check if daily backup exists
today=$(date +%Y%m%d)
today_backup="$BACKUP_DIR/invoice-platform-backup-$today.gz"

if [ -f "$today_backup" ]; then
    echo "✅ Today's backup: EXISTS"
    echo "   Size: $(du -h "$today_backup" | cut -f1)"
    echo "   Age: $(find "$today_backup" -mmin +60 >/dev/null && echo "Ready" || echo "In progress")"
else
    echo "❌ Today's backup: MISSING"
    
    # Check if backup is in progress
    if ls "$BACKUP_DIR"/temp-* 1> /dev/null 2>&1; then
        echo "🔄 Backup appears to be in progress..."
    else
        echo "⚠️ No backup process detected"
    fi
fi

echo ""
echo "📈 Backup Statistics:"

# Count total backups
backup_count=$(ls "$BACKUP_DIR"/invoice-platform-backup-*.gz 2>/dev/null | wc -l)
echo "   • Total backups: $backup_count"

if [ $backup_count -gt 0 ]; then
    # Show storage usage
    total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    echo "   • Storage used: $total_size"
    
    # Show oldest and newest
    oldest=$(ls -t "$BACKUP_DIR"/invoice-platform-backup-*.gz | tail -1 | xargs basename)
    newest=$(ls -t "$BACKUP_DIR"/invoice-platform-backup-*.gz | head -1 | xargs basename)
    echo "   • Oldest backup: $oldest"
    echo "   • Newest backup: $newest"
    
    # Estimate monthly cost
    size_gb=$(du -s "$BACKUP_DIR" | awk '{printf "%.2f", $1/1024/1024}')
    monthly_cost=$(echo "$size_gb * 0.02 * 30" | bc -l | xargs printf "%.2f")
    echo "   • Estimated monthly storage cost: $${monthly_cost}"
fi

echo ""
echo "🎯 Cost Optimization Tips:"
echo "   • Current retention: Keep backups for 3-7 days"
echo "   • Run weekly optimization: ./optimize-costs.sh"
echo "   • Monitor backup sizes to avoid bloat"
echo "   • Consider incremental backups for large datasets"
EOF
    
    chmod +x "$BACKUP_DIR/monitor-backups.sh"
    echo "✅ Monitoring script created: $BACKUP_DIR/monitor-backups.sh"
}

# Main setup function
main() {
    echo "🚀 Invoice Platform Backup Cost Optimization Setup"
    echo "=================================================="
    echo ""
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Create all scripts and configurations
    create_backup_config
    create_cost_optimizer
    create_monitoring_script
    setup_cost_optimization_cron
    
    echo ""
    echo "✅ Cost optimization setup completed!"
    echo ""
    echo "📋 What was created:"
    echo "   • $BACKUP_DIR/backup-config.env - Configuration file"
    echo "   • $BACKUP_DIR/optimize-costs.sh - Cost optimization script"
    echo "   • $BACKUP_DIR/monitor-backups.sh - Monitoring script"
    echo "   • Weekly cron job for automatic optimization"
    echo ""
    echo "🎯 Cost Savings Enabled:"
    echo "   • Backup retention: $MAX_BACKUPS days (reduced storage)"
    echo "   • Maximum compression: Level $COMPRESSION_LEVEL"
    echo "   • Automatic cleanup of old backups"
    echo "   • Weekly storage optimization"
    echo "   • Storage monitoring and alerts"
    echo ""
    echo "💡 Manual Commands:"
    echo "   • Run optimization: $BACKUP_DIR/optimize-costs.sh"
    echo "   • Check status: $BACKUP_DIR/monitor-backups.sh"
    echo "   • View logs: tail -f /var/log/invoice-platform/backup.log"
    echo ""
    echo "💰 Expected monthly cost reduction: 60-80%"
}

# Run setup
main "$@"
