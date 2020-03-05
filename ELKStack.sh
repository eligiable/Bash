#!/bin/bash

# This script will install the lastest ELK Stable Release under 7.x
# Set below the Beats version you want to install.
version=7.6.1

# Update/Upgrade Repository
echo "$(tput setaf 2) --- Performing upgrade ---"
sudo apt update && apt -y upgrade && apt -y autoremove && apt -y autoclean && apt clean

# Set Timezone to Asia/Dubai
echo "$(tput setaf 3) --- Setting Timezone to Asia/Dubai ---" && echo "$(tput setaf 7)"
sudo timedatectl set-timezone Asia/Dubai
date

# Install Java 8
echo "$(tput setaf 3) --- Installing Java 8 ---" && echo "$(tput setaf 7)"
sudo apt install openjdk-8-jdk

# Install Elasticsearch Debian Package 
# ref: https://www.elastic.co/guide/en/elasticsearch/reference/current/deb.html
echo "$(tput setaf 3) --- Setting up public signing key ---" && echo "$(tput setaf 7)"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "$(tput setaf 3) --- Installing the apt-transport-https package ---" && echo "$(tput setaf 7)"
sudo apt-get install apt-transport-https
sudo apt update
echo "$(tput setaf 3) --- Saving Repository Definition to /etc/apt/sources/list.d/elastic-7.x.list ---" && echo "$(tput setaf 7)"
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
echo "$(tput setaf 3) --- Installing the Elasticsearch Debian Package ---" && echo "$(tput setaf 7)"
sudo apt-get update && sudo apt-get install elasticsearch

# Install Kibana
echo "$(tput setaf 3) --- Installing the Kibana Debian Package ---" && echo "$(tput setaf 7)"
sudo apt-get install kibana

# Install Logstash
echo "$(tput setaf 3) --- Installing Logstash ---" && echo "$(tput setaf 7)"
sudo apt-get install logstash

# Install Filebeat
echo "$(tput setaf 3) --- Installing Filebeat ---" && echo "$(tput setaf 7)"
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${version}-amd64.deb
sudo dpkg -i filebeat-7.6.1-amd64.deb
sudo rm filebeat*
sudo filebeat modules enable system
sudo filebeat modules enable cisco
sudo filebeat modules enable netflow
sudo filebeat modules enable osquery
sudo filebeat modules enable elasticsearch
sudo filebeat modules enable kibana
sudo filebeat modules enable logstash

# Install Packetbeat
echo "$(tput setaf 3) --- Installing Packetbeat ---" && echo "$(tput setaf 7)"
sudo apt-get install libpcap0.8
curl -L -O https://artifacts.elastic.co/downloads/beats/packetbeat/packetbeat-${version}-amd64.deb
sudo dpkg -i packetbeat-7.6.1-amd64.deb
sudo rm packetbeat*

# Install Metricbeat
echo "$(tput setaf 3) --- Installing Metricbeat ---" && echo "$(tput setaf 7)"
curl -L -O https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-${version}-amd64.deb
sudo dpkg -i metricbeat-7.6.1-amd64.deb
sudo rm metricbeat*
sudo metricbeat modules enable elasticsearch
sudo metricbeat modules enable kibana
sudo metricbeat modules enable logstash
sudo metricbeat modules enable system

# Install Heartbeat
echo "$(tput setaf 3) --- Installing Heartbeat ---" && echo "$(tput setaf 7)"
curl -L -O https://artifacts.elastic.co/downloads/beats/heartbeat/heartbeat-${version}-amd64.deb
sudo dpkg -i heartbeat-7.6.1-amd64.deb
sudo rm heartbeat*

# Install Auditbeat
echo "$(tput setaf 3) --- Installing Auditbeat ---" && echo "$(tput setaf 7)"
curl -L -O https://artifacts.elastic.co/downloads/beats/auditbeat/auditbeat-${version}-amd64.deb
sudo dpkg -i auditbeat-7.6.1-amd64.deb
sudo rm auditbeat*

# Starting ELK Stack
echo "$(tput setaf 3) --- Starting Elasticsearch ---" && echo "$(tput setaf 7)"
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service
sudo /bin/systemctl start elasticsearch.service

echo "$(tput setaf 3) --- Starting Kibana ---" && echo "$(tput setaf 7)"
sudo /bin/systemctl enable kibana.service
sudo /bin/systemctl start kibana.service

echo "$(tput setaf 3) --- Starting Logstash ---" && echo "$(tput setaf 7)"
sudo /bin/systemctl enable logstash.service
sudo /bin/systemctl start logstash.service

# Waiting for ELK Stack to Wakeup
echo "$(tput setaf 3) --- Waiting for ELK Stack to Start the Services ---" && echo "$(tput setaf 7)"
sleep 1m

# Starting Beats
echo "$(tput setaf 3) --- Starting Filebeat ---" && echo "$(tput setaf 7)"
sudo systemctl enable filebeat
sudo systemctl start filebeat
sudo filebeat setup -e
sudo filebeat setup --dashboards
sudo filebeat setup --index-management
sudo filebeat setup --pipelines

echo "$(tput setaf 3) --- Starting Packetbeat ---" && echo "$(tput setaf 7)"
sudo systemctl enable packetbeat
sudo systemctl start packetbeat
sudo packetbeat setup -e
sudo packetbeat setup --dashboards
sudo packetbeat setup --index-management
sudo packetbeat setup --pipelines

echo "$(tput setaf 3) --- Starting Metricbeat ---" && echo "$(tput setaf 7)"
sudo systemctl enable metricbeat
sudo systemctl start metricbeat
sudo metricbeat setup -e
sudo metricbeat setup --dashboards
sudo metricbeat setup --index-management
sudo metricbeat setup --pipelines

echo "$(tput setaf 3) --- Starting Heartbeat ---" && echo "$(tput setaf 7)"
sudo systemctl enable heartbeat
sudo systemctl start heartbeat
sudo auditbeat setup -e
sudo auditbeat setup --dashboards
sudo auditbeat setup --index-management
sudo auditbeat setup --pipelines

echo "$(tput setaf 3) --- Starting Auditbeat ---" && echo "$(tput setaf 7)"
sudo systemctl enable auditbeat
sudo systemctl start auditbeat
sudo auditbeat setup -e
sudo auditbeat setup --dashboards
sudo auditbeat setup --index-management
sudo auditbeat setup --pipelines

# Edit Configuration
echo "$(tput setaf 2) --- Finsh Configuration as mentioned below: ---"
echo "$(tput setaf 3) 1. edit kibana.yml and change server.host to 0.0.0.0 so that you can connect to kibana from other systems http://IPADDRESS:5601"
echo "$(tput setaf 3) 2. edit elasticsearch.yml and change network.host to 0.0.0.0 so that other systems can send data to elasticsearch"
echo "$(tput setaf 3) 3. restart both services sudo systemctl restart elasticsearch kibana"
echo "$(tput setaf 7)
