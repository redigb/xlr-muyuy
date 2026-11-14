#!/usr/bin/env bash
# Corre EN LA VM. Lo invoca GitHub Actions por SSH en cada push a main.
set -euo pipefail
cd "${MUYUY_DIR:-/opt/muyuy}"
git fetch --quiet origin main
git reset --hard origin/main          # .env no está versionado: se conserva
docker compose up -d --build --remove-orphans
docker image prune -f >/dev/null
docker compose ps
