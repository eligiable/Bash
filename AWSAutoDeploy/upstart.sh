#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s inherit_errexit

### Configuration ###
readonly VALID_ENVIRONMENTS=("staging" "production" "eu")
readonly APP_BASE_DIR="/secure/www/example"
readonly CONFIG_FILES=(
    "${APP_BASE_DIR}/core/config.php"
    "${APP_BASE_DIR}/core/Laravel/.env"
)

### Initialization ###
init() {
    validate_input "$@"
    setup_logging
    load_functions
    setup_environment
}

validate_input() {
    if [[ $# -ne 1 ]]; then
        log_error "Usage: $0 <environment>"
        log_error "Valid environments: ${VALID_ENVIRONMENTS[*]}"
        exit 1
    fi

    CONFIG_ENV="$1"
    if ! printf '%s\n' "${VALID_ENVIRONMENTS[@]}" | grep -q "^$CONFIG_ENV$"; then
        log_error "Invalid environment '$CONFIG_ENV'"
        exit 1
    fi
}

setup_logging() {
    readonly LOG_DIR="/var/log/instance-init"
    mkdir -p "$LOG_DIR"
    readonly LOG_FILE="${LOG_DIR}/init_$(date +%Y%m%d_%H%M%S).log"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

load_functions() {
    source /root/functions.sh || {
        log_error "Failed to load functions library"
        exit 1
    }
}

### Main Functions ###
setup_environment() {
    set_hostname
    configure_hosts
    setup_config_files
    configure_php
    configure_services
    setup_cron_jobs
    finalize_setup
}

set_hostname() {
    case "$CONFIG_ENV" in
        "staging") HOSTNAME="staging.example.com" ;;
        "production") HOSTNAME="secure.example.com" ;;
        "eu") HOSTNAME="eu.example.com" ;;
    esac

    log "Setting hostname to: $HOSTNAME"
    hostnamectl set-hostname "$HOSTNAME"
    echo "$HOSTNAME" > /etc/hostname
}

configure_hosts() {
    log "Configuring /etc/hosts"
    cat > /etc/hosts <<-EOF
		127.0.0.1   localhost localhost.localdomain $HOSTNAME
		::1         localhost localhost.localdomain $HOSTNAME
	EOF
}

setup_config_files() {
    log "Setting up configuration files for $CONFIG_ENV environment"
    
    for config_file in "${CONFIG_FILES[@]}"; do
        local src_file="${config_file}.${CONFIG_ENV}"
        
        if [[ ! -f "$src_file" ]]; then
            log_error "Source config file not found: $src_file"
            continue
        fi

        rm -f "$config_file"
        ln -s "$src_file" "$config_file"
        chown nginx:nginx "$config_file"
    done
}

configure_php() {
    log "Configuring PHP for $CONFIG_ENV environment"
    
    # PHP.ini configuration
    local php_ini_src="/etc/php-7.1.ini.${CONFIG_ENV}"
    if [[ -f "$php_ini_src" ]]; then
        ln -sf "$php_ini_src" "/etc/php.ini"
    fi

    # PHP-FPM configuration
    local php_fpm_conf="/etc/php-fpm.d/${CONFIG_ENV}"
    if [[ -f "$php_fpm_conf" ]]; then
        rm -f "/etc/php-fpm.d/www.conf"
        ln -sf "$php_fpm_conf" "/etc/php-fpm.d/www.conf"
    fi
}

configure_services() {
    log "Configuring services"
    
    # Nginx configuration
    local nginx_conf="/etc/nginx/vhosts/${HOSTNAME}"
    if [[ -d "$nginx_conf" ]]; then
        rm -f "/etc/nginx/vhosts/current.conf"
        ln -sf "$nginx_conf" "/etc/nginx/vhosts/current.conf"
    fi

    # Restart services
    local services=("php-fpm" "nginx" "supervisor")
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log "Restarting service: $service"
            systemctl restart "$service" || log_error "Failed to restart $service"
        fi
    done
}

setup_cron_jobs() {
    log "Setting up cron jobs for $CONFIG_ENV"
    
    if [[ "$CONFIG_ENV" =~ ^(production|eu)$ ]]; then
        configure_production_cron
    else
        log "No cron jobs required for $CONFIG_ENV environment"
    fi
}

configure_production_cron() {
    local cron_file=$(mktemp)
    
    cat > "$cron_file" <<-EOF
		CONFIG_ENV=$CONFIG_ENV
		# Monthly
		15 0 1 * * /usr/bin/php $APP_BASE_DIR/core/Cron/monthly.php
		# ETL
		10 0 * * * /usr/bin/php $APP_BASE_DIR/core/Cron/etl.php
		# Daily
		5 0 * * * /usr/bin/php $APP_BASE_DIR/core/Cron/daily.php
		# Hourly
		0 * * * * /usr/bin/php $APP_BASE_DIR/core/Cron/hourly.php
		# Files
		*/5 * * * * /usr/bin/php $APP_BASE_DIR/core/Cron/files.php
		# Minutely
		* * * * * /usr/bin/php $APP_BASE_DIR/core/Cron/minutely.php
		# Darkweb
		*/10 * * * * /usr/bin/php $APP_BASE_DIR/core/Cron/darkweb.php
		# Webhooks
		*/5 * * * * /usr/bin/php $APP_BASE_DIR/core/Cron/webhook.php
	EOF

    sudo -u nginx crontab "$cron_file"
    rm -f "$cron_file"
    log "Cron jobs configured successfully"
}

finalize_setup() {
    log "Cleaning up temporary files"
    rm -rf \
        "${APP_BASE_DIR}/core/Cache/DeviceDetector/*" \
        "${APP_BASE_DIR}/core/Cache/IpModelCollection/*" \
        "${APP_BASE_DIR}/core/Logs/*.log" \
        "${APP_BASE_DIR}/core/Laravel/storage/logs/*.log"

    log "Instance initialization completed successfully for $CONFIG_ENV environment"
}

### Main Execution ###
main() {
    init "$@"
    setup_environment
    exit 0
}

# Load functions if sourced, run main if executed
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi