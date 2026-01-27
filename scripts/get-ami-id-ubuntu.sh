#!/usr/bin/env bash
set -euo pipefail

echo "🧠 Selecciona la arquitectura:"

ARCH="arm64"

SSM_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/${ARCH}/hvm/ebs-gp3/ami-id"

echo "🔎 Buscando AMI para arquitectura: $ARCH"

AMI_ID=$(aws ssm get-parameter \
  --name "$SSM_PARAM" \
  --query 'Parameter.Value' \
  --output text)

echo "✅ AMI ID encontrado: $AMI_ID"
