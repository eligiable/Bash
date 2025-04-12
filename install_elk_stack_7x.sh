#!/bin/bash

# Description: Installs and configures ELK Stack (Elasticsearch, Logstash, Kibana) and Beats

# Configuration Section
ELK_VERSION="7.6.1"  # ELK Stack version to install
TIMEZONE="Asia/Dubai"  # Timezone configuration
ELASTICSEARCH_HOST="0.0.0.0"  # Elasticsearch bind address
KIBANA_HOST="0.0.0.0"  # Kibana bind address

# Color Definitions
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
RESET=$(tput sgr0)

# Function to print section headers
section() {
    echo ""
    echo "${BLUE}=== $1 ===${RESET}"
    echo ""
}

# Function to check command success
check_command() {
    if [ $? -ne 0 ]; then
        echo "${RED}Error: $1 failed!${RESET}"
        exit 1
    fi
}

# Start Installation
section "Starting ELK Stack Installation (v$ELK_VERSION)"

# System Update
section "System Update & Upgrade"
echo "${YELLOW}Performing system update and upgrade...${RESET}"
sudo apt update && sudo apt -y upgrade && sudo apt -y autoremove && sudo apt -y autoclean
check_command "System update"

# Timezone Configuration
section "Timezone Configuration"
echo "${YELLOW}Setting timezone to $TIMEZONE...${RESET}"
sudo timedatectl set-timezone $TIMEZONE
date
check_command "Timezone setting"

# Java Installation
section "Java Installation"
echo "${YELLOW}Installing Java 8...${RESET}"
sudo apt install -y openjdk-8-jdk
check_command "Java installation"
java -version

# Elasticsearch Installation
section "Elasticsearch Installation"
echo "${YELLOW}Setting up Elasticsearch repository...${RESET}"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install -y apt-transport-https
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
sudo apt-get update
sudo apt-get install -y elasticsearch=$ELK_VERSION
check_command "Elasticsearch installation"

# Kibana Installation
section "Kibana Installation"
echo "${YELLOW}Installing Kibana...${RESET}"
sudo apt-get install -y kibana=$ELK_VERSION
check_command "Kibana installation"

# Logstash Installation
section "Logstash Installation"
echo "${YELLOW}Installing Logstash...${RESET}"
sudo apt-get install -y logstash=$ELK_VERSION
check_command "Logstash installation"

# Beats Installation Function
install_beat() {
    local beat_name=$1
    section "$beat_name Installation"
    echo "${YELLOW}Installing $beat_name...${RESET}"
    curl -L -O https://artifacts.elastic.co/downloads/beats/$beat_name/$beat_name-${ELK_VERSION}-amd64.deb
    sudo dpkg -i $beat_name-${ELK_VERSION}-amd64.deb
    sudo rm $beat_name-${ELK_VERSION}-amd64.deb
    check_command "$beat_name installation"
}

# Install Beats
install_beat "filebeat"
install_beat "packetbeat"
install_beat "metricbeat"
install_beat "heartbeat"
install_beat "auditbeat"

# APM Server Installation
section "APM Server Installation"
echo "${YELLOW}Installing APM Server...${RESET}"
curl -L -O https://artifacts.elastic.co/downloads/apm-server/apm-server-${ELK_VERSION}-amd64.deb
sudo dpkg -i apm-server-${ELK_VERSION}-amd64.deb
sudo rm apm-server-${ELK_VERSION}-amd64.deb
check_command "APM Server installation"

# Configure Services
section "Service Configuration"
echo "${YELLOW}Configuring Elasticsearch to listen on $ELASTICSEARCH_HOST...${RESET}"
sudo sed -i "s/#network.host: 192.168.0.1/network.host: $ELASTICSEARCH_HOST/" /etc/elasticsearch/elasticsearch.yml
sudo sed -i "s/#cluster.initial_master_nodes:.*/cluster.initial_master_nodes: [\"$(hostname)\"]/" /etc/elasticsearch/elasticsearch.yml

echo "${YELLOW}Configuring Kibana to listen on $KIBANA_HOST...${RESET}"
sudo sed -i "s/#server.host: \"localhost\"/server.host: \"$KIBANA_HOST\"/" /etc/kibana/kibana.yml

# Enable and Start Services
section "Starting ELK Stack Services"
services=("elasticsearch" "kibana" "logstash" "filebeat" "packetbeat" "metricbeat" "heartbeat" "auditbeat" "apm-server")

for service in "${services[@]}"; do
    echo "${YELLOW}Enabling and starting $service...${RESET}"
    sudo systemctl enable $service
    sudo systemctl start $service
    check_command "$service service start"
done

# Setup Beats
section "Setting Up Beats"
beats=("filebeat" "packetbeat" "metricbeat" "auditbeat")

for beat in "${beats[@]}"; do
    echo "${YELLOW}Setting up $beat...${RESET}"
    sudo $beat setup -e
    sudo $beat setup --dashboards
    sudo $beat setup --index-management
    sudo $beat setup --pipelines
done

# Final Checks
section "Installation Complete"
echo "${GREEN}ELK Stack installation completed successfully!${RESET}"
echo ""
echo "${YELLOW}Next Steps:${RESET}"
echo "1. Access Kibana at http://$(hostname -I | awk '{print $1}'):5601"
echo "2. Configure your beats to send data to this server"
echo "3. Check service status with: sudo systemctl status elasticsearch kibana logstash"
echo ""
echo "${BLUE}=== Installation Finished ===${RESET}"