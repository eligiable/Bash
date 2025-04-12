#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s inherit_errexit

### Constants ###
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

### Logging Functions ###
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    log "ERROR: $*" >&2
}

### AWS Operations ###
validate_aws_credentials() {
    log "Validating AWS credentials..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials validation failed"
        return 1
    fi
    log "AWS credentials validated successfully"
}

check_dependencies() {
    local required_commands=("aws" "jq" "curl")
    local missing=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi
    
    # Verify AWS CLI version
    local aws_version
    aws_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d'/' -f2)
    if [[ "$(printf '%s\n' "2.0.0" "$aws_version" | sort -V | head -n1)" != "2.0.0" ]]; then
        log_error "AWS CLI version $aws_version is older than required 2.0.0"
        return 1
    fi
    
    log "All dependencies verified successfully"
}

### Resource Cleanup ###
clean_resources() {
    local region="$1"
    local resource_id="$2"
    local resource_type="$3"
    
    case "$resource_type" in
        "ami")
            clean_ami "$region" "$resource_id"
            ;;
        "instance")
            clean_instance "$region" "$resource_id"
            ;;
        *)
            log_error "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

clean_ami() {
    local region="$1"
    local ami_id="$2"
    
    log "Cleaning up AMI: $ami_id in region $region"
    
    # Get associated snapshots
    local snapshots
    snapshots=$(aws ec2 describe-images \
        --region "$region" \
        --image-ids "$ami_id" \
        --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' \
        --output text 2>/dev/null) || {
        log_error "Failed to get snapshots for AMI $ami_id"
        return 1
    }

    # Delete snapshots
    for snapshot in $snapshots; do
        if [[ -n "$snapshot" && "$snapshot" != "None" ]]; then
            log "Deleting snapshot: $snapshot"
            if ! aws ec2 delete-snapshot --region "$region" --snapshot-id "$snapshot"; then
                log_error "Failed to delete snapshot $snapshot"
            fi
        fi
    done

    # Deregister AMI
    log "Deregistering AMI: $ami_id"
    if ! aws ec2 deregister-image --region "$region" --image-id "$ami_id"; then
        log_error "Failed to deregister AMI $ami_id"
        return 1
    fi

    log "Successfully cleaned up AMI: $ami_id"
}

clean_instance() {
    local region="$1"
    local instance_id="$2"
    
    log "Cleaning up instance: $instance_id in region $region"
    
    # Terminate instance
    if ! aws ec2 terminate-instances --region "$region" --instance-ids "$instance_id"; then
        log_error "Failed to terminate instance $instance_id"
        return 1
    fi
    
    log "Successfully terminated instance: $instance_id"
}

### Retry Mechanism ###
retry_operation() {
    local cmd="$1"
    local description="$2"
    local retries=0
    
    while (( retries < MAX_RETRIES )); do
        if eval "$cmd"; then
            return 0
        fi
        
        (( retries++ )) || true
        log "Retrying $description... Attempt $retries/$MAX_RETRIES"
        sleep $RETRY_DELAY
    done
    
    log_error "Failed to $description after $MAX_RETRIES attempts"
    return 1
}

### Safe Exit Handler ###
setup_exit_handler() {
    trap 'safe_exit' EXIT TERM INT
}

safe_exit() {
    local exit_code=$?
    
    # Unset sensitive environment variables
    unset AWS_ACCESS_KEY AWS_SECRET_KEY AWS_CREDENTIAL_FILE AWS_SESSION_TOKEN
    
    # Additional cleanup if needed
    if [[ -n "${CLEANUP_RESOURCES:-}" && "${CLEANUP_ON_EXIT:-true}" == "true" ]]; then
        log "Performing cleanup before exit..."
        clean_resources "$CLEANUP_RESOURCES"
    fi
    
    exit "$exit_code"
}