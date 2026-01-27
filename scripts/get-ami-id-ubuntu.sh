#!/usr/bin/env bash
set -euo pipefail

echo "🧠 Selecciona la arquitectura:"

select OPTION in "amd64 (x86_64)" "arm64 (Graviton)"; do
  case "$REPLY" in
    1)
      ARCH="amd64"
      break
      ;;
    2)
      ARCH="arm64"
      break
      ;;
    *)
      echo "❌ Opción inválida, prueba otra vez."
      ;;
  esac
done

SSM_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/${ARCH}/hvm/ebs-gp3/ami-id"

echo "🔎 Buscando AMI para arquitectura: $ARCH"

AMI_ID=$(aws ssm get-parameter \
  --name "$SSM_PARAM" \
  --query 'Parameter.Value' \
  --output text)

echo "✅ AMI ID encontrado: $AMI_ID"
