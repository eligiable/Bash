#!/bin/bash

# Config here
export AWS_ACCESS_KEY=ACCESS_KEY
export AWS_SECRET_KEY=SECRET_KEY
export EC2_REGION="us-east-1"
export SECURE_ROLE_ARN="ARN:instance-profile/ec2production"

# Functions
source ./functions.sh

# Initial data
PROD_IP="0.0.0.0"
PROD_EIPALLOC="eipalloc-00000000"
TEST_IP="0.0.0.0"
TEST_EIPALLOC="eipalloc-00000000"
APP_VERSION=$(cat /secure/www/#!/bin/bash

# Config here
export AWS_ACCESS_KEY=ACCESS_KEY
export AWS_SECRET_KEY=SECRET_KEY
export EC2_REGION="us-east-1"
export SECURE_ROLE_ARN="ARN:instance-profile/ec2production"

# Functions
source ./functions.sh

# Initial data
PROD_IP="0.0.0.0"
PROD_EIPALLOC="eipalloc-00000000"
TEST_IP="0.0.0.0"
TEST_EIPALLOC="eipalloc-00000000"
APP_VERSION=$(cat /secure/www/ahaseeb/core/config.production.php | grep '"VERSION"' | awk '{print $3}' | perl  -pe 's/[^0-9\.]//g')
CURRENT_TIMESTAMP=$(date +%s)
LOG_FILE="./"$APP_VERSION"_"$CURRENT_TIMESTAMP".log"
echo "Deploying application version: "$APP_VERSION
echo "Getting Staging instance ID...."
MY_INSTANCE_ID=$(/usr/bin/curl -sq http://0.0.0.0/2008-02-01/meta-data/instance-id)
echo "Staging instance ID: "$MY_INSTANCE_ID

# Creating amazon machine image from instance
echo ""
echo " ** STAGE 1. CREATING AMI FOR DEPLOYMENT"
echo "Creating IMAGE from Staging..."
NEW_AMI_NAME="DeploymentImage_"$APP_VERSION"_"$CURRENT_TIMESTAMP
NEW_AMI_ID=$(ec2cim --no-reboot -n $NEW_AMI_NAME $MY_INSTANCE_ID | grep "IMAGE" | awk '{print $2}')
if [ -z $NEW_AMI_ID ]; then
  echo "Can't create new AMI. Exiting..."
  safe_exit
  exit 1
fi

AMI_STATE=$(ec2-describe-images $NEW_AMI_ID | grep IMAGE | awk '{print $5}')
while [ ! "$AMI_STATE" = "available" ]; do
  echo "Waiting for AMI: "$NEW_AMI_ID"... Waiting..."
  sleep 5
  AMI_STATE=$(ec2-describe-images $NEW_AMI_ID | grep IMAGE | awk '{print $5}')
done
ec2-create-tags $NEW_AMI_ID --tag Version=$APP_VERSION
echo "Image has been successfully created. Image ID: "$NEW_AMI_ID

# Launch instance from amazon machine image
echo ""
echo " ** STAGE 2. LAUNCHING INSTANCES ON VPC"
echo "Trying to launch main instance in public subnet(us-east-1a) from this AMI..."
INSTANCES[0]=$(ec2-run-instances --instance-count 1 --instance-type t3.medium -m --key secure.ahaseeb.com --group sg-d6ed1ea2 --user-data-file ./user-data.production \
--iam-profile $SECURE_ROLE_ARN --availability-zone us-east-1a --subnet subnet-765a951d --instance-initiated-shutdown-behavior stop $NEW_AMI_ID | grep INSTANCE | awk '{print $2}')
ec2-create-tags ${INSTANCES[0]} --tag Name=secure.ahaseeb.com
ec2-create-tags ${INSTANCES[0]} --tag Version=$APP_VERSION
INSTANCE_PRIVATE_HOST[0]=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $5}')
while [ -z "${INSTANCE_PRIVATE_HOST[0]}" ]; do
  echo "Waiting for instance private IP of instance with id: "${INSTANCES[0]}
  sleep 3
  INSTANCE_PRIVATE_HOST[0]=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $5}')
done
echo "Instance has been successfully launched! Private host: "${INSTANCE_PRIVATE_HOST[0]}
echo "Instance has been successfully launched! Instance ID: ${INSTANCES[0]}"

echo "Trying to launch secondary instance in private subnet(us-east-1c) from this AMI..."
INSTANCES[1]=$(ec2-run-instances --instance-count 1 --instance-type t3.medium -m --key secure.ahaseeb.com --group sg-d6ed1ea2 --user-data-file ./user-data.production \
--iam-profile $SECURE_ROLE_ARN --availability-zone us-east-1c --subnet subnet-0d80e3f6908462729 --instance-initiated-shutdown-behavior stop $NEW_AMI_ID | grep INSTANCE | awk '{print $2}')
ec2-create-tags ${INSTANCES[1]} --tag Name=secure.ahaseeb.com
ec2-create-tags ${INSTANCES[1]} --tag Version=$APP_VERSION
INSTANCE_PRIVATE_HOST[1]=$(ec2-describe-instances ${INSTANCES[1]} | grep INSTANCE | awk -F $'\t' '{print $5}')
while [ -z "${INSTANCE_PRIVATE_HOST[1]}" ]; do
  echo "Waiting for instance public IP of instance with id: "${INSTANCES[1]}
  sleep 3
  INSTANCE_PRIVATE_HOST[1]=$(ec2-describe-instances ${INSTANCES[1]} | grep INSTANCE | awk -F $'\t' '{print $5}')
done
echo "Instance has been successfully launched! Private host: "${INSTANCE_PRIVATE_HOST[1]}
echo "Instance has been successfully launched! Instance ID: ${INSTANCES[1]}"
CHECK_INSTANCE_STATE=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $6}')
while [ "$CHECK_INSTANCE_STATE" != "running" ]; do
  echo "Waiting for instance state \"running\" for instance: ${INSTANCES[1]}. Current state is $CHECK_INSTANCE_STATE"
  sleep 3
  CHECK_INSTANCE_STATE=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $6}')
done
# echo "Disassociation IP: "$TEST_IP"..."
# ASSOCIATION_ID=$(ec2daddr $TEST_IP | awk -F $'\t' '{print $6}')
# echo "ASSOCIATION_ID is $ASSOCIATION_ID"
# ec2disaddr -a $ASSOCIATION_ID
echo "Association IP: "$TEST_IP" with new instance: "${INSTANCES[0]}"..."
ec2assocaddr -a $TEST_EIPALLOC -i ${INSTANCES[0]}

# Checking your already launched instance
echo ""
echo " ** STAGE 3. TESTING NEW INSTANCES"
echo "Wait untill instances came to active state.. Usually it takes about 5 mins"
echo "and after check runned instance using public hosts provided above ^^^."
echo "Use promt bellow to confirm what everything is going smooth."
echo "MAKE SURE WHAT ALL NEW RUNED INSTANCES HAVE TAGGED WITH NEW VERSION!!!"
sleep 20

while true; do
    read -p "Everything is OK? Do you wonna register instances on ELBs?" yn
    case $yn in
        [Yy]* ) echo 'yes'; break;;
        [Nn]* ) safe_exit;; #TODO: cleaning here
        * ) echo "Please answer yes or no.";;
    esac
done

# Changing current production instance with pre-production instance on loadbalancers
echo ""
echo " ** STAGE 4. UPDATING ELB"
echo "Updating ELB secure..."
elb-register-instances-with-lb vpcsecure --instances ${INSTANCES[0]},${INSTANCES[1]} -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
echo "Updating ELB sslsecure..."
elb-register-instances-with-lb vpcsslsecure --instances ${INSTANCES[0]},${INSTANCES[1]} -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY

# Changing current production instance with pre-production instance on loadbalancers
echo ""
echo " ** STAGE 4.5 UPDATING MAIN INSTANCE IP"
echo "Disassociation TEMP IP: "$TEST_IP"..."
ec2disaddr -a $(ec2daddr | grep $TEST_IP | awk '{print $6}')
echo "Disassociation PROD IP: "$PROD_IP"..."
ec2disaddr -a $(ec2daddr | grep $PROD_IP | awk '{print $6}')
echo "Association PROD IP: "$PROD_IP" with new instance: "${INSTANCES[0]}"..."
ec2assocaddr -a $PROD_EIPALLOC -i ${INSTANCES[0]}

# Create new launch config, and remove old
echo ""
echo " ** STAGE 5. UPDATING AUTOSCALING CONFIGURATION"
ASG_NAME="asg_vpc_secure"
NEW_LC_NAME="lc_vpc_secure_version_"$APP_VERSION
OLD_LC_NAME=$(as-describe-auto-scaling-groups $ASG_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY | awk '{print $3}')
OLD_AMI_NAME=$(as-describe-launch-configs $OLD_LC_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY | awk '{print $3}')
echo "Creating new launch configuration with new AMI..."
as-create-launch-config $NEW_LC_NAME --image-id $NEW_AMI_ID  --monitoring-enabled --instance-type t3.medium --key secure.ahaseeb.com --group sg-d6ed1ea2 --user-data-file $PWD/user-data.production --iam-instance-profile $SECURE_ROLE_ARN -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
if [ $? -eq 0 ]; then
  echo "Updating autoscaling group  with new launch config..."
  as-update-auto-scaling-group $ASG_NAME --launch-configuration $NEW_LC_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
  echo "Removing old one launch config and old AMI..."
  as-delete-launch-config $OLD_LC_NAME -f -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
  ec2-deregister $OLD_AMI_NAME
else
  echo "  !!! ERROR: Cant create launch config!"
fi

# Update CloudWatch Alarms
echo ""
echo " ** STAGE 6. UPDATING CLOUDWATCH ALARMS"
POLICY_SCALEUP_NAME="ARN:autoScalingGroupName/asg_vpc_secure:policyName/ScaleUP"
POLICY_SCALEDOWN_NAME="ARN:autoScalingGroupName/asg_vpc_secure:policyName/ScaleDOWN"
mon-put-metric-alarm --alarm-name secureAMIHighCPULoad --alarm-description "secureAMIHighCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average  --period 60 --threshold 75 --comparison-operator GreaterThanThreshold  --dimensions ImageId=$NEW_AMI_ID --evaluation-periods 3  --unit Percent --alarm-actions $POLICY_SCALEUP_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
mon-put-metric-alarm --alarm-name secureAMILowCPULoad --alarm-description "secureAMILowCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average  --period 60 --threshold 50 --comparison-operator LessThanThreshold  --dimensions ImageId=$NEW_AMI_ID --evaluation-periods 3  --unit Percent --alarm-actions $POLICY_SCALEDOWN_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY

# Remove old instances...
echo ""
echo " ** STAGE 7. REMOVING OLD INSTANCES"
OLD_INSTANCES=$(ec2-describe-instances --filter "tag:Name=secure.ahaseeb.com" | grep TAG | grep Version | grep -v $APP_VERSION | awk '{print $3}')

for OLD_INSTANCE in $OLD_INSTANCES;
do
  echo "De-registering instance "$OLD_INSTANCE" from ELB secure..."
  elb-deregister-instances-from-lb vpcsecure --instances $OLD_INSTANCE -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
  echo "De-registering instance "$OLD_INSTANCE" from ELB sslsecure..."
  elb-deregister-instances-from-lb vpcsslsecure --instances $OLD_INSTANCE -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
done

## Exiting
echo "Done!"
safe_exit/core/config.production.php | grep '"VERSION"' | awk '{print $3}' | perl  -pe 's/[^0-9\.]//g')
CURRENT_TIMESTAMP=$(date +%s)
LOG_FILE="./"$APP_VERSION"_"$CURRENT_TIMESTAMP".log"
echo "Deploying application version: "$APP_VERSION
echo "Getting Staging instance ID...."
MY_INSTANCE_ID=$(/usr/bin/curl -sq http://0.0.0.0/2008-02-01/meta-data/instance-id)
echo "Staging instance ID: "$MY_INSTANCE_ID

# Creating amazon machine image from instance
echo ""
echo " ** STAGE 1. CREATING AMI FOR DEPLOYMENT"
echo "Creating IMAGE from Staging..."
NEW_AMI_NAME="DeploymentImage_"$APP_VERSION"_"$CURRENT_TIMESTAMP
NEW_AMI_ID=$(ec2cim --no-reboot -n $NEW_AMI_NAME $MY_INSTANCE_ID | grep "IMAGE" | awk '{print $2}')
if [ -z $NEW_AMI_ID ]; then
  echo "Can't create new AMI. Exiting..."
  safe_exit
  exit 1
fi

AMI_STATE=$(ec2-describe-images $NEW_AMI_ID | grep IMAGE | awk '{print $5}')
while [ ! "$AMI_STATE" = "available" ]; do
  echo "Waiting for AMI: "$NEW_AMI_ID"... Waiting..."
  sleep 5
  AMI_STATE=$(ec2-describe-images $NEW_AMI_ID | grep IMAGE | awk '{print $5}')
done
ec2-create-tags $NEW_AMI_ID --tag Version=$APP_VERSION
echo "Image has been successfully created. Image ID: "$NEW_AMI_ID

# Launch instance from amazon machine image
echo ""
echo " ** STAGE 2. LAUNCHING INSTANCES ON VPC"
echo "Trying to launch main instance in public subnet(us-east-1a) from this AMI..."
INSTANCES[0]=$(ec2-run-instances --instance-count 1 --instance-type t3.medium -m --key secure.ahaseeb.com --group sg-d6ed1ea2 --user-data-file ./user-data.production \
--iam-profile $SECURE_ROLE_ARN --availability-zone us-east-1a --subnet subnet-765a951d --instance-initiated-shutdown-behavior stop $NEW_AMI_ID | grep INSTANCE | awk '{print $2}')
ec2-create-tags ${INSTANCES[0]} --tag Name=secure.ahaseeb.com
ec2-create-tags ${INSTANCES[0]} --tag Version=$APP_VERSION
INSTANCE_PRIVATE_HOST[0]=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $5}')
while [ -z "${INSTANCE_PRIVATE_HOST[0]}" ]; do
  echo "Waiting for instance private IP of instance with id: "${INSTANCES[0]}
  sleep 3
  INSTANCE_PRIVATE_HOST[0]=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $5}')
done
echo "Instance has been successfully launched! Private host: "${INSTANCE_PRIVATE_HOST[0]}
echo "Instance has been successfully launched! Instance ID: ${INSTANCES[0]}"

echo "Trying to launch secondary instance in private subnet(us-east-1c) from this AMI..."
INSTANCES[1]=$(ec2-run-instances --instance-count 1 --instance-type t3.medium -m --key secure.ahaseeb.com --group sg-d6ed1ea2 --user-data-file ./user-data.production \
--iam-profile $SECURE_ROLE_ARN --availability-zone us-east-1c --subnet subnet-0d80e3f6908462729 --instance-initiated-shutdown-behavior stop $NEW_AMI_ID | grep INSTANCE | awk '{print $2}')
ec2-create-tags ${INSTANCES[1]} --tag Name=secure.ahaseeb.com
ec2-create-tags ${INSTANCES[1]} --tag Version=$APP_VERSION
INSTANCE_PRIVATE_HOST[1]=$(ec2-describe-instances ${INSTANCES[1]} | grep INSTANCE | awk -F $'\t' '{print $5}')
while [ -z "${INSTANCE_PRIVATE_HOST[1]}" ]; do
  echo "Waiting for instance public IP of instance with id: "${INSTANCES[1]}
  sleep 3
  INSTANCE_PRIVATE_HOST[1]=$(ec2-describe-instances ${INSTANCES[1]} | grep INSTANCE | awk -F $'\t' '{print $5}')
done
echo "Instance has been successfully launched! Private host: "${INSTANCE_PRIVATE_HOST[1]}
echo "Instance has been successfully launched! Instance ID: ${INSTANCES[1]}"
CHECK_INSTANCE_STATE=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $6}')
while [ "$CHECK_INSTANCE_STATE" != "running" ]; do
  echo "Waiting for instance state \"running\" for instance: ${INSTANCES[1]}. Current state is $CHECK_INSTANCE_STATE"
  sleep 3
  CHECK_INSTANCE_STATE=$(ec2-describe-instances ${INSTANCES[0]} | grep INSTANCE | awk -F $'\t' '{print $6}')
done
# echo "Disassociation IP: "$TEST_IP"..."
# ASSOCIATION_ID=$(ec2daddr $TEST_IP | awk -F $'\t' '{print $6}')
# echo "ASSOCIATION_ID is $ASSOCIATION_ID"
# ec2disaddr -a $ASSOCIATION_ID
echo "Association IP: "$TEST_IP" with new instance: "${INSTANCES[0]}"..."
ec2assocaddr -a $TEST_EIPALLOC -i ${INSTANCES[0]}

# Checking your already launched instance
echo ""
echo " ** STAGE 3. TESTING NEW INSTANCES"
echo "Wait untill instances came to active state.. Usually it takes about 5 mins"
echo "and after check runned instance using public hosts provided above ^^^."
echo "Use promt bellow to confirm what everything is going smooth."
echo "MAKE SURE WHAT ALL NEW RUNED INSTANCES HAVE TAGGED WITH NEW VERSION!!!"
sleep 20

while true; do
    read -p "Everything is OK? Do you wonna register instances on ELBs?" yn
    case $yn in
        [Yy]* ) echo 'yes'; break;;
        [Nn]* ) safe_exit;; #TODO: cleaning here
        * ) echo "Please answer yes or no.";;
    esac
done

# Changing current production instance with pre-production instance on loadbalancers
echo ""
echo " ** STAGE 4. UPDATING ELB"
echo "Updating ELB secure..."
elb-register-instances-with-lb vpcsecure --instances ${INSTANCES[0]},${INSTANCES[1]} -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
echo "Updating ELB sslsecure..."
elb-register-instances-with-lb vpcsslsecure --instances ${INSTANCES[0]},${INSTANCES[1]} -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY

# Changing current production instance with pre-production instance on loadbalancers
echo ""
echo " ** STAGE 4.5 UPDATING MAIN INSTANCE IP"
echo "Disassociation TEMP IP: "$TEST_IP"..."
ec2disaddr -a $(ec2daddr | grep $TEST_IP | awk '{print $6}')
echo "Disassociation PROD IP: "$PROD_IP"..."
ec2disaddr -a $(ec2daddr | grep $PROD_IP | awk '{print $6}')
echo "Association PROD IP: "$PROD_IP" with new instance: "${INSTANCES[0]}"..."
ec2assocaddr -a $PROD_EIPALLOC -i ${INSTANCES[0]}

# Create new launch config, and remove old
echo ""
echo " ** STAGE 5. UPDATING AUTOSCALING CONFIGURATION"
ASG_NAME="asg_vpc_secure"
NEW_LC_NAME="lc_vpc_secure_version_"$APP_VERSION
OLD_LC_NAME=$(as-describe-auto-scaling-groups $ASG_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY | awk '{print $3}')
OLD_AMI_NAME=$(as-describe-launch-configs $OLD_LC_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY | awk '{print $3}')
echo "Creating new launch configuration with new AMI..."
as-create-launch-config $NEW_LC_NAME --image-id $NEW_AMI_ID  --monitoring-enabled --instance-type t3.medium --key secure.ahaseeb.com --group sg-d6ed1ea2 --user-data-file $PWD/user-data.production --iam-instance-profile $SECURE_ROLE_ARN -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
if [ $? -eq 0 ]; then
  echo "Updating autoscaling group  with new launch config..."
  as-update-auto-scaling-group $ASG_NAME --launch-configuration $NEW_LC_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
  echo "Removing old one launch config and old AMI..."
  as-delete-launch-config $OLD_LC_NAME -f -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
  ec2-deregister $OLD_AMI_NAME
else
  echo "  !!! ERROR: Cant create launch config!"
fi

# Update CloudWatch Alarms
echo ""
echo " ** STAGE 6. UPDATING CLOUDWATCH ALARMS"
POLICY_SCALEUP_NAME="ARN:autoScalingGroupName/asg_vpc_secure:policyName/ScaleUP"
POLICY_SCALEDOWN_NAME="ARN:autoScalingGroupName/asg_vpc_secure:policyName/ScaleDOWN"
mon-put-metric-alarm --alarm-name secureAMIHighCPULoad --alarm-description "secureAMIHighCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average  --period 60 --threshold 75 --comparison-operator GreaterThanThreshold  --dimensions ImageId=$NEW_AMI_ID --evaluation-periods 3  --unit Percent --alarm-actions $POLICY_SCALEUP_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
mon-put-metric-alarm --alarm-name secureAMILowCPULoad --alarm-description "secureAMILowCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average  --period 60 --threshold 50 --comparison-operator LessThanThreshold  --dimensions ImageId=$NEW_AMI_ID --evaluation-periods 3  --unit Percent --alarm-actions $POLICY_SCALEDOWN_NAME -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY

# Remove old instances...
echo ""
echo " ** STAGE 7. REMOVING OLD INSTANCES"
OLD_INSTANCES=$(ec2-describe-instances --filter "tag:Name=secure.ahaseeb.com" | grep TAG | grep Version | grep -v $APP_VERSION | awk '{print $3}')

for OLD_INSTANCE in $OLD_INSTANCES;
do
  echo "De-registering instance "$OLD_INSTANCE" from ELB secure..."
  elb-deregister-instances-from-lb vpcsecure --instances $OLD_INSTANCE -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
  echo "De-registering instance "$OLD_INSTANCE" from ELB sslsecure..."
  elb-deregister-instances-from-lb vpcsslsecure --instances $OLD_INSTANCE -I $AWS_ACCESS_KEY -S $AWS_SECRET_KEY
done

## Exiting
echo "Done!"
safe_exit
