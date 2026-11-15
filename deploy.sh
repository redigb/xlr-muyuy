#!/usr/bin/env bash
# Corre EN LA VM. Lo invoca GitHub Actions por SSH en cada push a main.
# No compila el backend: descarga la imagen que armó GitHub Actions (IMAGE_TAG = commit).
set -euo pipefail
cd "${MUYUY_DIR:-/opt/muyuy}"

# 1) Actualiza el repo y se vuelve a ejecutar: bash lee el script a medida que avanza,
#    así que sin esto correría la versión VIEJA de deploy.sh (la de antes del git reset).
if [ -z "${MUYUY_DEPLOY_ACTUALIZADO:-}" ]; then
  git fetch --quiet origin main
  git reset --hard origin/main        # compose, Caddyfile y data/; .env no está versionado: se conserva
  MUYUY_DEPLOY_ACTUALIZADO=1 exec bash "$0" "$@"
fi

# 2) Con el deploy.sh nuevo
export IMAGE="${IMAGE:-ghcr.io/redigb/xlr-muyuy}"   # Actions la manda = ghcr.io/<repo>; sobrevive a renombres
export IMAGE_TAG="${IMAGE_TAG:-latest}"
docker compose pull backend
docker compose build pipeline-api      # Python liviano: se construye en la VM
docker compose up -d --no-build --remove-orphans
docker image prune -f >/dev/null
docker compose ps
