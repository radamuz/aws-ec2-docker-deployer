#!/bin/bash

# Aplicar colores de bash
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
PURPLE='\033[0;35m'
BROWN='\033[0;33m'
CYAN="\e[36m"
NC='\033[0m' # No Color
# Fin Aplicar colores de bash

# Que aws cli no use less
echo -e "${CYAN}Inicio Bloque Que aws cli no use less${NC}"
export AWS_PAGER=""
echo -e "${GREEN}Fin Bloque Que aws cli no use less${NC}"
# Fin Que aws cli no use less


# Elegir un Dockerfile
echo -e "${CYAN}Inicio Bloque Elegir un Dockerfile${NC}"
DOCKERFILES=(dockerfiles/*)
echo "Elige un Dockerfile:"
select DOCKERFILE_PATH in "${DOCKERFILES[@]}"; do
  if [[ -n "$DOCKERFILE_PATH" ]]; then
    echo "Has elegido: $DOCKERFILE_PATH"
    break
  else
    echo "Opción inválida, prueba otra vez."
  fi
done
echo -e "${GREEN}Fin Bloque Elegir un Dockerfile${NC}"
# Fin Elegir un Dockerfile

# Arrancar proceso de construcción de imágenes Docker
echo -e "${CYAN}Inicio Bloque Arrancar proceso de construcción de imágenes Docker${NC}"
RUN_DOCKER_BUILD=true
if $RUN_DOCKER_BUILD; then
  bash scripts/docker-build.sh "$DOCKERFILE_PATH"
fi
echo -e "${GREEN}Fin Bloque Arrancar proceso de construcción de imágenes Docker${NC}"
# Fin Arrancar proceso de construcción de imágenes Docker

# Elegir un perfil de AWS 
echo -e "${CYAN}Inicio Bloque Elegir un perfil de AWS${NC}"
AWS_PROFILES=($(aws configure list-profiles | sort))
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
echo -e "${GREEN}Fin Bloque Elegir un perfil de AWS${NC}"
# Fin Elegir un perfil de AWS

# Elige una región de AWS con ./scripts/select-aws-region.sh
echo -e "${CYAN}Inicio Bloque Elegir una región de AWS${NC}"
source ./scripts/select-aws-region.sh
echo -e "AWS_REGION: $AWS_REGION"
echo -e "${GREEN}Fin Bloque Elegir una región de AWS${NC}"
# Fin Elige una región de AWS con ./scripts/select-aws-region.sh

# Test de credenciales
echo -e "${CYAN}Inicio Bloque Test de credenciales${NC}"
AWS_STS_GET_CALLER_IDENTITY=$(aws sts get-caller-identity --profile "$AWS_PROFILE")
AWS_STS_GET_CALLER_IDENTITY_STATUS=$?
echo "$AWS_STS_GET_CALLER_IDENTITY" | jq
if [ $AWS_STS_GET_CALLER_IDENTITY_STATUS -eq 0 ]; then
    echo "Las credenciales de AWS son válidas."
else
    echo "Error: Las credenciales de AWS no son válidas."
    exit 1
fi
echo -e "${GREEN}Fin Bloque Test de credenciales${NC}"
# Fin Test de credenciales

# Introduce el nombre del aplicativo a desplegar
read -p "Nombre del aplicativo: " APP_NAME
APP_NAME=${APP_NAME:-aws-ec2-docker-deployer}
APP_NAME=${APP_NAME}-aedd
# Fin Introduce el nombre del aplicativo a desplegar

# Asegurarse de que existe la carpeta keypairs
mkdir -p keypairs
# Fin Asegurarse de que existe la carpeta keypairs

# Crear key pair
CREATE_KEY_PAIR=true
if $CREATE_KEY_PAIR; then
  if aws ec2 describe-key-pairs \
      --query "KeyPairs[?KeyName=='$APP_NAME']" \
      --output text | grep -q "$APP_NAME"; then
    echo "✅ El key pair existe"
  else
    echo "❌ El key pair NO existe"
    aws ec2 create-key-pair \
      --key-name "$APP_NAME" \
      --query 'KeyMaterial' \
      --output text > "keypairs/$APP_NAME.$AWS_REGION.pem"
  fi
fi
# Fin crear key pair

# Crear security group
CREATE_SECURITY_GROUP=true
if $CREATE_SECURITY_GROUP; then
aws ec2 create-security-group \
  --group-name "$APP_NAME-sg" \
  --description "Security group for $APP_NAME"
fi
# Fin crear security group

# Obtener el security group ID
if $CREATE_SECURITY_GROUP; then
SECURITY_GROUP_ID=$(
  aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$APP_NAME-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
fi
# Fin Obtener el security group ID

# Agregar reglas al security group
if $CREATE_SECURITY_GROUP; then
aws ec2 authorize-security-group-ingress \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress \
  --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
fi
# Fin agregar reglas al security group

# Seleccionar VPC y Subnet
source scripts/select-vpc-subnet.sh
# Fin Seleccionar VPC y Subnet

# Obtener el AMI ID
source scripts/get-ami-id-ubuntu.sh
# Fin Obtener el AMI ID

# Comprobar si existe la EC2
source scripts/check-ec2-name.sh
# Fin comprobar si existe la EC2

# Si la EC2 existe entonces creala
if $EC2_EXISTS; then
  echo "❌ La EC2 '$APP_NAME' ya existe."
else
  # Ubuntus: ami-01f79b1e4a5c64257 (64-bit (x86)) / ami-0df5c15a5f998e2ab (64-bit (Arm))
  # t3a.medium (64-bit (x86)) / t4g.medium (64-bit (Arm))
  # Arrancar nueva instancia EC2
  EC2_RUN_INSTANCES_OUTPUT_JSON=$(aws ec2 run-instances \
    --image-id "${AMI_ID}" \
    --instance-type "t4g.medium" \
    --key-name "$APP_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --subnet-id "$SUBNET_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$APP_NAME}]" | jq)
  # Fin Arrancar nueva instancia EC2

  # Obtener el Instance ID
  INSTANCE_ID=$(
    echo "$EC2_RUN_INSTANCES_OUTPUT_JSON" \
    | jq -r '.Instances[0].InstanceId')
  echo "✅ INSTANCE_ID: $INSTANCE_ID"
  # Fin Obtener el Instance ID

  # Obtener la dirección IP pública
  PUBLIC_IP=$(
    aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)
  echo "✅ PUBLIC_IP: $PUBLIC_IP"
  # Fin Obtener la dirección IP pública
fi
# Fin Si la EC2 existe entonces creala

# Asegurarse de que existe la carpeta logs
mkdir -p logs
# Fin Asegurarse de que existe la carpeta logs

# Guardar registro de variables usadas
LOG_FILE="logs/$(date '+%Y-%m-%d_%H-%M-%S').log"
{
  echo "LOG_FILE=$LOG_FILE"
  echo "DOCKERFILE_PATH=$DOCKERFILE_PATH"
  echo "AWS_PROFILE=$AWS_PROFILE"
  echo "AWS_REGION=$AWS_REGION"
  echo "AWS_STS_GET_CALLER_IDENTITY=$AWS_STS_GET_CALLER_IDENTITY"
  echo "AWS_STS_GET_CALLER_IDENTITY_STATUS=$AWS_STS_GET_CALLER_IDENTITY_STATUS"
  echo "APP_NAME=$APP_NAME"
  echo "SECURITY_GROUP_ID=$SECURITY_GROUP_ID"
  echo "EC2_RUN_INSTANCES_OUTPUT_JSON=$EC2_RUN_INSTANCES_OUTPUT_JSON"
  echo "INSTANCE_ID=$INSTANCE_ID"
} > "$LOG_FILE"
# Fin Guardar registro de variables usadas