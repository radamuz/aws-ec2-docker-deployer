#!/bin/bash

if [[ -z "$INSTANCE_ID" ]]; then
  echo "❌ Uso: $0 <instance-id>"
  exit 1
fi

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[].Instances[].PublicIpAddress" \
  --output text)

if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
  echo "ℹ️  La instancia $INSTANCE_ID no tiene asignada IP pública"
else
  echo "✅ IP pública de $INSTANCE_ID: $PUBLIC_IP"
fi
