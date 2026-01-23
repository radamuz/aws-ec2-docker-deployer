#!/usr/bin/env bash

set -euo pipefail

# Elegir un perfil de AWS 
AWS_PROFILES=($(aws configure list-profiles))
echo "Elige un perfil de AWS:"
select AWS_PROFILE in "${AWS_PROFILES[@]}"; do
  if [[ -n "$AWS_PROFILE" ]]; then
    echo "Has elegido el perfil de AWS: $AWS_PROFILE"
    export AWS_PROFILE
    break
  else
    echo "Opción inválida, prueba otra vez."
  fi
done
# Fin Elegir un perfil de AWS 

# Elige una región de AWS
AWS_REGIONS=($(aws ec2 describe-regions --query "Regions[].RegionName" --output text))
echo "Elige una región de AWS:"
select AWS_REGION in "${AWS_REGIONS[@]}"; do
  if [[ -n "$AWS_REGION" ]]; then
    echo "Has elegido la región de AWS: $AWS_REGION"
    export AWS_REGION
    break
  else
    echo "Opción inválida, prueba otra vez."
  fi
done
# Fin Elige una región de AWS

echo "🔎 Obteniendo VPCs..."

# Obtener VPCs: ID | Nombre
mapfile -t VPCS < <(
  aws ec2 describe-vpcs \
    --query 'Vpcs[].{id:VpcId,name:Tags[?Key==`Name`]|[0].Value}' \
    --output json |
  jq -r '.[] | "\(.id)|\(.name // "NO-NAME")"'
)

if [[ ${#VPCS[@]} -eq 0 ]]; then
  echo "❌ No se encontraron VPCs"
  exit 1
fi

echo
echo "👉 Selecciona una VPC:"
select VPC in "${VPCS[@]}"; do
  [[ -n "$VPC" ]] && break
  echo "❌ Opción inválida"
done

VPC_ID="${VPC%%|*}"
VPC_NAME="${VPC##*|}"

echo
echo "✅ VPC seleccionada: $VPC_NAME ($VPC_ID)"
echo
echo "🔎 Obteniendo subnets de la VPC..."

# Obtener Subnets de la VPC seleccionada
mapfile -t SUBNETS < <(
  aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].{id:SubnetId,name:Tags[?Key==`Name`]|[0].Value,az:AvailabilityZone}' \
    --output json |
  jq -r '.[] | "\(.id)|\(.name // "NO-NAME")|\(.az)"'
)

if [[ ${#SUBNETS[@]} -eq 0 ]]; then
  echo "❌ No se encontraron subnets en la VPC"
  exit 1
fi

echo
echo "👉 Selecciona una Subnet:"
select SUBNET in "${SUBNETS[@]}"; do
  [[ -n "$SUBNET" ]] && break
  echo "❌ Opción inválida"
done

SUBNET_ID="${SUBNET%%|*}"
REST="${SUBNET#*|}"
SUBNET_NAME="${REST%%|*}"
AZ="${SUBNET##*|}"

echo
echo "🎉 Selección final:"
echo "VPC    : $VPC_NAME ($VPC_ID)"
echo "Subnet : $SUBNET_NAME ($SUBNET_ID)"
echo "AZ     : $AZ"

# Opcional: exportar variables
export AWS_SELECTED_VPC_ID="$VPC_ID"
export AWS_SELECTED_SUBNET_ID="$SUBNET_ID"

echo
echo "📦 Variables exportadas:"
echo "AWS_SELECTED_VPC_ID=$AWS_SELECTED_VPC_ID"
echo "AWS_SELECTED_SUBNET_ID=$AWS_SELECTED_SUBNET_ID"
