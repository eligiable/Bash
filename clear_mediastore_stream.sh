#!/bin/bash

# Description: This script deletes all objects in an AWS MediaStore stream path
# Requirements: awscli, jq

# Configuration
ENDPOINT="https://1q2w3e4r5t.data.mediastore.eu-west-1.amazonaws.com"
MSPATH="stream"
TEMP_FILE="mediastore_items.json"

# Verify dependencies
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install it first (apt install jq)."
    exit 1
fi

# Check AWS CLI configuration
if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS CLI is not configured. Please configure it first."
    exit 1
fi

echo "Listing and deleting objects in MediaStore path: $MSPATH"

# List all items and store in temporary file
aws mediastore-data list-items --endpoint="$ENDPOINT" --path="/$MSPATH/" > "$TEMP_FILE"

# Process each item
jq -r '.Items[].Name' "$TEMP_FILE" | while read -r OBJECT; do
    echo "Deleting: $OBJECT"
    aws mediastore-data delete-object --endpoint="$ENDPOINT" --path="/$MSPATH/$OBJECT"
    
    if [ $? -eq 0 ]; then
        echo "Successfully deleted: $OBJECT"
    else
        echo "Failed to delete: $OBJECT" >&2
    fi
done

# Clean up
rm -f "$TEMP_FILE"
echo "Operation completed."