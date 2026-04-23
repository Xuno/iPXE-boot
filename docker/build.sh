#!/bin/bash

VERSION=$(date +%Y-%m-%d)
DEST_DIR="docker/http/ubuntu/$VERSION"
BASE_OS_CONTAINER_NAME=base-os

docker compose --progress=plain  up --build --remove-orphans "$BASE_OS_CONTAINER_NAME"

echo "Deployment to $DEST_DIR complete."