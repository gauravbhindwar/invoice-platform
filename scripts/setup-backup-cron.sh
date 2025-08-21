#!/bin/bash

# Setup Daily Backup Cron Job for Invoice Platform
echo "⏰ Setting up daily backup cron job..."

# Get the absolute path to the backup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/daily-backup.sh"

# Make sure the backup script is executable
chmod +x "$BACKUP_SCRIPT"

# Create log directory
LOG_DIR="/var/log/invoice-platform"
sudo mkdir -p "$LOG_DIR"
sudo chown $(whoami):$(whoami) "$LOG_DIR"

# Backup cron job entry
CRON_JOB="0 0 * * * $BACKUP_SCRIPT >> $LOG_DIR/backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    echo "ℹ️ Backup cron job already exists"
else
    # Add cron job
    echo "📅 Adding daily backup cron job..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✅ Cron job added successfully"
fi

echo ""
echo "🎯 Backup Schedule Configured:"
echo "  - Time: Every day at 12:00 AM (midnight)"
echo "  - Script: $BACKUP_SCRIPT"
echo "  - Logs: $LOG_DIR/backup.log"
echo "  - Retention: 7 days"
echo ""
echo "📋 View current cron jobs:"
echo "crontab -l"
echo ""
echo "📊 View backup logs:"
echo "tail -f $LOG_DIR/backup.log"
