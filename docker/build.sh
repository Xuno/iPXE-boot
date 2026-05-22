#!/bin/bash

set -euo pipefail

DEST_DIR="http/boots/ubuntu/current"
ISO_CONTAINER_NAME=iso


docker compose --progress=plain up --build --remove-orphans "$ISO_CONTAINER_NAME"
docker compose down

echo "Deployment to $DEST_DIR and http/iso complete."
