#!/bin/bash

function clean () {
  SNAPS=$(ec2-describe-images $NEW_AMI_ID | grep BLOCKDEVICEMAPPING | awk '{print $4}')
  for S in $SNAPS; do
    ec2-delete-snapshot $S
  done

  ec2-deregister $NEW_AMI_ID
}

function safe_exit {
  unset AWS_ACCESS_KEY
  unset AWS_SECRET_KEY
  unset AWS_CREDENTIAL_FILE
  exit
}
