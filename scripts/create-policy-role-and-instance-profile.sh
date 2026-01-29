#!/usr/bin/env bash
set -euo pipefail

# ===== Variables =====
ROLE_NAME="ec2-read-own-tags-role"
POLICY_NAME="ec2-describe-own-instance-policy"
INSTANCE_PROFILE_NAME="ec2-read-own-tags-profile"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_JSON_FILE="$SCRIPT_DIR/iam/ec2-describe-own-instance-policy.json"
TRUST_POLICY_JSON_FILE="$SCRIPT_DIR/iam/ec2-assume-role-trust-policy.json"

if [[ ! -f "$POLICY_JSON_FILE" || ! -f "$TRUST_POLICY_JSON_FILE" ]]; then
  echo "❌ Faltan los archivos JSON en $SCRIPT_DIR/iam"
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

echo "▶ Creando policy IAM (si no existe)..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://$POLICY_JSON_FILE"
else
  echo "✔ Policy ya existe"
fi

echo "▶ Creando rol IAM (si no existe)..."
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://$TRUST_POLICY_JSON_FILE"
else
  echo "✔ Rol ya existe"
fi

echo "▶ Asociando policy al rol..."
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN" || true

echo "▶ Creando instance profile (si no existe)..."
if ! aws iam get-instance-profile --instance-profile-name "$INSTANCE_PROFILE_NAME" >/dev/null 2>&1; then
  aws iam create-instance-profile \
    --instance-profile-name "$INSTANCE_PROFILE_NAME"
else
  echo "✔ Instance profile ya existe"
fi

echo "▶ Añadiendo rol al instance profile..."
aws iam add-role-to-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --role-name "$ROLE_NAME" || true

echo
echo "✅ TODO LISTO"
echo "Instance Profile: $INSTANCE_PROFILE_NAME"
