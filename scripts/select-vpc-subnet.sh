#!/bin/bash

# Obtener VPCs: ID | Nombre
mapfile -t VPCS < <(
  aws ec2 describe-vpcs \
    --query 'Vpcs[].{id:VpcId,name:Tags[?Key==`Name`]|[0].Value}' \
    --output json |
  jq -r '.[] | "\(.id)|\(.name // "NO-NAME")"'
)
# Fin Obtener VPCs: ID | Nombre

# Comprobar si hay alguna VPC
if [[ ${#VPCS[@]} -eq 0 ]]; then
  echo "❌ No se encontraron VPCs"
  exit 1
fi
# Fin Comprobar si hay alguna VPC

# Seleccionar la VPC
echo
echo "👉 Selecciona una VPC:"
select VPC in "${VPCS[@]}"; do
  [[ -n "$VPC" ]] && break
  echo "❌ Opción inválida"
done
# Fin Seleccionar la VPC

# Diseccionar datos VPC
VPC_ID="${VPC%%|*}"
VPC_NAME="${VPC##*|}"
# Fin Diseccionar datos VPC

# Informar al usuario
echo
echo "✅ VPC seleccionada: $VPC_NAME ($VPC_ID)"
echo
echo "🔎 Obteniendo subnets de la VPC..."
# Fin Informar al usuario

# Obtener Subnets de la VPC seleccionada
mapfile -t SUBNETS < <(
  aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[].{id:SubnetId,name:Tags[?Key==`Name`]|[0].Value,az:AvailabilityZone}' \
    --output json |
  jq -r '.[] | "\(.id)|\(.name // "NO-NAME")|\(.az)"'
)
# Fin Obtener Subnets de la VPC seleccionada

# Comprobar si hay alguna subnet
if [[ ${#SUBNETS[@]} -eq 0 ]]; then
  echo "❌ No se encontraron subnets en la VPC"
  exit 1
fi
# Fin Comprobar si hay alguna subnet

# Seleccionar la Subnet
echo
echo "👉 Selecciona una Subnet:"
select SUBNET in "${SUBNETS[@]}"; do
  [[ -n "$SUBNET" ]] && break
  echo "❌ Opción inválida"
done
# Fin Seleccionar la Subnet

# Diseccionar datos Subnet
SUBNET_ID="${SUBNET%%|*}"
REST="${SUBNET#*|}"
SUBNET_NAME="${REST%%|*}"
SUBNET_AZ="${SUBNET##*|}"
# Fin Diseccionar datos Subnet

# Informar al usuario
echo
echo "✅ Subnet seleccionada: $SUBNET_NAME ($SUBNET_ID) - $SUBNET_AZ"