#!/bin/bash
# restore.sh - Capstone Linux Project (Role 4: Database & Backup)
#
# Restores DB + app content from a backup archive created by backup.sh.
# Must be tested for real: wipe data, restore, verify data is back.

# Enforce strict error handling
set -euo pipefail

error_handler() {
    echo "[ERROR] Restore process failed at line $1" >&2
}
trap 'error_handler $LINENO' ERR EXIT

# --help / -h (checked before the positional-arg check so it always works)
usage() {
    cat <<EOF
Usage: $0 <path_to_backup_file.tar.gz>
       $0 --help

Restores the PostgreSQL database and app content from a backup archive
produced by backup.sh, then restarts the app services.
EOF
}
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi
BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "[ERROR] Backup file not found: $BACKUP_FILE" >&2
    exit 1
fi

# ---- Load secrets ----
ENV_FILE="/etc/capstoneapp/.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "[ERROR] Environment file $ENV_FILE not found!" >&2
    exit 1
fi

: "${DB_CONTAINER_NAME:?DB_CONTAINER_NAME not set in $ENV_FILE}"
: "${DB_USER:?DB_USER not set in $ENV_FILE}"
: "${DB_NAME:?DB_NAME not set in $ENV_FILE}"

echo "[INFO] Starting restore process from $BACKUP_FILE..."

# ---- Extract to temp dir ----
TEMP_DIR=$(mktemp -d)
echo "[INFO] Extracting backup..."
sudo tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# ---- Find the extracted SQL dump (glob array, not `ls | head`) ----
shopt -s nullglob
DB_FILES=("$TEMP_DIR"/db_*.sql)
shopt -u nullglob
if [ ${#DB_FILES[@]} -eq 0 ]; then
    echo "[ERROR] No DB dump file (db_*.sql) found inside $BACKUP_FILE" >&2
    sudo rm -rf "$TEMP_DIR"
    exit 1
fi
DB_FILE="${DB_FILES[0]}"

# ---- Restore DB ----
# ON_ERROR_STOP=1: psql aborts on the first SQL error instead of silently
# continuing, so a partial/broken restore can never be reported as SUCCESS.
echo "[INFO] Restoring PostgreSQL database into Docker..."
sudo cat "$DB_FILE" | sudo docker exec -i "$DB_CONTAINER_NAME" psql -v ON_ERROR_STOP=1 \
    -U "$DB_USER" -d "$DB_NAME"

# ---- Restore app files ----
echo "[INFO] Restoring app files..."
sudo cp -a "$TEMP_DIR/opt/capstone-app/." /opt/capstone-app/
sudo cp -a "$TEMP_DIR/opt/info-app/." /opt/info-app/

# ---- Restart services ----
echo "[INFO] Restarting systemd services..."
sudo systemctl restart capstone-app.service
sudo systemctl restart info-app.service

# ---- Cleanup ----
echo "[INFO] Cleaning up temp files..."
sudo rm -rf "$TEMP_DIR"

# Clear trap on successful completion
trap - ERR EXIT
echo "[SUCCESS] System restored successfully from $BACKUP_FILE"