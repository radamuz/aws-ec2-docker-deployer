#!/usr/bin/env bash

set -euo pipefail

# Pedir nombre de la instancia (Tag Name)
read -r -p "Nombre (Tag Name) de la EC2 a buscar: " EC2_NAME
EC2_NAME=${EC2_NAME:-}

if [[ -z "$EC2_NAME" ]]; then
  echo "❌ Debes indicar un nombre de EC2."
  exit 1
fi

echo "🔎 Estas son las máquinas EC2 que tienen este nombre: $EC2_NAME"

mapfile -t EC2S < <(
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$EC2_NAME" \
    --query 'Reservations[].Instances[].{id:InstanceId,name:Tags[?Key==`Name`]|[0].Value,state:State.Name,type:InstanceType,az:Placement.AvailabilityZone,public:PublicIpAddress,private:PrivateIpAddress}' \
    --output json |
  jq -r '.[] | "\(.id)|\(.name // "NO-NAME")|\(.state)|\(.type)|\(.az)|\(.public // "NO-PUBLIC-IP")|\(.private // "NO-PRIVATE-IP")"'
)

if [[ ${#EC2S[@]} -eq 0 ]]; then
  echo "❌ No hay ninguna EC2 con el nombre: $EC2_NAME"
  exit 1
fi

echo
echo "👉 Selecciona la que encaja con la tuya:"
select EC2 in "${EC2S[@]}"; do
  [[ -n "$EC2" ]] && break
  echo "❌ Opción inválida"
done

INSTANCE_ID="${EC2%%|*}"
REST="${EC2#*|}"
INSTANCE_NAME="${REST%%|*}"
STATE="$(echo "$EC2" | cut -d'|' -f3)"
TYPE="$(echo "$EC2" | cut -d'|' -f4)"
AZ="$(echo "$EC2" | cut -d'|' -f5)"
PUBLIC_IP="$(echo "$EC2" | cut -d'|' -f6)"
PRIVATE_IP="$(echo "$EC2" | cut -d'|' -f7)"

echo
echo "✅ EC2 seleccionada:"
echo "Nombre    : $INSTANCE_NAME"
echo "ID        : $INSTANCE_ID"
echo "Estado    : $STATE"
echo "Tipo      : $TYPE"
echo "AZ        : $AZ"
echo "Public IP : $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"

export AWS_SELECTED_INSTANCE_ID="$INSTANCE_ID"
export AWS_SELECTED_INSTANCE_NAME="$INSTANCE_NAME"

echo
echo "📦 Variables exportadas:"
echo "AWS_SELECTED_INSTANCE_ID=$AWS_SELECTED_INSTANCE_ID"
echo "AWS_SELECTED_INSTANCE_NAME=$AWS_SELECTED_INSTANCE_NAME"
