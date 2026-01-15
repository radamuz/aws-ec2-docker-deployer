#!/bin/bash

# Script variables
export AWS_PAGER="cat"
BUILDX_BUILDER_NAME="multi-platform-builder"
# Fin Script variables

# Parámetros
DOCKERFILE_PATH=$1
# Fin parámetros

# Post parámetros variables
DOCKERFILE_NAME=$(basename "$DOCKERFILE_PATH")
# Fin Post parámetros variables

# Comprobar que docker buildx esté disponible
if ! docker buildx version >/dev/null 2>&1; then
    echo "Error: Docker Buildx no está disponible. Instala/activa buildx para construir multi-plataforma."
    exit 1
fi
# Fin Comprobar que docker buildx esté disponible

# Asegurar construcción multi-plataforma con docker buildx
if ! docker buildx inspect "$BUILDX_BUILDER_NAME" >/dev/null 2>&1; then
    docker buildx create --name "$BUILDX_BUILDER_NAME" --driver docker-container --use >/dev/null
else
    docker buildx use "$BUILDX_BUILDER_NAME" >/dev/null
fi
docker buildx inspect --bootstrap >/dev/null
# Fin Asegurar construcción multi-plataforma con docker buildx

# Construir la imagen y exportar a tar OCI
mkdir -p tars
docker buildx build --platform linux/arm64,linux/amd64 \
    --output "type=oci,dest=tars/$DOCKERFILE_NAME.oci.tar" \
    -t "$DOCKERFILE_NAME" \
    "$DOCKERFILE_PATH"
