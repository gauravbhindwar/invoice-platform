#!/bin/bash

# Setup Automated MongoDB Backups with Cost Optimization
echo "⏰ Setting up automated MongoDB backup system..."

# Configuration
BACKUP_SCRIPT_PATH="/app/scripts/backup-mongodb.sh"
CRON_JOB_USER="root"
LOG_DIR="/var/log/mongodb-backup"

# Function to setup cron job
setup_cron_job() {
    echo "📅 Setting up cron job for midnight backups..."
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Create cron job entry
    CRON_ENTRY="0 0 * * * $BACKUP_SCRIPT_PATH >> $LOG_DIR/backup.log 2>&1"
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    
    echo "✅ Cron job added: Daily backup at midnight"
    echo "📋 Cron entry: $CRON_ENTRY"
}

# Function to setup log rotation (cost optimization)
setup_log_rotation() {
    echo "🔄 Setting up log rotation for cost optimization..."
    
    cat > /etc/logrotate.d/mongodb-backup << 'EOF'
/var/log/mongodb-backup/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        # Optional: Send backup summary
        /bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    echo "✅ Log rotation configured"
}

# Function to create systemd service (alternative to cron)
create_systemd_service() {
    echo "🔧 Creating systemd service and timer..."
    
    # Create service file
    cat > /etc/systemd/system/mongodb-backup.service << EOF
[Unit]
Description=MongoDB Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT_PATH
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file for midnight execution
    cat > /etc/systemd/system/mongodb-backup.timer << EOF
[Unit]
Description=MongoDB Backup Timer
Requires=mongodb-backup.service

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timer
    systemctl daemon-reload
    systemctl enable mongodb-backup.timer
    systemctl start mongodb-backup.timer
    
    echo "✅ Systemd service and timer created"
    echo "📋 Status: $(systemctl is-active mongodb-backup.timer)"
}

# Function to setup Google Cloud Storage with cost optimization
setup_gcs_cost_optimization() {
    echo "💰 Setting up Google Cloud Storage cost optimization..."
    
    local bucket_name="invoice-platform-backups"
    
    # Check if gsutil is available
    if ! command -v gsutil &> /dev/null; then
        echo "⚠️ gsutil not found. Install Google Cloud SDK first."
        return 1
    fi
    
    # Create lifecycle policy for automatic cost optimization
    cat > /tmp/gcs-lifecycle-policy.json << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "NEARLINE"
        },
        "condition": {
          "age": 7,
          "matchesStorageClass": ["STANDARD"]
        }
      },
      {
        "action": {
          "type": "SetStorageClass", 
          "storageClass": "COLDLINE"
        },
        "condition": {
          "age": 30,
          "matchesStorageClass": ["NEARLINE"]
        }
      },
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "ARCHIVE"
        },
        "condition": {
          "age": 90,
          "matchesStorageClass": ["COLDLINE"]
        }
      },
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 365
        }
      }
    ]
  }
}
EOF

    # Apply lifecycle policy
    gsutil lifecycle set /tmp/gcs-lifecycle-policy.json gs://$bucket_name 2>/dev/null || {
        echo "📂 Creating bucket with lifecycle policy..."
        gsutil mb -p "${PROJECT_ID:-invoice-platform-prod}" -c STANDARD -l asia-south1 gs://$bucket_name
        gsutil lifecycle set /tmp/gcs-lifecycle-policy.json gs://$bucket_name
    }
    
    # Cleanup temp file
    rm /tmp/gcs-lifecycle-policy.json
    
    echo "✅ GCS cost optimization configured"
    echo "💡 Cost optimization details:"
    echo "   - Standard storage: First 7 days"
    echo "   - Nearline storage: 7-30 days (50% cheaper)"
    echo "   - Coldline storage: 30-90 days (70% cheaper)"
    echo "   - Archive storage: 90-365 days (80% cheaper)"
    echo "   - Auto-delete: After 365 days"
}

# Function to create monitoring script
create_monitoring_script() {
    echo "📊 Creating backup monitoring script..."
    
    cat > /app/scripts/backup-monitor.sh << 'EOF'
#!/bin/bash

# MongoDB Backup Monitoring Script
echo "📊 MongoDB Backup Monitoring Report"
echo "=================================="
echo ""

BACKUP_DIR="/app/backups"
LOG_FILE="/var/log/mongodb-backup/backup.log"
GCS_BUCKET="invoice-platform-backups"

# Check last backup status
echo "🕐 Last Backup Status:"
if [ -f "$LOG_FILE" ]; then
    last_backup=$(tail -n 20 "$LOG_FILE" | grep -E "(✅|❌)" | tail -n 1)
    echo "   $last_backup"
else
    echo "   ⚠️ No backup log found"
fi

# Local backup statistics
echo ""
echo "💾 Local Backup Statistics:"
if [ -d "$BACKUP_DIR" ]; then
    backup_count=$(ls -1 "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    latest_backup=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)
    
    echo "   Total backups: $backup_count"
    echo "   Total size: $total_size"
    if [ -n "$latest_backup" ]; then
        latest_date=$(stat -c %y "$latest_backup" | cut -d' ' -f1)
        latest_size=$(du -h "$latest_backup" | cut -f1)
        echo "   Latest backup: $(basename "$latest_backup") ($latest_size) - $latest_date"
    fi
else
    echo "   ⚠️ No local backup directory found"
fi

# Cloud backup statistics
echo ""
echo "☁️ Cloud Backup Statistics:"
if command -v gsutil &> /dev/null; then
    daily_count=$(gsutil ls gs://$GCS_BUCKET/daily/ 2>/dev/null | wc -l)
    weekly_count=$(gsutil ls gs://$GCS_BUCKET/weekly/ 2>/dev/null | wc -l)
    monthly_count=$(gsutil ls gs://$GCS_BUCKET/monthly/ 2>/dev/null | wc -l)
    
    echo "   Daily backups: $daily_count"
    echo "   Weekly backups: $weekly_count"
    echo "   Monthly backups: $monthly_count"
    
    # Estimate storage costs
    echo ""
    echo "💰 Estimated Monthly Storage Cost:"
    echo "   - Daily backups (Standard): ~$0.02/GB/month × estimated size"
    echo "   - Weekly backups (Nearline): ~$0.01/GB/month × estimated size" 
    echo "   - Monthly backups (Coldline): ~$0.006/GB/month × estimated size"
    echo "   - Archive backups: ~$0.0012/GB/month × estimated size"
else
    echo "   ⚠️ gsutil not available"
fi

# System health
echo ""
echo "🏥 System Health:"
disk_usage=$(df -h /app 2>/dev/null | tail -n 1 | awk '{print $5}' || echo "N/A")
memory_usage=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}' 2>/dev/null || echo "N/A")
echo "   Disk usage: $disk_usage"
echo "   Memory usage: $memory_usage"

# Next backup time
echo ""
echo "⏰ Next Scheduled Backup:"
if command -v systemctl &> /dev/null && systemctl is-active mongodb-backup.timer &>/dev/null; then
    next_run=$(systemctl list-timers mongodb-backup.timer | grep mongodb-backup.timer | awk '{print $1, $2}')
    echo "   $next_run"
elif crontab -l 2>/dev/null | grep -q backup-mongodb.sh; then
    echo "   Midnight daily (via cron)"
else
    echo "   ⚠️ No scheduled backup found"
fi

echo ""
echo "Report generated: $(date)"
EOF

    chmod +x /app/scripts/backup-monitor.sh
    echo "✅ Monitoring script created at /app/scripts/backup-monitor.sh"
}

# Function to setup cost alerts (Google Cloud)
setup_cost_alerts() {
    echo "🔔 Setting up cost monitoring alerts..."
    
    # Create budget alert configuration
    cat > /tmp/budget-config.yaml << EOF
displayName: "Invoice Platform Backup Storage Budget"
budgetFilter:
  projects:
    - "projects/${PROJECT_ID:-invoice-platform-prod}"
  services:
    - "services/95FF2355-89CE-672C-D5DC-CDD51B993F93"  # Cloud Storage
amount:
  specifiedAmount:
    currencyCode: "USD"
    units: "10"  # $10 monthly budget for backup storage
thresholdRules:
  - thresholdPercent: 0.5  # 50% alert
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 0.8  # 80% alert
    spendBasis: CURRENT_SPEND
  - thresholdPercent: 1.0  # 100% alert
    spendBasis: CURRENT_SPEND
EOF

    if command -v gcloud &> /dev/null; then
        echo "💰 Budget alerts can be set up via Google Cloud Console"
        echo "   Go to: https://console.cloud.google.com/billing/budgets"
        echo "   Create budget for Cloud Storage with $10/month limit"
    fi
    
    rm /tmp/budget-config.yaml
}

# Main setup function
main() {
    echo "🚀 Invoice Platform - MongoDB Backup Setup"
    echo "=========================================="
    echo ""
    
    # Make backup script executable
    chmod +x "$BACKUP_SCRIPT_PATH"
    
    # Choose scheduling method
    echo "⚡ Choose backup scheduling method:"
    echo "1. Cron job (traditional, reliable)"
    echo "2. Systemd timer (modern, better logging)"
    echo ""
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            setup_cron_job
            ;;
        2)
            create_systemd_service
            ;;
        *)
            echo "Invalid choice, setting up cron job..."
            setup_cron_job
            ;;
    esac
    
    # Setup additional components
    setup_log_rotation
    setup_gcs_cost_optimization
    create_monitoring_script
    setup_cost_alerts
    
    echo ""
    echo "🎉 Backup System Setup Complete!"
    echo "================================"
    echo ""
    echo "✅ Features configured:"
    echo "   • Automated midnight backups"
    echo "   • Cost-optimized cloud storage"
    echo "   • Automatic retention management"
    echo "   • Log rotation"
    echo "   • Monitoring scripts"
    echo ""
    echo "💰 Cost Optimization Features:"
    echo "   • Incremental backup detection"
    echo "   • Automatic storage class transitions"
    echo "   • Retention policies (7 daily, 4 weekly, 3 monthly)"
    echo "   • Compressed backups"
    echo "   • Auto-deletion after 1 year"
    echo ""
    echo "🔧 Management Commands:"
    echo "   • Test backup: $BACKUP_SCRIPT_PATH"
    echo "   • Monitor status: /app/scripts/backup-monitor.sh"
    echo "   • View logs: tail -f /var/log/mongodb-backup/backup.log"
    echo "   • Check schedule: systemctl status mongodb-backup.timer"
    echo ""
    echo "📊 Expected monthly costs:"
    echo "   • Storage: $1-5/month (depending on database size)"
    echo "   • Egress: Minimal (backups only)"
    echo "   • Operations: Free tier covers most usage"
    echo ""
    echo "🎯 Your MongoDB backup system is now optimized for cost and reliability!"
}

# Run setup
main "$@"
