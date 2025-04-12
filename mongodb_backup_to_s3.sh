#!/bin/bash

# Description: This script performs a backup of a MongoDB database, compresses it, and uploads it to an AWS S3 bucket. It includes logging, error handling, and cleanup.

# Configuration Variables
HOST="localhost"
DBNAME="DB_Name"
DBUSER="DB_User"
DBPWD="DB_Password"
BUCKET="Bucket_Name/MongoDB"
USER="ubuntu"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEST="/tmp/mongodb_backups"
BKPFILE="${DBNAME}_${TIMESTAMP}.gz"
LOG_FILE="/var/log/mongodb_backup.log"

# Create destination directory if it doesn't exist
mkdir -p "$DEST"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start backup process
{
    log "Starting MongoDB backup of $DBNAME to s3://$BUCKET/"
    
    # Execute Backup
    if /usr/bin/mongodump -h "$HOST" -d "$DBNAME" -u "$DBUSER" -p "$DBPWD" --gzip --archive="$DEST/$BKPFILE"; then
        log "MongoDB dump completed successfully"
        
        # Upload to S3
        if /usr/local/bin/s3cmd put "$DEST/$BKPFILE" "s3://$BUCKET/"; then
            log "Backup uploaded successfully to s3://$BUCKET/$BKPFILE"
            log "Backup available at https://s3.amazonaws.com/$BUCKET/$BKPFILE"
            
            # Clean up local backup
            rm -f "$DEST/$BKPFILE"
            log "Local backup file removed"
        else
            log "ERROR: Failed to upload backup to S3"
            exit 1
        fi
    else
        log "ERROR: MongoDB dump failed"
        exit 1
    fi
    
    log "Backup process completed successfully"
} 2>&1 | tee -a "$LOG_FILE"