#!/bin/bash

set -euo pipefail

DEST_DIR="http/boots/ubuntu/current"
ISO_CONTAINER_NAME=iso
BASE_OS_CONTAINER_NAME=base-os
APPS_CONTAINER_NAME=apps

docker compose --progress=plain up --build --remove-orphans "$ISO_CONTAINER_NAME"
docker compose --progress=plain up --build --remove-orphans "$BASE_OS_CONTAINER_NAME"
docker compose --progress=plain up --build --remove-orphans "$APPS_CONTAINER_NAME"
docker compose down

echo "Deployment to $DEST_DIR and http/iso complete."
