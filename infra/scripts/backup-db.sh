#!/usr/bin/env bash
set -euo pipefail

# ─── Database Backup Script ───
# Creates a compressed pg_dump and retains the last 7 backups.
# Usage: bash infra/scripts/backup-db.sh
# Crontab: 0 3 * * * /home/marketplace/Marketplace-Evelyn/infra/scripts/backup-db.sh >> /var/log/marketplace-backup.log 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$INFRA_DIR/.env.production"
COMPOSE_FILE="$INFRA_DIR/docker-compose.prod.yml"
BACKUP_DIR="$INFRA_DIR/backups"
RETAIN_COUNT=7

mkdir -p "$BACKUP_DIR"

# Load environment
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/marketplace_${TIMESTAMP}.sql.gz"

echo "[$(date -u -Iseconds)] Starting database backup..."

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T postgres \
  pg_dump -U "${POSTGRES_USER:-marketplace}" "${POSTGRES_DB:-marketplace}" \
  | gzip > "$BACKUP_FILE"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date -u -Iseconds)] Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# Retain only last N backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/marketplace_*.sql.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$RETAIN_COUNT" ]; then
  REMOVE_COUNT=$((BACKUP_COUNT - RETAIN_COUNT))
  ls -1t "$BACKUP_DIR"/marketplace_*.sql.gz | tail -n "$REMOVE_COUNT" | xargs rm -f
  echo "[$(date -u -Iseconds)] Removed $REMOVE_COUNT old backup(s). Retained last $RETAIN_COUNT."
fi

echo "[$(date -u -Iseconds)] Backup complete."
