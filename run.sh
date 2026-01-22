#!/bin/bash

# Elegir un Dockerfile
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
# Fin Elegir un Dockerfile

# Arrancar proceso de construcción de imágenes Docker
RUN_DOCKER_BUILD=true
if $RUN_DOCKER_BUILD; then
  bash scripts/docker-build.sh "$DOCKERFILE_PATH"
fi
# Fin Arrancar proceso de construcción de imágenes Docker

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

# Test de credenciales
AWS_STS_GET_CALLER_IDENTITY=$(aws sts get-caller-identity --profile "$AWS_PROFILE")
AWS_STS_GET_CALLER_IDENTITY_STATUS=$?
echo "$AWS_STS_GET_CALLER_IDENTITY" | jq
if [ $AWS_STS_GET_CALLER_IDENTITY_STATUS -eq 0 ]; then
    echo "Las credenciales de AWS son válidas."
else
    echo "Error: Las credenciales de AWS no son válidas."
    exit 1
fi
# Fin Test de credenciales

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
} > "$LOG_FILE"
# Fin Guardar registro de variables usadas