#!/usr/bin/env bash
set -euo pipefail

# ─── Deployment Script ───
# Run from the project root directory
# Usage: bash infra/scripts/deploy.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"
ENV_FILE="$INFRA_DIR/.env.production"
COMPOSE_FILE="$INFRA_DIR/docker-compose.prod.yml"

wait_for_backend_health() {
  echo "=== Waiting for backend health check ==="
  local max_retries=30
  local retry=0

  until docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T backend wget -q --spider http://localhost:3000/health 2>/dev/null; do
    retry=$((retry + 1))
    if [ "$retry" -ge "$max_retries" ]; then
      echo "ERROR: Backend did not become healthy after $max_retries attempts."
      docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs backend --tail=50
      exit 1
    fi
    echo "  Waiting... ($retry/$max_retries)"
    sleep 2
  done

  echo "Backend is healthy."
}

ensure_latest_migration_compiled() {
  local latest_migration_js="$1"
  if [ -z "$latest_migration_js" ]; then
    echo "No source migration file detected; skipping migration artifact check."
    return 0
  fi

  if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T backend sh -lc "test -f dist/migrations/$latest_migration_js"; then
    echo "Latest migration artifact found in container: dist/migrations/$latest_migration_js"
    return 0
  fi

  echo "WARNING: dist/migrations/$latest_migration_js not found after cached build."
  echo "Forcing backend rebuild without cache to avoid stale migration artifacts..."
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build --no-cache backend
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --no-deps --force-recreate backend
  wait_for_backend_health

  if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T backend sh -lc "test -f dist/migrations/$latest_migration_js"; then
    echo "ERROR: Migration artifact still missing after no-cache rebuild: dist/migrations/$latest_migration_js"
    exit 1
  fi

  echo "Latest migration artifact confirmed after no-cache rebuild."
}

echo "=== Marketplace Deployment ==="
echo "Project root: $PROJECT_ROOT"

# Check .env.production exists
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found."
  echo "Copy .env.production.example and fill in the secrets."
  exit 1
fi

echo "=== Pulling latest code ==="
cd "$PROJECT_ROOT"
git pull origin main

LATEST_MIGRATION_TS=$(ls -1 "$PROJECT_ROOT/backend/src/migrations/"*.ts 2>/dev/null | sort | tail -n 1 || true)
LATEST_MIGRATION_JS=""
if [ -n "$LATEST_MIGRATION_TS" ]; then
  LATEST_MIGRATION_JS="$(basename "${LATEST_MIGRATION_TS%.ts}.js")"
  echo "Latest source migration detected: $LATEST_MIGRATION_JS"
fi

echo "=== Ensuring data services are running (non-destructive) ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d postgres redis

echo "=== Rebuilding backend image ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build backend

echo "=== Recreating backend only (keep postgres/redis running) ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --no-deps --force-recreate backend

wait_for_backend_health
ensure_latest_migration_compiled "$LATEST_MIGRATION_JS"

echo "=== Running migrations ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T backend node -e "
  const { DataSource } = require('typeorm');
  const ds = new DataSource({
    type: 'postgres',
    url: process.env.DATABASE_URL,
    migrations: ['dist/migrations/*.js'],
  });
  ds.initialize()
    .then(d => d.runMigrations())
    .then(m => { console.log('Migrations applied:', m.length); process.exit(0); })
    .catch(e => { console.error('Migration failed:', e.message); process.exit(1); });
"

echo "=== Verifying /health endpoint ==="
HTTP_STATUS=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T backend wget -q -O /dev/null --server-response http://localhost:3000/health 2>&1 | grep -c "200 OK" || true)
if [ "$HTTP_STATUS" -ge 1 ]; then
  echo "Health check passed (200 OK)."
else
  echo "WARNING: Health check response was not 200."
fi

echo ""
echo "=== Deployment Complete ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
