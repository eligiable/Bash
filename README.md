# Bash
Bash Scripts to Automate

### AWS Auto Deploy

> This system provides automated deployment of applications across AWS regions (US and EU) with blue-green deployment strategy. The solution includes instance creation, AMI management, load balancer updates, and automated cleanup.

### Mongo Self-Signed Certificate

> This project provides scripts to automate the generation of SSL/TLS certificates for MongoDB clusters with proper Subject Alternative Names (SANs) for secure communication between nodes.

### Remote Logging

> This rsyslog configuration sets up a centralized log server that: Listens on both UDP and TCP ports 61514 for remote logs, Organizes received logs by hostname and program name in daily files, Disables local logging to avoid duplication (when using systemd journal), and Includes proper journal integration and performance optimizations.

### Delete AWS EBS Snapshots

> Deletes EBS snapshots older than specified date, with exclusions.

### Clear AWS Media Store Stream

> This script deletes all objects in an AWS MediaStore stream path, Requires: awscli, jq.

### Clear RAM Cache

> This script clears the system's RAM cache and provides before/after memory statistics, Requires: bc (calculator) - will be installed automatically if missing.

### ELK Stack 7x

> Installs and configures ELK Stack (Elasticsearch, Logstash, Kibana) and Beats.

### Install XMRRig

> Install XMRRig on Ubuntu 14/16.

### Magento2 JSON Cache Validator

> This script checks if JSON generation is running, validates the existence of required cache directories and files, counts JSON files per store, and triggers regeneration if needed. It's designed to ensure product/category JSON cache is properly maintained for a Magento 2 store.

### MongoDB Backup to S3

> This script performs a backup of a MongoDB database, compresses it, and uploads it to an AWS S3 bucket. It includes logging, error handling, and cleanup.

### MongoDB OPLog Incremental Backup

> This script performs incremental backups of MongoDB's oplog by dumping all operations that occurred since the last backup. It's designed to run periodically (e.g., hourly) to maintain a continuous backup of all database changes.

### Restore Magento2 Prod to Stagging

> This script performs the following operations: Backs up admin users from production database, Restores a production database backup to staging environment, Creates a parallel backup database, and Handles data sanitization and format conversion.

### Server Maintenance

> Performs comprehensive server maintenance tasks.

### Sync Static Website to S3

> This script performs two main functions: Syncs a local website directory to an S3 bucket while excluding specific file types that will be handled separately. Fixes content-type metadata for common web file types in the S3 bucket by setting the correct MIME types.

### Restore MySQL Backup from S3

> Shell Script to download MySQL Backup from S3, perform some specific Operations and Restore.

### Server Maintenance 

> Shell Script to automate common server maintenance tasks and send email alerts.

### Static Website Hosting on S3

> Shell Script to upload files to AWS S3 Static Website Hosting because AWS S3 mismatches the header of the Static Content.

### Website Health Monitor

> Monitors website availability and manages MySQL sleep connections when the site is down. Sends email notifications for status changes.

### Website Status Monitor

> This script checks if a website is online by attempting to access it multiple times. It verifies the HTTP status code and provides appropriate exit codes for monitoring systems.