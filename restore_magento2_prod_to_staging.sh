#!/bin/bash -x

# Description: This script performs the following operations:
#   1. Backs up admin users from production database
#   2. Restores a production database backup to staging environment
#   3. Creates a parallel backup database
#   4. Handles data sanitization and format conversion

# Initialize variables
LOG_FILE="/tmp/download_magento2_live_script.log"
ADMIN_BACKUP="/tmp/magento2_live_adminusers.sql"
PROCESS_ADMIN_SCRIPT="~/scripts/process_magento2_live_adminusers.sql"
PROCESS_LIVE_SCRIPT="~/scripts/process_magento2_live.sql"
MYSQL_CREDS="--user=root --password=magento"

{
    # Clear any existing admin backup
    echo "=== Starting Magento 2 Database Restoration ==="
    echo "[$(date)] Step 1: Backing up admin users..."
    rm -rf "${ADMIN_BACKUP}"
    
    # Backup admin users from production
    if ! mysqldump ${MYSQL_CREDS} magento2_live admin_user > "${ADMIN_BACKUP}"; then
        echo "ERROR: Failed to backup admin users" >&2
        exit 1
    fi
    
    # Process admin users (preserve them in staging)
    if [ -f "${PROCESS_ADMIN_SCRIPT}" ]; then
        if ! mysql ${MYSQL_CREDS} -e "source ${PROCESS_ADMIN_SCRIPT}"; then
            echo "WARNING: Failed to process admin users script" >&2
        fi
    else
        echo "WARNING: Admin processing script not found at ${PROCESS_ADMIN_SCRIPT}" >&2
    fi

    # Find and decompress the latest backup
    echo "[$(date)] Step 2: Decompressing latest database backup..."
    mysql_dump="$(ls /tmp/magento2_live_*.*.sql.gz | tail -n 1)"
    if [ -z "${mysql_dump}" ]; then
        echo "ERROR: No database backup found in /tmp" >&2
        exit 1
    fi
    
    if ! gzip -d "${mysql_dump}" >> /tmp/download_magento_live.log; then
        echo "ERROR: Failed to decompress ${mysql_dump}" >&2
        exit 1
    fi

    # Prepare the SQL file for import
    echo "[$(date)] Step 3: Preparing database for import..."
    mysql_sql="$(ls /tmp/magento2_live_*.*.sql | tail -n 1)"
    if ! sed -i 's/ROW_FORMAT=FIXED//g' "${mysql_sql}"; then
        echo "WARNING: Failed to modify ROW_FORMAT in ${mysql_sql}" >&2
    fi

    # Restore to staging environment
    echo "[$(date)] Step 4: Restoring to magento2_live (staging)..."
    if ! mysql ${MYSQL_CREDS} magento2_live < "${mysql_sql}"; then
        echo "ERROR: Failed to restore to magento2_live" >&2
        exit 1
    fi

    # Process staging database
    echo "[$(date)] Step 5: Processing staging database..."
    if [ -f "${PROCESS_LIVE_SCRIPT}" ]; then
        if ! mysql ${MYSQL_CREDS} -e "source ${PROCESS_LIVE_SCRIPT}"; then
            echo "WARNING: Failed to process staging database script" >&2
        fi
    else
        echo "WARNING: Staging processing script not found at ${PROCESS_LIVE_SCRIPT}" >&2
    fi

    # Create parallel backup database
    echo "[$(date)] Step 6: Creating backup database..."
    if ! sed -i 's|magento2_live|magento_production_backup|' "${mysql_sql}"; then
        echo "WARNING: Failed to modify database name in backup file" >&2
    fi
    
    if ! mysql ${MYSQL_CREDS} magento_production_backup < "${mysql_sql}"; then
        echo "ERROR: Failed to restore to magento_production_backup" >&2
        exit 1
    fi

    echo "[$(date)] === Restoration completed successfully ==="
    echo "${mysql_sql} has been successfully restored to both magento2_live and magento_production_backup databases."
} 2>&1 | tee "${LOG_FILE}"

# Check final status
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "Success! Detailed log available at ${LOG_FILE}"
    exit 0
else
    echo "Failed! Check log at ${LOG_FILE} for details"
    exit 1
fi