#!/usr/bin/env bash
# Corre EN LA VM. Lo invoca GitHub Actions por SSH en cada push a main.
# No compila: descarga la imagen que armó GitHub Actions (IMAGE_TAG = commit).
set -euo pipefail
cd "${MUYUY_DIR:-/opt/muyuy}"
git fetch --quiet origin main
git reset --hard origin/main          # compose, Caddyfile y data/; .env no está versionado: se conserva
export IMAGE_TAG="${IMAGE_TAG:-latest}"
docker compose pull backend
docker compose up -d --no-build --remove-orphans
docker image prune -f >/dev/null
docker compose ps
