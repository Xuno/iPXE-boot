#!/bin/bash

set -euo pipefail

docker compose --progress=plain up --build --remove-orphans
docker compose down

echo "Deployment http/iso complete."
