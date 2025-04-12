#!/bin/bash

set -o errexit          # Exit on any error
set -o nounset          # Exit on undefined variables
set -o pipefail         # Pipeline fails if any command fails
shopt -s inherit_errexit # Make subshells inherit errexit

### Configuration Section ###
readonly DEPLOYMENT_REGIONS=("us-east-1" "eu-west-1")  # Supported regions
readonly SCRIPT_NAME=$(basename "$0")
readonly LOG_DIR="/var/log/deployments"
readonly LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
readonly -A INSTANCE_TYPES=(
    ["us-east-1"]="t3.medium"
    ["eu-west-1"]="t3.small"
)
readonly -A SUBNET_IDS=(
    ["us-east-1a"]="subnet-XXXXXXXX"
    ["us-east-1c"]="subnet-YYYYYYYY"
    ["eu-west-1a"]="subnet-ZZZZZZZZ"
)
readonly -A SECURITY_GROUP_IDS=(
    ["us-east-1"]="sg-XXXXXXXX"
    ["eu-west-1"]="sg-YYYYYYYY"
)
readonly -A KEY_NAMES=(
    ["us-east-1"]="secure.example.com"
    ["eu-west-1"]="secure.example.com-EU"
)

### Initialization ###
init() {
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    
    # Configure logging
    readonly LOG_FILE="${LOG_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"
    exec > >(tee -a "${LOG_FILE}") 2>&1
    
    # Load functions
    source ./functions.sh || {
        log_error "Failed to load functions.sh"
        exit 1
    }
    
    # Check dependencies
    check_dependencies || exit 1
    
    # Validate AWS credentials
    validate_aws_credentials || exit 1
    
    # Set trap for cleanup
    trap 'cleanup_on_exit' EXIT TERM INT
}

### Logging Functions ###
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    log "ERROR: $*" >&2
}

### Main Deployment Functions ###
get_app_version() {
    local config_file="/secure/www/example/core/config.production.php"
    grep -oP '(?<="VERSION", ")[^"]+' "${config_file}" || {
        log_error "Failed to get app version from ${config_file}"
        return 1
    }
}

create_ami() {
    local region="$1"
    local instance_id="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local ami_name="DeploymentImage_${APP_VERSION}_${timestamp}"
    
    log "Creating AMI from instance ${instance_id} in ${region}"
    
    local ami_id
    ami_id=$(aws ec2 create-image \
        --region "${region}" \
        --instance-id "${instance_id}" \
        --name "${ami_name}" \
        --no-reboot \
        --output text) || {
        log_error "Failed to create AMI"
        return 1
    }
    
    log "Created AMI: ${ami_id}"
    
    # Tag the AMI
    aws ec2 create-tags \
        --region "${region}" \
        --resources "${ami_id}" \
        --tags \
            "Key=Name,Value=${APP_VERSION}" \
            "Key=Environment,Value=Production" \
            "Key=CreatedBy,Value=${SCRIPT_NAME}" || {
        log_error "Failed to tag AMI ${ami_id}"
        return 1
    }
    
    # Wait for AMI to be available
    wait_for_ami "${region}" "${ami_id}" || return 1
    
    echo "${ami_id}"
}

wait_for_ami() {
    local region="$1"
    local ami_id="$2"
    local max_attempts=30
    local sleep_seconds=30
    
    log "Waiting for AMI ${ami_id} to become available..."
    
    for ((i=1; i<=max_attempts; i++)); do
        local state
        state=$(aws ec2 describe-images \
            --region "${region}" \
            --image-ids "${ami_id}" \
            --query 'Images[0].State' \
            --output text)
        
        case "${state}" in
            "available")
                log "AMI ${ami_id} is now available"
                return 0
                ;;
            "failed")
                log_error "AMI creation failed"
                return 1
                ;;
            *)
                if (( i % 5 == 0 )); then
                    log "AMI state: ${state} (attempt ${i}/${max_attempts})"
                fi
                sleep "${sleep_seconds}"
                ;;
        esac
    done
    
    log_error "Timeout waiting for AMI ${ami_id} to become available"
    return 1
}

launch_instance() {
    local region="$1"
    local ami_id="$2"
    local az="$3"
    local instance_type="${INSTANCE_TYPES[$region]}"
    local subnet_id="${SUBNET_IDS[$az]}"
    local sg_id="${SECURITY_GROUP_IDS[$region]}"
    local key_name="${KEY_NAMES[$region]}"
    
    log "Launching instance in ${region} (${az}) from AMI ${ami_id}"
    
    local instance_id
    instance_id=$(aws ec2 run-instances \
        --region "${region}" \
        --placement "AvailabilityZone=${az}" \
        --image-id "${ami_id}" \
        --instance-type "${instance_type}" \
        --subnet-id "${subnet_id}" \
        --security-group-ids "${sg_id}" \
        --key-name "${key_name}" \
        --monitoring "Enabled=true" \
        --iam-instance-profile "Arn=${SECURE_ROLE_ARN}" \
        --user-data "file://user-data.production" \
        --query 'Instances[0].InstanceId' \
        --output text) || {
        log_error "Failed to launch instance in ${region}"
        return 1
    }
    
    log "Launched instance: ${instance_id}"
    
    # Tag the instance
    aws ec2 create-tags \
        --region "${region}" \
        --resources "${instance_id}" \
        --tags \
            "Key=Name,Value=secure.example.com" \
            "Key=Version,Value=${APP_VERSION}" \
            "Key=Environment,Value=Production" || {
        log_error "Failed to tag instance ${instance_id}"
        return 1
    }
    
    # Wait for instance to be running
    wait_for_instance "${region}" "${instance_id}" || return 1
    
    # Get private IP
    local private_ip
    private_ip=$(aws ec2 describe-instances \
        --region "${region}" \
        --instance-ids "${instance_id}" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text) || {
        log_error "Failed to get private IP for instance ${instance_id}"
        return 1
    }
    
    echo "${instance_id} ${private_ip}"
}

wait_for_instance() {
    local region="$1"
    local instance_id="$2"
    local max_attempts=30
    local sleep_seconds=10
    
    log "Waiting for instance ${instance_id} to be running..."
    
    for ((i=1; i<=max_attempts; i++)); do
        local state
        state=$(aws ec2 describe-instances \
            --region "${region}" \
            --instance-ids "${instance_id}" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text)
        
        case "${state}" in
            "running")
                log "Instance ${instance_id} is now running"
                return 0
                ;;
            "failed"|"terminated"|"shutting-down")
                log_error "Instance ${instance_id} entered bad state: ${state}"
                return 1
                ;;
            *)
                if (( i % 5 == 0 )); then
                    log "Instance state: ${state} (attempt ${i}/${max_attempts})"
                fi
                sleep "${sleep_seconds}"
                ;;
        esac
    done
    
    log_error "Timeout waiting for instance ${instance_id} to be running"
    return 1
}

update_load_balancer() {
    local region="$1"
    local instance_id="$2"
    local target_group_arn="$3"
    
    log "Registering instance ${instance_id} with target group ${target_group_arn}"
    
    aws elbv2 register-targets \
        --region "${region}" \
        --target-group-arn "${target_group_arn}" \
        --targets "Id=${instance_id}" || {
        log_error "Failed to register instance with target group"
        return 1
    }
    
    log "Successfully registered instance with target group"
}

### Cleanup Functions ###
cleanup_on_exit() {
    local exit_code=$?
    
    # Release lock
    rm -f "${LOCK_FILE}"
    
    # Unset sensitive variables
    unset AWS_ACCESS_KEY AWS_SECRET_KEY AWS_CREDENTIAL_FILE
    
    if (( exit_code != 0 )); then
        log_error "Script exited with error (code: ${exit_code})"
        # Additional cleanup can be added here
    fi
    
    exit "${exit_code}"
}

### Main Execution ###
main() {
    # Prevent concurrent executions
    if [ -e "${LOCK_FILE}" ]; then
        log_error "Script is already running (lock file exists)"
        exit 1
    fi
    touch "${LOCK_FILE}"
    
    init
    
    # Get application version
    readonly APP_VERSION=$(get_app_version) || exit 1
    log "Starting deployment of application version: ${APP_VERSION}"
    
    # Get current instance ID
    readonly MY_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    log "Source instance ID: ${MY_INSTANCE_ID}"
    
    # Deployment region selection
    PS3="Select deployment region(s): "
    options=("US only" "EU only" "Both regions" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "US only")
                deploy_region "us-east-1"
                break
                ;;
            "EU only")
                deploy_region "eu-west-1"
                break
                ;;
            "Both regions")
                deploy_region "us-east-1"
                deploy_region "eu-west-1"
                break
                ;;
            "Quit")
                exit 0
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
    
    log "Deployment completed successfully"
    exit 0
}

deploy_region() {
    local region="$1"
    log "Starting deployment in region: ${region}"
    
    # Create AMI
    local ami_id
    ami_id=$(create_ami "${region}" "${MY_INSTANCE_ID}") || {
        log_error "AMI creation failed for region ${region}"
        return 1
    }
    
    # Launch instances (primary and secondary for US, single for EU)
    local azs=()
    if [[ "${region}" == "us-east-1" ]]; then
        azs=("us-east-1a" "us-east-1c")
    else
        azs=("eu-west-1a")
    fi
    
    local instances=()
    for az in "${azs[@]}"; do
        local instance_info
        instance_info=$(launch_instance "${region}" "${ami_id}" "${az}") || {
            log_error "Instance launch failed in ${az}"
            return 1
        }
        instances+=("${instance_info}")
    done
    
    # Update load balancer
    local target_group_arn=""
    if [[ "${region}" == "us-east-1" ]]; then
        target_group_arn="arn:aws:elasticloadbalancing:us-east-1:ACCOUNT_ID:targetgroup/vpcsecure/TARGET_ID"
    else
        target_group_arn="arn:aws:elasticloadbalancing:eu-west-1:ACCOUNT_ID:targetgroup/vpcsecure-eu/TARGET_ID"
    fi
    
    for instance_info in "${instances[@]}"; do
        local instance_id=$(echo "${instance_info}" | awk '{print $1}')
        update_load_balancer "${region}" "${instance_id}" "${target_group_arn}" || {
            log_error "Failed to update load balancer for instance ${instance_id}"
            return 1
        }
    done
    
    # Additional region-specific steps would go here
    # (EIP association, autoscaling updates, etc.)
    
    log "Successfully completed deployment in region: ${region}"
}

# Execute main function
main "$@"