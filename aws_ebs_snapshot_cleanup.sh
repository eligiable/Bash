#!/bin/bash

# Description: Deletes EBS snapshots older than specified date, with exclusions

# Configuration
DRY_RUN=0                  # Set to 1 to enable dry run mode
VERBOSE=1                  # Set to 1 to enable progress output
OWNER_ID="1234567890"      # AWS account owner ID
DAYS_TO_KEEP=1             # Number of days to keep snapshots (older will be deleted)
REGION="us-east-1"         # AWS region to operate in

# List of snapshots to exclude from deletion (in use by AMIs or otherwise protected)
PROTECTED_SNAPSHOTS=(
    "snap-0dc6b6ad009f3e9b9"
    "snap-018f0920e4609c47d"
    "snap-0a50ba7d31e038e53"
    "snap-046e5ba5aaa374904"
    "snap-00441faa7b0c933d7"
    "snap-0b3f49a9562aec5da"
    "snap-05489a1d590894d17"
    "snap-0d0138f9a74d82933"
)

# Calculate cutoff date (now - DAYS_TO_KEEP)
CUTOFF_DATE=$(date -d "$DAYS_TO_KEEP days ago" +'%Y-%m-%d')

# Logging function
log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# Validate AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Set AWS region
export AWS_DEFAULT_REGION=$REGION

log "Starting AWS Snapshot Cleanup"
log "Date of snapshots to delete (if older than): $CUTOFF_DATE"
log "Dry run mode: $([ "$DRY_RUN" -eq 1 ] && echo "ON" || echo "OFF")"
log "Protected snapshots: ${PROTECTED_SNAPSHOTS[*]}"

# Get list of snapshots older than cutoff date
log "Retrieving list of snapshots..."
SNAPSHOTS_TO_DELETE=$(aws ec2 describe-snapshots \
    --owner-ids "$OWNER_ID" \
    --output text \
    --query "Snapshots[?StartTime<'$CUTOFF_DATE'].SnapshotId" \
)

if [ -z "$SNAPSHOTS_TO_DELETE" ]; then
    log "No snapshots found older than $CUTOFF_DATE"
    exit 0
fi

log "Found ${#SNAPSHOTS_TO_DELETE[@]} snapshots to process"

# Process each snapshot
DELETED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for snapshot_id in $SNAPSHOTS_TO_DELETE; do
    # Check if snapshot is in protected list
    if [[ " ${PROTECTED_SNAPSHOTS[*]} " =~ " ${snapshot_id} " ]]; then
        log "Skipping protected snapshot: $snapshot_id"
        ((SKIPPED_COUNT++))
        continue
    fi

    log "Processing snapshot: $snapshot_id"

    # Check if snapshot is actually in use by any AMI
    ami_usage=$(aws ec2 describe-images --filters "Name=block-device-mapping.snapshot-id,Values=$snapshot_id" --query "Images[*].ImageId" --output text)
    
    if [ -n "$ami_usage" ]; then
        log "Skipping snapshot $snapshot_id in use by AMI(s): $ami_usage"
        ((SKIPPED_COUNT++))
        continue
    fi

    # Delete the snapshot (or dry run)
    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY RUN] Would delete snapshot: $snapshot_id"
        aws ec2 delete-snapshot --snapshot-id "$snapshot_id" --dry-run
    else
        log "Deleting snapshot: $snapshot_id"
        if aws ec2 delete-snapshot --snapshot-id "$snapshot_id"; then
            log "Successfully deleted snapshot: $snapshot_id"
            ((DELETED_COUNT++))
        else
            log "Error deleting snapshot: $snapshot_id"
            ((ERROR_COUNT++))
        fi
    fi
done

# Summary report
log "Cleanup completed:"
log "  Snapshots deleted: $DELETED_COUNT"
log "  Snapshots skipped: $SKIPPED_COUNT"
log "  Errors encountered: $ERROR_COUNT"

exit 0