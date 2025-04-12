#!/bin/bash

# Configuration
CONFIG_FILE="mongo-cert-vars.sh"
BACKUP_FILE="${CONFIG_FILE}.bak"
TEMP_DIR="/tmp/certs_$(date +%Y%m%d%H%M%S)"
DEFAULT_USER="ec2-user"
REMOTE_DIR="/home/${DEFAULT_USER}/certs"

# Text Colors
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
ENDC="\e[0m"

# Error Handling
function error_exit {
    echo -e "${RED}[ERROR] $1${ENDC}" >&2
    exit 1
}

# Backup original config file
cp "${CONFIG_FILE}" "${BACKUP_FILE}" || error_exit "Failed to backup config file"

# Certificate Name
echo -e -n "${YELLOW}Enter a name for your Certificate (without extensions): ${ENDC}"
read -r certName
[[ -z "$certName" ]] && error_exit "Certificate name cannot be empty"

# DNS Values
declare -a dns_entries
for i in {1..5}; do
    echo -e -n "${YELLOW}Enter DNS Name $i (leave empty to skip): ${ENDC}"
    read -r dns_entry
    [[ -n "$dns_entry" ]] && dns_entries+=("$dns_entry")
done

# IP Addresses
declare -a ip_addresses
for i in {1..3}; do
    echo -e -n "${YELLOW}Enter IP for Server $i (leave empty to skip): ${ENDC}"
    read -r ip_entry
    [[ -n "$ip_entry" ]] && ip_addresses+=("$ip_entry")
done

# Update DNS Values in config
if [[ ${#dns_entries[@]} -gt 0 ]]; then
    for i in "${!dns_entries[@]}"; do
        sed -i "s/DNS.$((i+1))/${dns_entries[i]}/" "${CONFIG_FILE}" || error_exit "Failed to update DNS in config"
    done
fi

# Create temporary directory
mkdir -p "${TEMP_DIR}" || error_exit "Failed to create temp directory"

# Certificate Generation
echo -e "${GREEN}Generating Certificate...${ENDC}"
openssl req -config "${CONFIG_FILE}" -newkey rsa:4096 -sha256 \
    -new -x509 -days 730 -nodes \
    -out "${TEMP_DIR}/${certName}.crt" \
    -keyout "${TEMP_DIR}/${certName}.key" \
    || error_exit "Certificate generation failed"

# Verify certificate
openssl x509 -in "${TEMP_DIR}/${certName}.crt" -noout -text \
    || error_exit "Certificate verification failed"

# Merging Certificate into .pem
echo -e "${GREEN}Creating .pem file...${ENDC}"
cat "${TEMP_DIR}/${certName}.key" "${TEMP_DIR}/${certName}.crt" > "${TEMP_DIR}/${certName}.pem" \
    || error_exit "Failed to create PEM file"

# Set proper permissions
chmod 600 "${TEMP_DIR}"/* || error_exit "Failed to set file permissions"

# Display certificate
read -r -p "${YELLOW}Would you like to view the Certificate? [y/N]: ${ENDC}" response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    openssl x509 -in "${TEMP_DIR}/${certName}.pem" -text -noout
fi

# Copy to remote nodes if IPs provided
if [[ ${#ip_addresses[@]} -gt 0 ]]; then
    echo -e "${GREEN}Copying Certificates to remote nodes...${ENDC}"
    for ip in "${ip_addresses}"; do
        echo -e "${BLUE}Copying to ${ip}...${ENDC}"
        ssh "${DEFAULT_USER}@${ip}" "mkdir -p ${REMOTE_DIR}" || echo "Failed to create remote dir on ${ip}"
        scp -p "${TEMP_DIR}/${certName}."* "${DEFAULT_USER}@${ip}:${REMOTE_DIR}/" \
            || echo "Failed to copy to ${ip}"
    done
fi

# Restore original config
mv "${BACKUP_FILE}" "${CONFIG_FILE}" || error_exit "Failed to restore original config"

echo -e "${GREEN}Certificate generation complete! Files are in:${ENDC}"
echo -e "${BLUE}${TEMP_DIR}${ENDC}"
echo -e "${GREEN}To clean up later, run: rm -rf ${TEMP_DIR}${ENDC}"