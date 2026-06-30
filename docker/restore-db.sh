#!/bin/sh
set -e

BACKUP_FILE="/backups/chatwoot.sql"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "No backup file found, skipping restore."
    exit 0
fi

TABLES=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0")

if [ "$TABLES" = "0" ]; then
    echo "Database is empty, restoring from backup..."
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$BACKUP_FILE"
    echo "Restore complete."
else
    echo "Database has data, skipping restore."
fi
