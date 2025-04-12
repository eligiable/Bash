#!/bin/bash

###############################################################################
# Performs comprehensive server maintenance tasks including:
# - System updates and package management
# - Log rotation and compression
# - Disk space cleanup and monitoring
# - Memory usage monitoring
# - Critical directory backups with retention policy
# - Service status verification
# - Email alerts for critical events with SMTP configuration
# - Detailed logging with warning/critical event tracking
#
# Usage:
# 1. Configure the variables in the "Configuration" section
# 2. Make script executable: chmod +x server_maintenance.sh
# 3. Run as root: sudo ./server_maintenance.sh
# 4. Consider setting up a cron job for regular execution
#
# Dependencies:
# - mailutils (for email alerts)
# - systemd (for service checks)
###############################################################################

### Configuration Section ###

# Backup configuration
BACKUP_DIR="/backup"                          # Directory to store backups
BACKUP_RETENTION_DAYS=7                       # Number of days to keep backups
CRITICAL_DIRS="/etc /home /var/www"           # Directories to back up

# Log management configuration
LOG_DIR="/var/log"                            # Directory to manage logs
LOG_RETENTION_DAYS=30                         # Days to keep compressed logs
MAX_LOG_SIZE="100M"                           # Threshold for large log warnings

# System monitoring thresholds
DISK_THRESHOLD=90                             # Percentage for disk space alerts
MEMORY_THRESHOLD=90                           # Percentage for memory alerts
SWAP_THRESHOLD=80                             # Percentage for swap alerts

# Critical services to check
CRITICAL_SERVICES="ssh apache2 mysql nginx"   # Services to verify are running

# Email notification configuration
ADMIN_EMAIL="admin@example.com"               # Recipient for alerts
EMAIL_SUBJECT="Server Maintenance Report"     # Email subject line
SEND_EMAIL_ALERTS=true                        # Set to false to disable emails

# SMTP configuration (only needed if SEND_EMAIL_ALERTS=true)
SMTP_SERVER="smtp.example.com"
SMTP_PORT="587"
SMTP_USER="alerts@example.com"
SMTP_PASSWORD="your_password"
SMTP_FROM="server-alerts@example.com"

### End of Configuration Section ###

# Initialize variables
EMAIL_CONTENT=""
SCRIPT_LOG="/var/log/maintenance.log"
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname -f)

# Logging function with email alerts
log_message() {
    local message="$1"
    local severity="${2:-INFO}"
    
    # Log to file with timestamp and severity
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$severity] $message" >> "$SCRIPT_LOG"
    
    # Add to email content if it's a warning or error
    if [[ "$severity" == "WARNING" || "$severity" == "ERROR" ]]; then
        EMAIL_CONTENT="${EMAIL_CONTENT}\n[$severity] $message"
    fi
    
    # Print to console if interactive session
    if [ -t 0 ]; then
        echo "[$severity] $message"
    fi
}

# Send email alert
send_email_alert() {
    if [ "$SEND_EMAIL_ALERTS" = true ] && [ -n "$EMAIL_CONTENT" ]; then
        local email_body="Server Maintenance Report for $HOSTNAME\n"
        email_body+="Generated on: $CURRENT_DATE\n\n"
        email_body+="=== System Status Overview ===\n"
        email_body+="$(uptime)\n"
        email_body+="$(free -h | awk '/Mem:/ {print "Memory: " $3 " used of " $2}')\n"
        email_body+="$(df -h --output=source,pcent,target | grep -v '^Filesystem')\n\n"
        email_body+="=== Issues Detected ===\n"
        email_body+="${EMAIL_CONTENT}\n\n"
        email_body+="=== Maintenance Details ===\n"
        email_body+="Full log available at: $SCRIPT_LOG\n"
        email_body+="Last 10 lines of log:\n$(tail -n 10 $SCRIPT_LOG)\n"
        
        log_message "Sending email alert to $ADMIN_EMAIL" "INFO"
        
        echo -e "$email_body" | mail -s "$EMAIL_SUBJECT - $HOSTNAME - $CURRENT_DATE" \
            -r "$SMTP_FROM" \
            -S smtp="$SMTP_SERVER:$SMTP_PORT" \
            -S smtp-use-starttls \
            -S smtp-auth=login \
            -S smtp-auth-user="$SMTP_USER" \
            -S smtp-auth-password="$SMTP_PASSWORD" \
            "$ADMIN_EMAIL"
    else
        log_message "No warnings or critical events to report" "INFO"
    fi
}

# Check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_message "This script must be run as root" "ERROR"
        exit 1
    fi
}

# Update system packages
update_system() {
    log_message "Starting system update" "INFO"
    
    # Update package lists
    if ! apt-get update -qq; then
        log_message "Failed to update package lists" "ERROR"
        return 1
    fi
    
    # Upgrade packages
    if ! apt-get upgrade -y -qq; then
        log_message "Failed to upgrade packages" "ERROR"
        return 1
    fi
    
    # Check for packages that need reboot
    if [ -f /var/run/reboot-required ]; then
        log_message "System reboot required to complete updates" "WARNING"
    fi
    
    log_message "System update completed" "INFO"
}

# Rotate and compress logs
manage_logs() {
    log_message "Starting log management" "INFO"
    
    # Find and compress logs older than 1 day (not today's logs)
    find "$LOG_DIR" -type f -name "*.log" -mtime +1 ! -name "*.gz" -exec gzip -f {} \; 2>/dev/null
    
    # Delete compressed logs older than retention period
    find "$LOG_DIR" -type f -name "*.gz" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null
    
    # Check for large log files
    find "$LOG_DIR" -type f -size +$MAX_LOG_SIZE -name "*.log" -exec ls -lh {} + | while read line; do
        log_message "Large log file detected: $line" "WARNING"
    done
    
    # Clean empty log files
    find "$LOG_DIR" -type f -name "*.log" -empty -delete 2>/dev/null
    
    log_message "Log management completed" "INFO"
}

# Clean up disk space
cleanup_disk() {
    log_message "Starting disk cleanup" "INFO"
    
    # Clean apt cache
    apt-get clean -qq
    apt-get autoremove -y -qq
    
    # Remove old kernels (keep current and one previous)
    current_kernel=$(uname -r | sed 's/-*[a-z]//g;s/-386//')
    installed_kernels=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -vE "$current_kernel|linux-image-generic")
    
    for kernel in $installed_kernels; do
        apt-get purge -y "$kernel" >/dev/null
    done
    
    # Clean temporary files
    rm -rf /tmp/* /var/tmp/*
    
    # Clean old crash reports
    rm -f /var/crash/*
    
    log_message "Disk cleanup completed" "INFO"
}

# Check disk space
check_disk_space() {
    log_message "Checking disk space" "INFO"
    
    df -hP | grep '^/dev/' | while read line; do
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        partition=$(echo "$line" | awk '{print $1}')
        mount_point=$(echo "$line" | awk '{print $6}')
        
        if [ "$usage" -gt "$DISK_THRESHOLD" ]; then
            log_message "Partition $partition ($mount_point) is ${usage}% full" "WARNING"
        fi
        
        # Check for read-only filesystems
        if grep -q "$mount_point ro," /proc/mounts; then
            log_message "Filesystem $mount_point is mounted read-only" "ERROR"
        fi
    done
    
    # Check inodes
    df -iP | grep '^/dev/' | while read line; do
        iuse=$(echo "$line" | awk '{print $5}' | tr -d '%')
        partition=$(echo "$line" | awk '{print $1}')
        if [ "$iuse" -gt "$DISK_THRESHOLD" ]; then
            log_message "Partition $partition is ${iuse}% inode usage" "WARNING"
        fi
    done
}

# Check memory usage
check_memory() {
    log_message "Checking memory usage" "INFO"
    
    memory_usage=$(free | awk '/Mem:/ {printf("%d", $3/$2 * 100)}')
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        log_message "Memory usage is at ${memory_usage}%" "WARNING"
    fi
    
    # Check swap usage
    swap_usage=$(free | awk '/Swap:/ {printf("%d", $3/$2 * 100)}')
    if [ "$swap_usage" -gt "$SWAP_THRESHOLD" ]; then
        log_message "Swap usage is at ${swap_usage}%" "WARNING"
    fi
    
    # Check for OOM killer activity
    if dmesg | grep -i "oom-killer"; then
        log_message "OOM killer has been active recently" "ERROR"
    fi
}

# Backup critical directories
perform_backup() {
    log_message "Starting backup process" "INFO"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Backup each critical directory
    for dir in $CRITICAL_DIRS; do
        if [ ! -d "$dir" ]; then
            log_message "Directory $dir does not exist, skipping backup" "WARNING"
            continue
        fi
        
        base_name=$(basename "$dir")
        backup_file="$BACKUP_DIR/${base_name}_backup_$TIMESTAMP.tar.gz"
        
        log_message "Backing up $dir to $backup_file" "INFO"
        
        if ! tar -czf "$backup_file" "$dir" 2>/dev/null; then
            log_message "Failed to backup $dir" "ERROR"
            continue
        fi
        
        # Verify backup integrity
        if ! gzip -t "$backup_file"; then
            log_message "Backup verification failed for $backup_file" "ERROR"
            rm -f "$backup_file"
        else
            # Set proper permissions
            chmod 600 "$backup_file"
            log_message "Successfully backed up $dir" "INFO"
        fi
    done
    
    # Remove backups older than retention period
    find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete
    
    log_message "Backup process completed" "INFO"
}

# Check service status
check_services() {
    log_message "Checking service status" "INFO"
    
    for service in $CRITICAL_SERVICES; do
        if ! systemctl is-enabled "$service" >/dev/null 2>&1; then
            log_message "Service $service is not enabled to start at boot" "WARNING"
            continue
        fi
        
        if ! systemctl is-active --quiet "$service"; then
            log_message "Service $service is not running" "ERROR"
            # Attempt to restart the service
            if systemctl restart "$service"; then
                log_message "Successfully restarted service $service" "INFO"
            else
                log_message "Failed to restart service $service" "ERROR"
            fi
        fi
    done
}

# Check for pending reboots
check_reboot() {
    if [ -f /var/run/reboot-required ]; then
        log_message "System reboot required (pending updates)" "WARNING"
    fi
    
    if [ -f /var/run/reboot-required.pkgs ]; then
        pkgs=$(cat /var/run/reboot-required.pkgs)
        log_message "Reboot required for: $pkgs" "WARNING"
    fi
}

# Check for security updates
check_security_updates() {
    if [ -x /usr/bin/apt-get ]; then
        security_updates=$(apt-get upgrade --dry-run | grep -i security | wc -l)
        if [ "$security_updates" -gt 0 ]; then
            log_message "$security_updates security updates available" "WARNING"
        fi
    fi
}

# Main execution function
main() {
    log_message "Starting maintenance script on $HOSTNAME" "INFO"
    log_message "System information: $(uname -a)" "INFO"
    
    # Run maintenance tasks
    check_root
    update_system
    check_security_updates
    manage_logs
    cleanup_disk
    check_disk_space
    check_memory
    perform_backup
    check_services
    check_reboot
    
    # Calculate script runtime
    end_time=$(date +%s)
    runtime=$((end_time - start_time))
    log_message "Maintenance script completed in $runtime seconds" "INFO"
    
    # Send email alert if there were any warnings or errors
    send_email_alert
    
    exit 0
}

# Record start time and run main function
start_time=$(date +%s)
main