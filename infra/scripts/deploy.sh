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

echo "=== Ensuring data services are running (non-destructive) ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d postgres redis

echo "=== Rebuilding backend image ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build backend

echo "=== Recreating backend only (keep postgres/redis running) ==="
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --no-deps --force-recreate backend

echo "=== Waiting for backend health check ==="
MAX_RETRIES=30
RETRY=0
until docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T backend wget -q --spider http://localhost:3000/health 2>/dev/null; do
  RETRY=$((RETRY + 1))
  if [ $RETRY -ge $MAX_RETRIES ]; then
    echo "ERROR: Backend did not become healthy after $MAX_RETRIES attempts."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs backend --tail=50
    exit 1
  fi
  echo "  Waiting... ($RETRY/$MAX_RETRIES)"
  sleep 2
done
echo "Backend is healthy."

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
