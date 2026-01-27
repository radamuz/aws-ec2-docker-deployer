#!/usr/bin/env bash
set -e

echo "📌 Creando Elastic IP en $AWS_REGION..."

ALLOCATION_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --region "$AWS_REGION" \
  --query 'AllocationId' \
  --output text)

echo "✅ Elastic IP creada. AllocationId: $ALLOCATION_ID"

echo "🔗 Asociando Elastic IP a la instancia $INSTANCE_ID..."

ASSOCIATION_ID=$(aws ec2 associate-address \
  --instance-id "$INSTANCE_ID" \
  --allocation-id "$ALLOCATION_ID" \
  --region "$AWS_REGION" \
  --query 'AssociationId' \
  --output text)

echo "✅ Elastic IP asociada. AssociationId: $ASSOCIATION_ID"

PUBLIC_IP=$(aws ec2 describe-addresses \
  --allocation-ids "$ALLOCATION_ID" \
  --region "$AWS_REGION" \
  --query 'Addresses[0].PublicIp' \
  --output text)

echo "🌍 IP pública asignada: $PUBLIC_IP"
