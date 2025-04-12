# AWS Auto Deployment

## Overview
This system provides automated deployment of applications across AWS regions (US and EU) with blue-green deployment strategy. The solution includes instance creation, AMI management, load balancer updates, and automated cleanup.

## Prerequisites
- AWS CLI v2+ configured with proper credentials
- jq installed for JSON processing
- Bash 4.0+ for script execution
- IAM permissions for EC2, ELB, and Auto Scaling operations

## Configuration Guide

### 1. Environment Setup
Before running the deployment, configure these files:

#### `run.sh`
```bash
# AWS Credentials (recommend using IAM roles instead)
export AWS_ACCESS_KEY="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_KEY="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Deployment Configuration
export SECURE_ROLE_ARN="arn:aws:iam::123456789012:instance-profile/ec2production"
export US_INSTANCE_TYPE="t3.medium"
export EU_INSTANCE_TYPE="t3.small"

# Network Configuration
export PROD_IP="203.0.113.10"
export TEST_IP="203.0.113.20"
export EU_PROD_IP="198.51.100.10"
export EU_TEST_IP="198.51.100.20"

# Application Paths
export APP_CONFIG_PATH="/secure/www/your_app/core/config.production.php"
```

#### `upstart.sh`
```bash
# Hostname Configuration
HOSTNAME="secure.yourdomain.com"  # For production
# OR
HOSTNAME="eu.yourdomain.com"      # For EU deployment
# OR 
HOSTNAME="staging.yourdomain.com" # For staging

# Application Symlinks
APP_BASE="/secure/www/your_app"
```

### 2. Required AWS Resources
Ensure these resources exist before deployment:
- VPC with public/private subnets in each AZ
- Security groups for application instances
- IAM instance profile with necessary permissions
- Target groups for load balancers

## Deployment Execution

### Basic Usage
```bash
./run.sh
```

The script will prompt you to select deployment region(s):
1. US only (us-east-1)
2. EU only (eu-west-1) 
3. Both regions
4. Quit

### Deployment Process
The system follows this workflow:
1. Creates AMI from staging instance
2. Launches new instances in selected region(s)
3. Registers instances with load balancers
4. Updates auto scaling configurations
5. Cleans up old resources

### Logging
All deployment activity is logged to:
```
/var/log/deployments/deployment_YYYYMMDD_HHMMSS.log
```

## Maintenance

### Manual Cleanup
To clean up resources if deployment fails:
```bash
# For US resources
aws ec2 deregister-image --image-id ami-xxxxxxxx --region us-east-1
aws ec2 delete-snapshot --snapshot-id snap-xxxxxxxx --region us-east-1

# For EU resources 
aws ec2 deregister-image --image-id ami-xxxxxxxx --region eu-west-1
aws ec2 delete-snapshot --snapshot-id snap-xxxxxxxx --region eu-west-1
```

### Updating Deployment
To modify the deployment:
1. Update configuration in `run.sh`
2. Test changes in staging environment
3. Commit changes to version control
4. Deploy to production using the updated script

## Best Practices

1. **Security**
   - Use IAM roles instead of hardcoded credentials
   - Restrict security group rules to minimum required access
   - Regularly rotate any used credentials

2. **Reliability**
   - Test deployments in staging first
   - Monitor deployment logs for errors
   - Set up CloudWatch alarms for deployment metrics

3. **Maintenance**
   - Review and update instance types annually
   - Keep AMI creation scripts up-to-date
   - Regularly test rollback procedures

## Troubleshooting

### Common Issues
**AMI Creation Fails**
- Verify source instance is in running state
- Check IAM permissions for EC2 image creation
- Ensure no ongoing maintenance on AWS side

**Instance Launch Fails**
- Verify subnet and security group IDs are correct
- Check instance type availability in target AZ
- Review instance limits in your AWS account

**Load Balancer Registration Fails**
- Confirm target group ARN is correct
- Verify instances pass health checks
- Check security group allows LB traffic