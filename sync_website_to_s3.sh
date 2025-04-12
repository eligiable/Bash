#!/usr/bin/env bash

################################################################################
# Description: This script performs two main functions:
#              1. Syncs a local website directory to an S3 bucket while excluding
#                 specific file types that will be handled separately.
#              2. Fixes content-type metadata for common web file types in the
#                 S3 bucket by setting the correct MIME types.
#
# Usage: ./sync_website_to_s3.sh [profile]
#   Where [profile] is an optional AWS CLI profile name (defaults to 'default')
#
# Requirements:
# - AWS CLI installed and configured
# - Proper permissions to access the S3 bucket and CloudFront distribution
################################################################################

{
# Main sync operation - upload all files except those that need special content-type handling
echo "Starting synchronization of website files to S3..."
aws s3 sync /var/www/example/dist/example/ s3://example.com --exclude "*.css" --exclude "*.js" --exclude "*.json" --exclude "*.jpg" --exclude "*.jpeg" --exclude "*.gif" --exclude "*.png" --exclude "*.svg" --exclude "*.pdf" --exclude "*.xml"
RETVAL=$?
[ $RETVAL -eq 0 ] && echo "Synchronization Completed Successfully"
[ $RETVAL -ne 0 ] && echo "Synchronization Failed"

# Safely fix invalid content-type metadata on AWS S3 bucket website assets for some common filetypes
# Includes CSS, JS, JSON, JPG, JPEG, GIF, PNG, SVG, PDF, XML

BUCKET="example.com"

# Functions
function check_command {
    type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

function completed(){
    echo
    horizontalRule
    tput setaf 2; echo "All operations completed successfully!" && tput sgr0
    horizontalRule
    echo
}

function fail(){
    tput setaf 1; echo "Failure: $*" && tput sgr0
    exit 1
}

function horizontalRule(){
    echo "====================================================="
}

function message(){
    echo
    horizontalRule
    echo "$*"
    horizontalRule
    echo
}

function pause(){
    read -n 1 -s -p "Press any key to continue..."
    echo
}

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! grep -q aws_access_key_id ~/.aws/credentials; then
    if ! grep -q aws_access_key_id ~/.aws/config; then
        fail "AWS config not found or CLI not installed. Please run \"aws configure\"."
    fi
fi

check_command "aws"

# Check for AWS CLI profile argument passed into the script
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-multiple-profiles
if [ $# -eq 0 ]; then
    scriptname=`basename "$0"`
    echo "Usage: ./$scriptname profile"
    echo "Where profile is the AWS CLI profile name"
    echo "Using default profile"
    profile=default
else
    profile=$1
fi

message "Starting content-type metadata correction for S3 bucket: $BUCKET"

# Set default region
REGION="eu-west-1"

# Process each file type with its proper content-type
message "Processing CSS files..."
css=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.css" --content-type "text/css" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$css"
fi
if echo $css | egrep -iq "error|not"; then
    fail "$css"
else
    echo "$css"
fi

message "Processing JavaScript files..."
js=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.js" --content-type "application/javascript" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$js"
fi
if echo $js | egrep -iq "error|not"; then
    fail "$js"
else
    echo "$js"
fi

message "Processing JSON files..."
json=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.json" --content-type "application/json" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$json"
fi
if echo $json | egrep -iq "error|not"; then
    fail "$json"
else
    echo "$json"
fi

message "Processing JPG images..."
jpg=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.jpg" --content-type "image/jpeg" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$jpg"
fi
if echo $jpg | egrep -iq "error|not"; then
    fail "$jpg"
else
    echo "$jpg"
fi

message "Processing JPEG images..."
jpeg=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.jpeg" --content-type "image/jpeg" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$jpeg"
fi
if echo $jpeg | egrep -iq "error|not"; then
    fail "$jpeg"
else
    echo "$jpeg"
fi

message "Processing GIF images..."
gif=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.gif" --content-type "image/gif" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$gif"
fi
if echo $gif | egrep -iq "error|not"; then
    fail "$gif"
else
    echo "$gif"
fi

message "Processing PNG images..."
png=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.png" --content-type "image/png" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$png"
fi
if echo $png | egrep -iq "error|not"; then
    fail "$png"
else
    echo "$png"
fi

message "Processing SVG images..."
svg=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.svg" --content-type "image/svg+xml" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$svg"
fi
if echo $svg | egrep -iq "error|not"; then
    fail "$svg"
else
    echo "$svg"
fi

message "Processing PDF files..."
pdf=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.pdf" --content-type "application/pdf" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$pdf"
fi
if echo $pdf | egrep -iq "error|not"; then
    fail "$pdf"
else
    echo "$pdf"
fi

message "Processing XML files..."
xml=$(aws s3 cp --recursive --profile $profile --region $REGION /var/www/example/dist/example/ s3://$BUCKET/ --exclude "*" --include "*.xml" --content-type "text/xml" --metadata-directive "REPLACE" 2>&1)
if [ ! $? -eq 0 ]; then
    fail "$xml"
fi
if echo $xml | egrep -iq "error|not"; then
    fail "$xml"
else
    echo "$xml"
fi

completed

# Clear CloudFront Cache
message "Creating CloudFront invalidation..."
aws cloudfront create-invalidation --distribution-id=1Q2W3E4R5T6 --paths "/*"

} 2>&1 | tee /tmp/sync-website-to-s3.log