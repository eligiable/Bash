#!/bin/bash

# Server Maintenance Script
# Performs common maintenance tasks including:
# - System updates
# - Log rotation
# - Disk space cleanup
# - Memory usage check
# - Backup critical directories
# - Service status check
# - Email alerts for critical events

# Configuration
BACKUP_DIR="/backup"
LOG_DIR="/var/log"
CRITICAL_SERVICES="ssh apache2 mysql nginx"
DISK_THRESHOLD=90
MEMORY_THRESHOLD=90
MAX_LOG_SIZE=100M

# Email configuration
ADMIN_EMAIL="admin@example.com"
SMTP_SERVER="smtp.example.com"
SMTP_PORT="587"
SMTP_USER="alerts@example.com"
SMTP_PASSWORD="your_password"
EMAIL_SUBJECT="Server Maintenance Alert"

# Initialize email content
EMAIL_CONTENT=""

# Logging function with email alerts
log_message() {
    local message="$1"
    local is_warning="${2:-false}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> /var/log/maintenance.log
    
    if [ "$is_warning" = true ]; then
        EMAIL_CONTENT="${EMAIL_CONTENT}\n[WARNING] $message"
    fi
}

# Send email alert
send_email_alert() {
    if [ -n "$EMAIL_CONTENT" ]; then
        local email_body="Server Maintenance Report - $(date '+%Y-%m-%d %H:%M:%S')\n\nWarnings and Critical Events:${EMAIL_CONTENT}\n\nFull log available at: /var/log/maintenance.log"
        
        echo -e "$email_body" | mail -s "$EMAIL_SUBJECT" \
            -S smtp="$SMTP_SERVER:$SMTP_PORT" \
            -S smtp-use-starttls \
            -S smtp-auth=login \
            -S smtp-auth-user="$SMTP_USER" \
            -S smtp-auth-password="$SMTP_PASSWORD" \
            "$ADMIN_EMAIL"
        
        log_message "Email alert sent to $ADMIN_EMAIL"
    else
        log_message "No warnings or critical events to report"
    fi
}

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Update system packages
update_system() {
    log_message "Starting system update"
    
    if ! apt-get update; then
        log_message "Failed to update package lists" true
    fi
    
    if ! apt-get upgrade -y; then
        log_message "Failed to upgrade packages" true
    fi
    
    log_message "System update completed"
}

# Rotate and compress logs
manage_logs() {
    log_message "Starting log management"
    
    # Find and compress logs older than 7 days
    find $LOG_DIR -type f -name "*.log" -mtime +7 -exec gzip {} \;
    
    # Delete logs older than 30 days
    find $LOG_DIR -type f -name "*.gz" -mtime +30 -delete
    
    # Check for large log files
    find $LOG_DIR -type f -size +$MAX_LOG_SIZE -exec bash -c \
        'log_message "Large log file detected: {}" true' \;
    
    log_message "Log management completed"
}

# Clean up disk space
cleanup_disk() {
    log_message "Starting disk cleanup"
    
    # Clean apt cache
    apt-get clean
    apt-get autoremove -y
    
    # Remove old kernels
    dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs apt-get -y purge
    
    # Clean temporary files
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    log_message "Disk cleanup completed"
}

# Check disk space
check_disk_space() {
    log_message "Checking disk space"
    
    df -h | grep '^/dev/' | while read line; do
        usage=$(echo $line | awk '{print $5}' | sed 's/%//')
        partition=$(echo $line | awk '{print $1}')
        if [ $usage -gt $DISK_THRESHOLD ]; then
            log_message "Partition $partition is ${usage}% full" true
        fi
    done
}

# Check memory usage
check_memory() {
    log_message "Checking memory usage"
    
    memory_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    if [ $memory_usage -gt $MEMORY_THRESHOLD ]; then
        log_message "Memory usage is at ${memory_usage}%" true
    fi
}

# Backup critical directories
perform_backup() {
    log_message "Starting backup"
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Create backup directory if it doesn't exist
    mkdir -p $BACKUP_DIR
    
    # Backup important directories
    if ! tar -czf $BACKUP_DIR/etc_backup_$timestamp.tar.gz /etc; then
        log_message "Failed to backup /etc directory" true
    fi
    
    if ! tar -czf $BACKUP_DIR/home_backup_$timestamp.tar.gz /home; then
        log_message "Failed to backup /home directory" true
    fi
    
    # Remove backups older than 7 days
    find $BACKUP_DIR -type f -mtime +7 -delete
    
    log_message "Backup completed"
}

# Check service status
check_services() {
    log_message "Checking service status"
    
    for service in $CRITICAL_SERVICES; do
        if ! systemctl is-active --quiet $service; then
            log_message "Service $service is not running" true
        fi
    done
}

# Main execution
log_message "Starting maintenance script"

update_system
manage_logs
cleanup_disk
check_disk_space
check_memory
perform_backup
check_services

# Send email alert if there were any warnings
send_email_alert

log_message "Maintenance script completed"
