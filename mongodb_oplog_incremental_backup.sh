#!/bin/bash

# Description: This script performs incremental backups of MongoDB's oplog by dumping all operations that occurred since the last backup. It's designed to run periodically (e.g., hourly) to maintain a continuous backup of all database changes.

function initStaticParams {
   # MongoDB Connection Parameters
   MONGODB_SERVER="127.0.0.1"
   MONOGDB_PORT="27017"
   MONGODB_USER="DB_User"
   MONGODB_PWD="DB_Password"
   AUTH_DATABASE="admin"
   
   # Backup Parameters
   OUTPUT_DIRECTORY="/mnt/mongodb-slave/oplogs"
   MAX_BACKUP_AGE_DAYS=30  # Automatically delete backups older than this
   MIN_FREE_SPACE_GB=10    # Minimum required free space in GB
   
   # Logging Parameters
   LOG_FILE="/var/log/mongodb/backup.log"
   MAX_LOG_SIZE_MB=10      # Rotate log if larger than this
   MAX_LOG_FILES=5         # Keep this many rotated logs
   
   # Notification Parameters (optional)
   EMAIL_NOTIFICATIONS=false
   EMAIL_ADDRESS="admin@example.com"
   
   # Log Levels
   LOG_MESSAGE_ERROR=1
   LOG_MESSAGE_WARN=2
   LOG_MESSAGE_INFO=3
   LOG_MESSAGE_DEBUG=4
   LOG_LEVEL=$LOG_MESSAGE_DEBUG
   
   # Script Identification
   SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
   SCRIPT_NAME=$(basename "$SCRIPT_PATH")
   LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
}

function log {
   local MESSAGE_LEVEL=$1
   shift
   local MESSAGE="$*"
   local TIMESTAMP=$(date +'%Y-%m-%dT%H:%M:%S.%3N')
   local LEVEL_STR
   
   case $MESSAGE_LEVEL in
      $LOG_MESSAGE_ERROR) LEVEL_STR="ERROR" ;;
      $LOG_MESSAGE_WARN)  LEVEL_STR="WARN"  ;;
      $LOG_MESSAGE_INFO) LEVEL_STR="INFO"  ;;
      $LOG_MESSAGE_DEBUG) LEVEL_STR="DEBUG" ;;
      *) LEVEL_STR="UNKNOWN" ;;
   esac
   
   if [ $MESSAGE_LEVEL -le $LOG_LEVEL ]; then
      echo "${TIMESTAMP} [${LEVEL_STR}] ${MESSAGE}" >> "$LOG_FILE"
   fi
}

function cleanup {
   # Remove lock file and perform any other cleanup
   if [ -f "$LOCK_FILE" ]; then
      rm -f "$LOCK_FILE"
      log $LOG_MESSAGE_DEBUG "[DEBUG] Removed lock file: $LOCK_FILE"
   fi
}

function checkPrerequisites {
   # Check required commands are available
   local REQUIRED_COMMANDS=("mongodump" "bsondump" "jq" "stat")
   local MISSING_COMMANDS=()
   
   for cmd in "${REQUIRED_COMMANDS[@]}"; do
      if ! command -v "$cmd" &> /dev/null; then
         MISSING_COMMANDS+=("$cmd")
      fi
   done
   
   if [ ${#MISSING_COMMANDS[@]} -gt 0 ]; then
      log $LOG_MESSAGE_ERROR "[ERROR] Missing required commands: ${MISSING_COMMANDS[*]}"
      exit 1
   fi
   
   # Check free space
   local FREE_SPACE_KB=$(df -Pk "$OUTPUT_DIRECTORY" | awk 'NR==2 {print $4}')
   local FREE_SPACE_GB=$((FREE_SPACE_KB / 1024 / 1024))
   
   if [ "$FREE_SPACE_GB" -lt "$MIN_FREE_SPACE_GB" ]; then
      log $LOG_MESSAGE_ERROR "[ERROR] Not enough free space in $OUTPUT_DIRECTORY. Required: ${MIN_FREE_SPACE_GB}GB, Available: ${FREE_SPACE_GB}GB"
      exit 1
   fi
   
   # Check if output directory exists and is writable
   if [ ! -d "$OUTPUT_DIRECTORY" ]; then
      log $LOG_MESSAGE_DEBUG "[DEBUG] Creating output directory: $OUTPUT_DIRECTORY"
      mkdir -p "$OUTPUT_DIRECTORY" || {
         log $LOG_MESSAGE_ERROR "[ERROR] Failed to create output directory: $OUTPUT_DIRECTORY"
         exit 1
      }
   fi
   
   if [ ! -w "$OUTPUT_DIRECTORY" ]; then
      log $LOG_MESSAGE_ERROR "[ERROR] Output directory is not writable: $OUTPUT_DIRECTORY"
      exit 1
   fi
}

function rotateLogs {
   if [ -f "$LOG_FILE" ]; then
      local LOG_SIZE=$(stat -c%s "$LOG_FILE")
      local MAX_LOG_SIZE=$((MAX_LOG_SIZE_MB * 1024 * 1024))
      
      if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
         log $LOG_MESSAGE_DEBUG "[DEBUG] Rotating log file (size: $LOG_SIZE bytes)"
         
         for ((i=MAX_LOG_FILES-1; i>=1; i--)); do
            if [ -f "${LOG_FILE}.${i}" ]; then
               mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
            fi
         done
         
         mv "$LOG_FILE" "${LOG_FILE}.1"
      fi
   fi
}

function cleanupOldBackups {
   log $LOG_MESSAGE_DEBUG "[DEBUG] Cleaning up backups older than $MAX_BACKUP_AGE_DAYS days"
   find "$OUTPUT_DIRECTORY" -name "*.bson" -mtime +$MAX_BACKUP_AGE_DAYS -exec rm -f {} \; 2>> "$LOG_FILE"
}

function acquireLock {
   if [ -f "$LOCK_FILE" ]; then
      local PID=$(cat "$LOCK_FILE")
      if ps -p "$PID" > /dev/null; then
         log $LOG_MESSAGE_ERROR "[ERROR] Script is already running with PID $PID"
         exit 1
      else
         log $LOG_MESSAGE_WARN "[WARN] Stale lock file found (PID $PID). Removing and continuing."
         rm -f "$LOCK_FILE"
      fi
   fi
   
   echo $$ > "$LOCK_FILE"
   trap cleanup EXIT
   log $LOG_MESSAGE_DEBUG "[DEBUG] Lock acquired (PID $$)"
}

function sendNotification {
   if [ "$EMAIL_NOTIFICATIONS" = true ]; then
      local SUBJECT="MongoDB Oplog Backup $1"
      local BODY="$2"
      echo "$BODY" | mail -s "$SUBJECT" "$EMAIL_ADDRESS"
   fi
}

function main {
   initStaticParams
   rotateLogs
   acquireLock
   checkPrerequisites
   cleanupOldBackups
   
   log $LOG_MESSAGE_INFO "[INFO] Starting incremental backup of oplog"
   
   mkdir -p "$OUTPUT_DIRECTORY"
   
   local LAST_OPLOG_DUMP=$(ls -t "${OUTPUT_DIRECTORY}"/*.bson 2> /dev/null | head -1)
   local LAST_OPLOG_ENTRY=""
   local START_TIMESTAMP=""
   local TIMESTAMP_LAST_OPLOG_ENTRY=""
   local INC_NUMBER_LAST_OPLOG_ENTRY=""
   
   if [ -n "$LAST_OPLOG_DUMP" ]; then
      log $LOG_MESSAGE_DEBUG "[DEBUG] Last incremental oplog backup is $LAST_OPLOG_DUMP"
      
      LAST_OPLOG_ENTRY=$(bsondump "$LAST_OPLOG_DUMP" 2>> "$LOG_FILE" | grep ts | tail -1)
      if [ -z "$LAST_OPLOG_ENTRY" ]; then
         log $LOG_MESSAGE_ERROR "[ERROR] Evaluating last backed up oplog entry with bsondump failed"
         sendNotification "Failed" "Failed to evaluate last oplog entry"
         exit 1
      else
         TIMESTAMP_LAST_OPLOG_ENTRY=$(echo "$LAST_OPLOG_ENTRY" | jq -r '.ts[].t')
         INC_NUMBER_LAST_OPLOG_ENTRY=$(echo "$LAST_OPLOG_ENTRY" | jq -r '.ts[].i')
         START_TIMESTAMP="Timestamp( ${TIMESTAMP_LAST_OPLOG_ENTRY}, ${INC_NUMBER_LAST_OPLOG_ENTRY} )"
         log $LOG_MESSAGE_DEBUG "[DEBUG] Dumping everything newer than $START_TIMESTAMP"
      fi
      log $LOG_MESSAGE_DEBUG "[DEBUG] Last backed up oplog entry: $LAST_OPLOG_ENTRY"
   else
      log $LOG_MESSAGE_WARN "[WARN] No backed up oplog available. Creating initial backup"
   fi
   
   local OUTPUT_FILE="${OUTPUT_DIRECTORY}/$(date +%Y%m%d_%H%M%S)_oplog.bson"
   local RET_CODE=0
   
   if [ -n "$LAST_OPLOG_ENTRY" ]; then
      log $LOG_MESSAGE_DEBUG "[DEBUG] Executing mongodump with query for new entries"
      mongodump -h "$MONGODB_SERVER" --port "$MONOGDB_PORT" -u "$MONGODB_USER" -p "$MONGODB_PWD" \
         --authenticationDatabase="$AUTH_DATABASE" -d local -c oplog.rs \
         --query "{ \"ts\" : { \"\$gt\" : $START_TIMESTAMP } }" -o - > "$OUTPUT_FILE" 2>> "$LOG_FILE"
      RET_CODE=$?
   else 
      TIMESTAMP_LAST_OPLOG_ENTRY=0000000000
      INC_NUMBER_LAST_OPLOG_ENTRY=0
      log $LOG_MESSAGE_DEBUG "[DEBUG] Executing mongodump for full oplog"
      mongodump -h "$MONGODB_SERVER" --port "$MONOGDB_PORT" -u "$MONGODB_USER" -p "$MONGODB_PWD" \
         --authenticationDatabase="$AUTH_DATABASE" -d local -c oplog.rs -o - > "$OUTPUT_FILE" 2>> "$LOG_FILE"
      RET_CODE=$?
   fi
   
   if [ $RET_CODE -gt 0 ]; then
      log $LOG_MESSAGE_ERROR "[ERROR] Incremental backup of oplog with mongodump failed with return code $RET_CODE"
      sendNotification "Failed" "Mongodump failed with return code $RET_CODE"
      exit 1
   fi
   
   local FILESIZE=$(stat --printf="%s" "$OUTPUT_FILE" 2>/dev/null)
   
   if [ -z "$FILESIZE" ] || [ "$FILESIZE" -eq 0 ]; then
      log $LOG_MESSAGE_WARN "[WARN] No documents have been dumped (no changes in MongoDB since last backup?). Deleting $OUTPUT_FILE"
      rm -f "$OUTPUT_FILE"
      sendNotification "Skipped" "No new oplog entries to backup"
   else
      log $LOG_MESSAGE_INFO "[INFO] Successfully backed up oplog to $OUTPUT_FILE (size: $FILESIZE bytes)"
      sendNotification "Success" "Oplog backup completed successfully. File: $OUTPUT_FILE Size: $FILESIZE bytes"
   fi
   
   log $LOG_MESSAGE_INFO "[INFO] Finished incremental backup of oplog"
}

main