#!/bin/bash
set -x

# Environmental Vars
export AWS_ACCESS_KEY={YOUR_VALUE}
export AWS_SECRET_KEY={YOUR_VALUE}
export SECURE_ROLE_ARN="arn:aws:iam::{YOUR_VALUE}:instance-profile/ec2production"

# Functions
source ./functions.sh

# Global Vars
## US Env. Vars
US_INSTANCE_TYPE="t3.medium"
PROD_IP="{YOUR_VALUE}"
PROD_EIPALLOC="eipalloc-{YOUR_VALUE}"
TEST_IP="{YOUR_VALUE}"
TEST_EIPALLOC="eipalloc-{YOUR_VALUE}"

## EU Env. Vars
EU_INSTANCE_TYPE="t3.small"
EU_PROD_IP="{YOUR_VALUE}"
EU_PROD_EIPALLOC="eipalloc-{YOUR_VALUE}"
EU_TEST_IP="{YOUR_VALUE}"
EU_TEST_EIPALLOC="eipalloc-{YOUR_VALUE}"

## App Control Vars
APP_VERSION=$(cat /secure/www/{YOUR_VALUE}/core/config.production.php | grep '"VERSION"' | awk '{print $3}' | perl  -pe 's/[^0-9\.]//g')
CURRENT_TIMESTAMP=$(date +%s)
LOG_FILE="./"$APP_VERSION"_"$CURRENT_TIMESTAMP".log"
echo "Deploying application version: "$APP_VERSION
echo "Getting Staging instance ID...."
MY_INSTANCE_ID=$(/usr/bin/curl -sq http://{YOUR_VALUE}/meta-data/instance-id)
echo "Staging instance ID: "$MY_INSTANCE_ID

# Deployment
## STAGE 0: Select Region
echo " ** STAGE 0. DEPLOYMENT REGION"
read -p "Enter 'us' for deployment in US Region, 'eu' for deployment in Ireland, or 'all' to deploy on both: " choice

## US STAGE 1: Create Image from Staging
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

# US STAGE 1: Verify Created Image from Staging
AMI_STATE=$(aws ec2 describe-images --region us-east-1 --image-ids "$NEW_AMI_ID" | jq -r '.Images[0].State')
while [ ! "$AMI_STATE" = "available" ]; do
  echo "Waiting for AMI: "$NEW_AMI_ID"... Waiting..."
  sleep 5
  AMI_STATE=$(aws ec2 describe-images --region us-east-1 --image-ids "$NEW_AMI_ID" | jq -r '.Images[0].State')
done

aws ec2 create-tags --region us-east-1 --resources "$NEW_AMI_ID" --tags Key=Name,Value=$APP_VERSION
echo "Image has been successfully created. Image ID: "$NEW_AMI_ID

## US Deployment Start
if [ "$choice" == "us" ] || [ "$choice" == "all" ]; then

# US STAGE 2: Launch Primary Instance from Staging Image
echo ""
echo " ** STAGE 2. LAUNCHING INSTANCES ON VPC"
echo "Trying to launch main instance in public subnet(us-east-1a) from $NEW_AMI_ID AMI..."

INSTANCES[0]=$(aws ec2 run-instances --region us-east-1 --placement AvailabilityZone=us-east-1a --monitoring Enabled=true --image-id "$NEW_AMI_ID" --subnet-id subnet-{YOUR_VALUE} --security-group-ids sg-{YOUR_VALUE} --key-name secure.{YOUR_VALUE}.com --iam-instance-profile Arn="$SECURE_ROLE_ARN" --instance-type $US_INSTANCE_TYPE --user-data file://user-data.production | jq -r '.Instances[0].InstanceId')

aws ec2 create-tags --region us-east-1 --resources "${INSTANCES[0]}" --tags Key=Name,Value=secure.{YOUR_VALUE}.com
aws ec2 create-tags --region us-east-1 --resources "${INSTANCES[0]}" --tags Key=Version,Value="$APP_VERSION"

INSTANCE_PRIVATE_HOST[0]=$(aws ec2 describe-instances --region us-east-1 --instance-ids ${INSTANCES[0]} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
while [ -z "$INSTANCE_PRIVATE_HOST[0]" ]; do
  echo "Waiting for instance private IP of instance with id: "${INSTANCES[0]}
  sleep 3
  INSTANCE_PRIVATE_HOST[0]=$(aws ec2 describe-instances --region us-east-1 --instance-ids ${INSTANCES[0]} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
done

echo "Instance has been successfully launched! Private host: "${INSTANCE_PRIVATE_HOST[0]}
echo "Instance has been successfully launched! Instance ID: ${INSTANCES[0]}"

## US STAGE 2: Launch Secondary Instance from Staging Image
echo "Trying to launch secondary instance in private subnet(us-east-1c) from $NEW_AMI_ID AMI..."

INSTANCES[1]=$(aws ec2 run-instances --region us-east-1 --placement AvailabilityZone=us-east-1c --monitoring Enabled=true --image-id "$NEW_AMI_ID" --subnet-id subnet-{YOUR_VALUE} --security-group-ids sg-{YOUR_VALUE} --key-name secure.{YOUR_VALUE}.com --iam-instance-profile Arn="$SECURE_ROLE_ARN" --instance-type $US_INSTANCE_TYPE --user-data file://user-data.production | jq -r '.Instances[0].InstanceId')

aws ec2 create-tags --region us-east-1 --resources "${INSTANCES[1]}" --tags Key=Name,Value=secure.{YOUR_VALUE}.com
aws ec2 create-tags --region us-east-1 --resources "${INSTANCES[1]}" --tags Key=Version,Value="$APP_VERSION"

INSTANCE_PRIVATE_HOST[1]=$(aws ec2 describe-instances --region us-east-1 --instance-ids ${INSTANCES[1]} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
while [ -z "$INSTANCE_PRIVATE_HOST[1]" ]; do
  echo "Waiting for instance private IP of instance with id: "${INSTANCES[1]}
  sleep 3
  INSTANCE_PRIVATE_HOST[1]=$(aws ec2 describe-instances --region us-east-1 --instance-ids ${INSTANCES[1]} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
done

echo "Instance has been successfully launched! Private host: "${INSTANCE_PRIVATE_HOST[0]}
echo "Instance has been successfully launched! Instance ID: ${INSTANCES[1]}"

# US STAGE 2: Verify newly created Instance(s) State
CHECK_INSTANCE_STATE=$(aws ec2 describe-instances --region us-east-1 --instance-ids ${INSTANCES[0]} | jq -r '.Reservations[0].Instances[0].State.Name')
while [ "$CHECK_INSTANCE_STATE" != "running" ]; do
  echo "Waiting for instance state \"running\" for instance: ${INSTANCES[1]}. Current state is $CHECK_INSTANCE_STATE"
  sleep 3
  CHECK_INSTANCE_STATE=$(aws ec2 describe-instances --region us-east-1 --instance-ids ${INSTANCES[0]} | jq -r '.Reservations[0].Instances[0].State.Name')
done

echo "Association IP: "$TEST_IP" with new instance: "${INSTANCES[0]}"..."
aws ec2 associate-address --region us-east-1 --allocation-id $TEST_EIPALLOC --instance-id ${INSTANCES[0]}

## US STAGE 3: Verifying newly launched Instances
echo ""
echo " ** STAGE 3. TESTING NEW INSTANCES"
echo "Wait untill instances came to active state.. Usually it takes about 5 mins"
echo "and after check runned instance using public hosts provided above ^^^."
echo "Use promt bellow to confirm what everything is going smooth."
echo "MAKE SURE WHAT ALL NEW RUNED INSTANCES HAVE TAGGED WITH NEW VERSION!!!"
sleep 20

while true; do
    read -p "Everything is OK? Do you wonna register instances on LBs?" yn
    case $yn in
        [Yy]* ) echo 'yes'; break;;
        [Nn]* ) safe_exit;; #TODO: cleaning here
        * ) echo "Please answer yes or no.";;
    esac
done

## US STAGE 4: Update Loadbalncer with newly launched Instances
echo ""
echo " ** STAGE 4. UPDATING LB"

echo "Updating ALB secure..."
aws elbv2 register-targets --region us-east-1 --target-group-arn arn:aws:elasticloadbalancing:us-east-1:{YOUR_VALUE}:targetgroup/vpcsecure/{YOUR_VALUE} --targets Id=${INSTANCES[0]} Id=${INSTANCES[1]}

# US STAGE 4.5 Update newly launched Instances IPs
echo ""
echo " ** STAGE 4.5 UPDATING MAIN INSTANCE IP"

echo "Disassociation TEMP IP: "$TEST_IP"..."
aws ec2 disassociate-address --region us-east-1 --public-ip $TEST_IP

echo "Disassociation PROD IP: "$PROD_IP"..."
aws ec2 disassociate-address --region us-east-1 --public-ip $PROD_IP

echo "Association PROD IP: "$PROD_IP" with new instance: "${INSTANCES[0]}"..."
aws ec2 associate-address --region us-east-1 --instance-id ${INSTANCES[0]} --public-ip $PROD_IP

## US STAGE 5: Update Autoscale Group and Launch Configuration
echo ""
echo " ** STAGE 5. UPDATING AUTOSCALING CONFIGURATION"
ASG_NAME="asg_vpc_secure"
NEW_LC_NAME="lc_vpc_secure_version_"$APP_VERSION"_"$CURRENT_TIMESTAMP
OLD_LC_NAME=$(aws autoscaling describe-auto-scaling-groups --region us-east-1 --auto-scaling-group-name $ASG_NAME | jq -r '.AutoScalingGroups[0].LaunchConfigurationName')
OLD_AMI_NAME=$(aws autoscaling describe-launch-configurations --region us-east-1 --launch-configuration-names $OLD_LC_NAME  | jq -r '.LaunchConfigurations[0].ImageId')

echo "Creating new launch configuration with new AMI..."
aws autoscaling create-launch-configuration --launch-configuration-name $NEW_LC_NAME  --region us-east-1 --image-id $NEW_AMI_ID --instance-type $US_INSTANCE_TYPE --security-groups sg-{YOUR_VALUE} --key-name secure.{YOUR_VALUE}.com --user-data file://user-data.production --iam-instance-profile $SECURE_ROLE_ARN --instance-monitoring Enabled=true

if [ $? -eq 0 ]; then
  echo "Updating autoscaling group  with new launch config..."
  aws autoscaling update-auto-scaling-group --region us-east-1 --auto-scaling-group-name $ASG_NAME  --launch-configuration-name $NEW_LC_NAME
  echo "Removing old launch config and old AMI..."
  aws autoscaling delete-launch-configuration --region us-east-1 --launch-configuration-name $OLD_LC_NAME
  aws ec2 deregister-image --region us-east-1 --image-id $OLD_AMI_NAME
else
 echo "  !!! ERROR: Cant create launch config!"
fi

## STAGE 6: Update CloudWatch Alarms
echo ""
echo " ** STAGE 6. UPDATING CLOUDWATCH ALARMS"
POLICY_SCALEUP_NAME="arn:aws:autoscaling:us-east-1:{YOUR_VALUE}:scalingPolicy:11a13eba-bf78-493e-86b7-a3f43be82485:autoScalingGroupName/asg_vpc_secure:policyName/ScaleUP"
POLICY_SCALEDOWN_NAME="arn:aws:autoscaling:us-east-1:{YOUR_VALUE}:scalingPolicy:8930c805-94fa-4023-b17e-74a63996a1c7:autoScalingGroupName/asg_vpc_secure:policyName/ScaleDOWN"

aws cloudwatch put-metric-alarm --region us-east-1 --alarm-name secureAMIHighCPULoad --alarm-description "secureAMIHighCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 75 --comparison-operator GreaterThanThreshold  --dimensions "Name=ImageId,Value=$NEW_AMI_ID" --evaluation-periods 3 --alarm-actions $POLICY_SCALEUP_NAME  --unit Percent

aws cloudwatch put-metric-alarm --region us-east-1 --alarm-name secureAMILowCPULoad --alarm-description "secureAMILowCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 50 --comparison-operator GreaterThanThreshold  --dimensions "Name=ImageId,Value=$NEW_AMI_ID" --evaluation-periods 3 --alarm-actions $POLICY_SCALEDOWN_NAME  --unit Percent

## STAGE 7: Remove Old Instances
echo ""
echo " ** STAGE 7. REMOVING OLD INSTANCES"
OLD_INSTANCES_VERSION=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Name,Values=secure.{YOUR_VALUE}.com" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[?Tags[?Key==`Version` && Value!=`'$APP_VERSION'`]].InstanceId' --output text)

for OLD_INSTANCE in $OLD_INSTANCES_VERSION;
do
  echo "De-registering instance "$OLD_INSTANCES" from ALB vpcsecure..."
  aws elbv2 deregister-targets --region us-east-1 --target-group-arn arn:aws:elasticloadbalancing:us-east-1:{YOUR_VALUE}:targetgroup/vpcsecure/{YOUR_VALUE} --targets Id=$OLD_INSTANCES
done

## US Deployment End
echo "Done!"
safe_exit
fi

# EU Deployment Start
if [ "$choice" == "eu" ] || [ "$choice" == "all" ]; then

## EU STAGE 1: Copy Image from US-Staging
echo ""
echo " ** STAGE 2. COPYING AMI TO EU REGION"
echo "Copying AMI to EU region..."
EU_AMI_ID=$(aws ec2 copy-image --source-region us-east-1 --source-image-id "$NEW_AMI_ID" --name "$NEW_AMI_NAME" --region eu-west-1 | jq -r '.ImageId')
if [ -z "$EU_AMI_ID" ]; then
    echo "Failed to copy the AMI to the EU region. Exiting..."
    safe_exit
    exit 1
fi

echo "Successfully copied AMI to EU region. EU AMI ID: $EU_AMI_ID"

# EU STAGE 1: Verify Created Image from US-Staging
EU_AMI_STATE=$(aws ec2 describe-images --region eu-west-1 --image-ids "$EU_AMI_ID" | jq -r '.Images[0].State')
while [ ! "$EU_AMI_STATE" = "available" ]; do
  echo "Waiting for AMI: "$EU_AMI_ID"... Waiting..."
  sleep 5
  EU_AMI_STATE=$(aws ec2 describe-images --region eu-west-1 --image-ids "$EU_AMI_ID" | jq -r '.Images[0].State')
done

aws ec2 create-tags --region eu-west-1 --resources "$EU_AMI_ID" --tags Key=Name,Value=$APP_VERSION
echo "Image has been successfully created. Image ID: "$EU_AMI_ID

## EU STAGE 2: Launch Instance from copied Staging Image
echo ""
echo " ** STAGE 2. LAUNCHING INSTANCES ON VPC"
echo "Trying to launch main instance in public subnet(eu-west-1a) from $EU_AMI_ID this AMI..."

EU_INSTANCES=$(aws ec2 run-instances --region eu-west-1 --placement AvailabilityZone=eu-west-1a --monitoring Enabled=true --image-id "$EU_AMI_ID" --subnet-id subnet-{YOUR_VALUE} --security-group-ids sg-{YOUR_VALUE} --key-name secure.{YOUR_VALUE}.com-EU --iam-instance-profile Arn="$SECURE_ROLE_ARN" --instance-type $EU_INSTANCE_TYPE --user-data file://user-data.eu | jq -r '.Instances[0].InstanceId')

aws ec2 create-tags --region eu-west-1 --resources "$EU_INSTANCES" --tags Key=Name,Value=eu.{YOUR_VALUE}.com
aws ec2 create-tags --region eu-west-1 --resources "$EU_INSTANCES" --tags Key=Version,Value="$APP_VERSION"

EU_INSTANCE_PRIVATE_HOST=$(aws ec2 describe-instances --region eu-west-1 --instance-ids $EU_INSTANCES | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
while [ -z "$EU_INSTANCE_PRIVATE_HOST" ]; do
  echo "Waiting for instance private IP of instance with id: "$EU_INSTANCES
  sleep 3
  EU_INSTANCE_PRIVATE_HOST=$(aws ec2 describe-instances --region eu-west-1 --instance-ids $EU_INSTANCES | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
done

echo "Instance has been successfully launched! Private host: "$EU_INSTANCE_PRIVATE_HOST
echo "Instance has been successfully launched! Instance ID: $EU_INSTANCES"

# EU STAGE 2: Verify newly created Instance(s) State
CHECK_INSTANCE_STATE=$(aws ec2 describe-instances --region eu-west-1 --instance-ids $EU_INSTANCES | jq -r '.Reservations[0].Instances[0].State.Name')
while [ "$CHECK_INSTANCE_STATE" != "running" ]; do
  echo "Waiting for instance state \"running\" for instance: $EU_INSTANCES. Current state is $CHECK_INSTANCE_STATE"
  sleep 3
  CHECK_INSTANCE_STATE=$(aws ec2 describe-instances --region eu-west-1 --instance-ids $EU_INSTANCES | jq -r '.Reservations[0].Instances[0].State.Name')
done

echo "Association IP: "$EU_TEST_IP" with new instance: "$EU_INSTANCES"..."
aws ec2 associate-address --region eu-west-1 --allocation-id $EU_TEST_EIPALLOC --instance-id $EU_INSTANCES

## EU STAGE 3: Verifying newly launched Instances
echo ""
echo " ** STAGE 3. TESTING NEW INSTANCES"
echo "Wait untill instances came to active state.. Usually it takes about 5 mins"
echo "and after check runned instance using public hosts provided above ^^^."
echo "Use promt bellow to confirm what everything is going smooth."
echo "MAKE SURE WHAT ALL NEW RUNED INSTANCES HAVE TAGGED WITH NEW VERSION!!!"
sleep 20

while true; do
    read -p "Everything is OK? Do you wonna register instances on LBs?" yn
    case $yn in
        [Yy]* ) echo 'yes'; break;;
        [Nn]* ) safe_exit;; #TODO: cleaning here
        * ) echo "Please answer yes or no.";;
    esac
done

## EU STAGE 4: Update Loadbalncer with newly launched Instances
echo ""
echo " ** STAGE 4. UPDATING LB"
echo "Updating ALB secure..."
aws elbv2 register-targets --region eu-west-1 --target-group-arn arn:aws:elasticloadbalancing:eu-west-1:{YOUR_VALUE}:targetgroup/vpcsecure-eu/{YOUR_VALUE} --targets Id=$EU_INSTANCES

## EU STAGE 4.5 Update newly launched Instances IPs
echo ""
echo " ** STAGE 4.5 UPDATING MAIN INSTANCE IP"

echo "Disassociation TEMP IP: "$EU_TEST_IP"..."
aws ec2 disassociate-address --region eu-west-1 --public-ip $EU_TEST_IP

echo "Disassociation PROD IP: "$EU_PROD_IP"..."
aws ec2 disassociate-address --region eu-west-1 --public-ip $EU_PROD_IP

echo "Association PROD IP: "$EU_PROD_IP" with new instance: "$EU_INSTANCES"..."
aws ec2 associate-address --region eu-west-1 --instance-id $EU_INSTANCES --public-ip $EU_PROD_IP

## EU STAGE 5: Update Autoscale Group and Launch Configuration
echo ""
echo " ** STAGE 5. UPDATING AUTOSCALING CONFIGURATION"
ASG_NAME="eu_asg_vpc_secure"
NEW_LC_NAME="eu_lc_vpc_secure_version_"$APP_VERSION"_"$CURRENT_TIMESTAMP
OLD_LC_NAME=$(aws autoscaling describe-auto-scaling-groups --region eu-west-1 --auto-scaling-group-name $ASG_NAME | jq -r '.AutoScalingGroups[0].LaunchConfigurationName')
OLD_AMI_NAME=$(aws autoscaling describe-launch-configurations --region eu-west-1 --launch-configuration-names $OLD_LC_NAME  | jq -r '.LaunchConfigurations[0].ImageId')

echo "Creating new launch configuration with new AMI..."
aws autoscaling create-launch-configuration --launch-configuration-name $NEW_LC_NAME  --region eu-west-1 --image-id $EU_AMI_ID --instance-type $EU_INSTANCE_TYPE --security-groups sg-{YOUR_VALUE} --key-name secure.{YOUR_VALUE}.com-EU --user-data file://user-data.eu --iam-instance-profile $SECURE_ROLE_ARN --instance-monitoring Enabled=true

if [ $? -eq 0 ]; then
  echo "Updating autoscaling group  with new launch config..."
  aws autoscaling update-auto-scaling-group --region eu-west-1 --auto-scaling-group-name $ASG_NAME  --launch-configuration-name $NEW_LC_NAME
  echo "Removing old launch config and old AMI..."
  aws autoscaling delete-launch-configuration --region eu-west-1 --launch-configuration-name $OLD_LC_NAME
  aws ec2 deregister-image --region eu-west-1 --image-id $OLD_AMI_NAME
else
 echo "  !!! ERROR: Cant create launch config!"
fi

## STAGE 6: Update CloudWatch Alarms
echo ""
echo " ** STAGE 6. UPDATING CLOUDWATCH ALARMS"
EU_POLICY_SCALEUP_NAME="arn:aws:autoscaling:eu-west-1:{YOUR_VALUE}:scalingPolicy:cb12df6c-9408-46ea-9235-508683e597a1:autoScalingGroupName/eu_asg_vpc_secure:policyName/EUScaleUP"
EU_POLICY_SCALEDOWN_NAME="arn:aws:autoscaling:eu-west-1:{YOUR_VALUE}:scalingPolicy:30d02c06-4c1e-4519-ae89-e03b39e92312:autoScalingGroupName/eu_asg_vpc_secure:policyName/EUScaleDOWN"

aws cloudwatch put-metric-alarm --region eu-west-1 --alarm-name EUsecureAMIHighCPULoad --alarm-description "EUsecureAMIHighCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 75 --comparison-operator GreaterThanThreshold  --dimensions "Name=ImageId,Value=$EU_AMI_ID" --evaluation-periods 3 --alarm-actions $EU_POLICY_SCALEUP_NAME  --unit Percent

aws cloudwatch put-metric-alarm --region eu-west-1 --alarm-name EUsecureAMILowCPULoad --alarm-description "EUsecureAMILowCPULoad" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 60 --threshold 50 --comparison-operator GreaterThanThreshold  --dimensions "Name=ImageId,Value=$EU_AMI_ID" --evaluation-periods 3 --alarm-actions $EU_POLICY_SCALEDOWN_NAME  --unit Percent

## STAGE 7: Remove Old Instances
echo ""
echo " ** STAGE 7. REMOVING OLD INSTANCES"
EU_OLD_INSTANCES=$(aws ec2 describe-instances --region eu-west-1 --filters "Name=tag:Name,Values=eu.{YOUR_VALUE}.com" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[?Tags[?Key==`Version` && Value!=`'$APP_VERSION'`]].InstanceId' --output text)

for OLD_INSTANCE in $EU_OLD_INSTANCES;
do
  echo "De-registering instance $OLD_INSTANCE from ALB vpcsecure..."
  aws elbv2 deregister-targets --region eu-west-1 --target-group-arn arn:aws:elasticloadbalancing:eu-west-1:{YOUR_VALUE}:targetgroup/vpcsecure-eu/{YOUR_VALUE} --targets Id=$OLD_INSTANCE
done

## EU Deployment End
echo "Done!"
safe_exit

fi

if [ "$choice" != "us" ] && [ "$choice" != "eu" ] && [ "$choice" != "all" ]; then
    echo "Invalid choice. Please enter 'us', 'eu', or 'all'."
fi
