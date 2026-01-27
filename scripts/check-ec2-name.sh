#!/usr/bin/env bash
set -euo pipefail

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=$APP_NAME" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [[ -n "$INSTANCE_IDS" ]]; then
  echo "❌ Existe una EC2 llamada '$APP_NAME'"
  echo "🆔 Instance ID(s): $INSTANCE_IDS"
  EC2_EXISTS=true
else
  echo "✅ No existe ninguna EC2 llamada '$APP_NAME'"
  EC2_EXISTS=false
fi