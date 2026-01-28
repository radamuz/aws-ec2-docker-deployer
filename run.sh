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
echo -e "${CYAN}Inicio Bloque Introduce el nombre del aplicativo a desplegar${NC}"
read -p "Nombre del aplicativo: " APP_NAME
APP_NAME=${APP_NAME:-aws-ec2-docker-deployer}
APP_NAME=${APP_NAME}-aedd
echo -e "${GREEN}Fin Bloque Introduce el nombre del aplicativo a desplegar${NC}"
# Fin Introduce el nombre del aplicativo a desplegar

# Asegurarse de que existe la carpeta keypairs
echo -e "${CYAN}Inicio Bloque Asegurarse de que existe la carpeta keypairs${NC}"
mkdir -p keypairs
echo -e "${GREEN}Fin Bloque Asegurarse de que existe la carpeta keypairs${NC}"
# Fin Asegurarse de que existe la carpeta keypairs

# Crear key pair
echo -e "${CYAN}Inicio Bloque Crear key pair${NC}"
CREATE_KEY_PAIR=true
PEM_KEY_NAME="$APP_NAME.$AWS_REGION.$AWS_PROFILE"
PEM_KEY_PATH="keypairs/$PEM_KEY_NAME.pem"
if $CREATE_KEY_PAIR; then
  if aws ec2 describe-key-pairs \
      --query "KeyPairs[?KeyName=='$PEM_KEY_NAME']" \
      --output text | grep -q "$PEM_KEY_NAME"; then
    echo "✅ El key pair existe"
  else
    echo "❌ El key pair NO existe"
    aws ec2 create-key-pair \
      --key-name "$PEM_KEY_NAME" \
      --query 'KeyMaterial' \
      --output text > "$PEM_KEY_PATH"
  fi
fi
echo -e "${GREEN}Fin Bloque Crear key pair${NC}"
# Fin crear key pair

# Hacer cat $PEM_KEY_PATH y subirlo al secret manager si no existe
echo -e "${CYAN}Inicio Bloque Hacer cat \$PEM_KEY_PATH y subirlo al secret manager si no existe${NC}"
if ! aws secretsmanager describe-secret --secret-id "$PEM_KEY_PATH" >/dev/null 2>&1; then
  echo "❌ El secreto NO existe, creando..."
  aws secretsmanager create-secret --name "$PEM_KEY_PATH" --secret-string file://"$PEM_KEY_PATH" | jq
else
  echo "✅ El secreto ya existe"
fi
echo -e "${GREEN}Fin Bloque Hacer cat \$PEM_KEY_PATH y subirlo al secret manager si no existe${NC}"
# Fin Hacer cat $PEM_KEY_PATH y subirlo al secret manager si no existe

# Crear security group
echo -e "${CYAN}Inicio Bloque Crear security group${NC}"
CREATE_SECURITY_GROUP=true
if $CREATE_SECURITY_GROUP; then
aws ec2 create-security-group \
  --group-name "$APP_NAME-sg" \
  --description "Security group for $APP_NAME"
fi
echo -e "${GREEN}Fin Bloque Crear security group${NC}"
# Fin crear security group

# Obtener el security group ID
echo -e "${CYAN}Inicio Bloque Obtener el security group ID${NC}"
if $CREATE_SECURITY_GROUP; then
SECURITY_GROUP_ID=$(
  aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$APP_NAME-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
fi
echo -e "${GREEN}Fin Bloque Obtener el security group ID${NC}"
# Fin Obtener el security group ID

# Agregar reglas al security group
echo -e "${CYAN}Inicio Bloque Agregar reglas al security group${NC}"
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
echo -e "${GREEN}Fin Bloque Agregar reglas al security group${NC}"
# Fin agregar reglas al security group

# Seleccionar VPC y Subnet
echo -e "${CYAN}Inicio Bloque Seleccionar VPC y Subnet${NC}"
source scripts/select-vpc-subnet.sh
echo -e "${GREEN}Fin Bloque Seleccionar VPC y Subnet${NC}"
# Fin Seleccionar VPC y Subnet

# Obtener el AMI ID
echo -e "${CYAN}Inicio Bloque Obtener el AMI ID${NC}"
source scripts/get-ami-id-ubuntu.sh
echo -e "${GREEN}Fin Bloque Obtener el AMI ID${NC}"
# Fin Obtener el AMI ID

# Comprobar si existe la EC2
echo -e "${CYAN}Inicio Bloque Comprobar si existe la EC2${NC}"
source scripts/check-ec2-name.sh
echo -e "${GREEN}Fin Bloque Comprobar si existe la EC2${NC}"
# Fin comprobar si existe la EC2

# Elegir el instance type de AWS
echo -e "${CYAN}Inicio Bloque Elegir el instance type de AWS${NC}"
echo "Elige el instance type de AWS:"
select INSTANCE_TYPE in $(cat config/instance-types.txt); do
  if [[ -n "$INSTANCE_TYPE" ]]; then
    echo "Has elegido el instance type de AWS: $INSTANCE_TYPE"
    export INSTANCE_TYPE
    break
  else
    echo "Opción inválida, prueba otra vez."
  fi
done
echo -e "${GREEN}Fin Bloque Elegir el instance type de AWS${NC}"
# Fin Elegir el instance type de AWS

# Si la EC2 no existe entonces creala
echo -e "${CYAN}Inicio Bloque Si la EC2 no existe entonces creala${NC}"
CREATE_EC2=true
if $CREATE_EC2; then
  if $EC2_EXISTS; then
    # Si la EC2 existe obtener el INSTANCE_ID
    echo -e "${CYAN}Inicio Bloque Si la EC2 existe obtener el INSTANCE_ID${NC}"
    echo "✅ La EC2 '$APP_NAME' ya existe."
    INSTANCE_ID=$(
      aws ec2 describe-instances \
      --filters Name=tag:Name,Values="$APP_NAME" \
      --query 'Reservations[0].Instances[0].InstanceId' \
      --output text)
    echo "✅ INSTANCE_ID: $INSTANCE_ID"

    EC2_DESCRIBE_INSTANCES_OUTPUT_JSON=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID")

    # Obtener la dirección IP pública
    PUBLIC_IP=$(
      aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' \
      --output text)
    echo "✅ PUBLIC_IP: $PUBLIC_IP"
    echo -e "${GREEN}Fin Bloque Si la EC2 existe obtener el INSTANCE_ID${NC}"
    # Fin Si la EC2 existe obtener el INSTANCE_ID
  else
    # Ubuntus: ami-01f79b1e4a5c64257 (64-bit (x86)) / ami-0df5c15a5f998e2ab (64-bit (Arm))
    # t3a.medium (64-bit (x86)) / t4g.medium (64-bit (Arm))
    # Arrancar nueva instancia EC2
    EC2_RUN_INSTANCES_OUTPUT_JSON=$(aws ec2 run-instances \
      --image-id "${AMI_ID}" \
      --instance-type "$INSTANCE_TYPE" \
      --key-name "$PEM_KEY_NAME" \
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
fi
echo -e "${GREEN}Fin Bloque Si la EC2 no existe entonces creala${NC}"
# Fin Si la EC2 no existe entonces creala

# Informar al usuario de que puede acceder a la máquina a través del siguiente comando
echo -e "${CYAN}Inicio Bloque Informar al usuario de que puede acceder a la máquina a través del siguiente comando${NC}"
echo -e "Puedes acceder a la máquina a través del siguiente comando:"
PEM_KEY_REALPATH=$(realpath "$PEM_KEY_PATH")
echo "chmod 600 $PEM_KEY_REALPATH"
echo "ssh -i $PEM_KEY_REALPATH ubuntu@$PUBLIC_IP"
echo -e "${GREEN}Fin Bloque Informar al usuario de que puede acceder a la máquina a través del siguiente comando${NC}"
# Fin Informar al usuario de que puede acceder a la máquina a través del siguiente comando

# Asegurarse de que existe la carpeta logs
echo -e "${CYAN}Inicio Bloque Asegurarse de que existe la carpeta logs${NC}"
mkdir -p logs
echo -e "${GREEN}Fin Bloque Asegurarse de que existe la carpeta logs${NC}"
# Fin Asegurarse de que existe la carpeta logs

# Guardar registro de variables usadas
echo -e "${CYAN}Inicio Bloque Guardar registro de variables usadas${NC}"
LOG_FILE="logs/$(date '+%Y-%m-%d_%H-%M-%S').log"
{
  echo "LOG_FILE=$LOG_FILE"
  echo "DOCKERFILE_PATH=${DOCKERFILE_PATH-UNDEFINED}"
  echo "AWS_PROFILE=${AWS_PROFILE-UNDEFINED}"
  echo "AWS_REGION=${AWS_REGION-UNDEFINED}"
  echo "AWS_STS_GET_CALLER_IDENTITY=${AWS_STS_GET_CALLER_IDENTITY-UNDEFINED}"
  echo "AWS_STS_GET_CALLER_IDENTITY_STATUS=${AWS_STS_GET_CALLER_IDENTITY_STATUS-UNDEFINED}"
  echo "APP_NAME=${APP_NAME-UNDEFINED}"
  echo "SECURITY_GROUP_ID=${SECURITY_GROUP_ID-UNDEFINED}"
  echo "PEM_KEY_PATH=${PEM_KEY_PATH-UNDEFINED}"
  echo "EC2_DESCRIBE_INSTANCES_OUTPUT_JSON=${EC2_DESCRIBE_INSTANCES_OUTPUT_JSON-UNDEFINED}"
  echo "EC2_RUN_INSTANCES_OUTPUT_JSON=${EC2_RUN_INSTANCES_OUTPUT_JSON-UNDEFINED}"
  echo "INSTANCE_ID=${INSTANCE_ID-UNDEFINED}"
  echo "PUBLIC_IP=${PUBLIC_IP-UNDEFINED}"
} > "$LOG_FILE"
echo -e "${GREEN}Fin Bloque Guardar registro de variables usadas${NC}"
# Fin Guardar registro de variables usadas
