#!/usr/bin/env bash

set -e

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id \
  -H "X-aws-ec2-metadata-token: $TOKEN")
  
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region \
  -H "X-aws-ec2-metadata-token: $TOKEN")

apt update -y

apt install unzip -y

cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -f awscliv2.zip
cd -

APP_NAME=$(aws ec2 describe-tags \
  --region "$REGION" \
  --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" \
  --query 'Tags[0].Value' \
  --output text)

hostnamectl set-hostname "$APP_NAME"

