#!/bin/bash

# Description: This script checks if JSON generation is running, validates the existence of required cache directories and files, counts JSON files per store, and triggers regeneration if needed. It's designed to ensure product/category JSON cache is properly maintained for a Magento 2 store.

# Configuration
CACHE_BASE="/var/www/magento2/pub/media/cache"
LOG_FILE="/tmp/check-json-script.log"
EMAIL_TO="alert@example.com"
EMAIL_FROM="Example TV<no-reply@example.com>"
STORE_IDS="2 4 5 6 7 8 9 10 11 12 13 14"

# Initialize variables
CHECKLIST=0
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Logging function
log() {
    echo "[$TIMESTAMP] $1" | tee -a $LOG_FILE
}

# Check if JSON generation is already running
log "Checking if JSON generation process is already running..."
if pgrep -f "ctv:json:generate" > /dev/null; then
    log "JSON Generation is already running. Exiting."
    exit 0
fi

# Main validation function
validate_cache() {
    local cache_type=$1
    local cache_path="$CACHE_BASE/$cache_type"
    
    log "-- Validating $cache_type directories --"
    
    # Check base directory
    if [ ! -d "$cache_path" ]; then
        log "ERROR: Base directory $cache_path does not exist!"
        CHECKLIST=1
        return
    fi
    
    # Check store directories
    for store_id in $STORE_IDS; do
        store_path="$cache_path/$store_id"
        if [ ! -d "$store_path" ]; then
            log "ERROR: Directory $store_path does not exist!"
            CHECKLIST=1
        else
            log "Directory $store_path exists."
            
            # Check 0.json file
            local json_file="$store_path/0.json"
            if [ ! -f "$json_file" ]; then
                log "ERROR: Required file $json_file does not exist!"
                CHECKLIST=1
            fi
            
            # Count JSON files
            local json_count=$(find "$store_path" -type f -name "*.json" | wc -l)
            log "StoreID $store_id has $json_count JSON files"
        fi
    done
}

# Main execution
{
    log "Starting JSON cache validation..."
    
    # Validate categories cache
    validate_cache "categories"
    
    # Validate products cache
    validate_cache "products"
    
    log "Validation complete. Checklist status: $CHECKLIST"
} 

# Take action based on validation results
if [ $CHECKLIST -eq 1 ]; then
    log "Issues detected. Starting JSON regeneration process..."
    $(which mail) -s "JSON Generation Checklist - Regeneration Triggered" "$EMAIL_TO" < $LOG_FILE -a "From:$EMAIL_FROM" > /dev/null 2>&1
    
    # Regenerate JSON cache
    php /var/www/magento2/bin/magento ctv:json:generate
    
    # Refresh cache (assuming this is a custom cache swap script)
    /var/www/magento2/shell/swap_cache.sh
    
    log "JSON regeneration completed."
else
    log "No issues detected. JSON cache is valid."
fi

exit 0