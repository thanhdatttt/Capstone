#!/bin/bash
# restore.sh - Capstone Linux Project
set -euo pipefail

error_handler() {
    echo "[ERROR] Restore process failed at line $1" >&2
}
trap 'error_handler $LINENO' ERR EXIT

usage() {
    cat << "EOF"
Usage: restore.sh <path_to_backup_file.tar.gz>
       restore.sh --help

Restores the PostgreSQL database, app content and web content from a backup
produced by backup.sh, then restarts the app services.
EOF
    trap - ERR EXIT
    exit 0
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
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

# ---- Find the extracted SQL dump ----
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
echo "[INFO] Restoring PostgreSQL database into Docker..."
sudo cat "$DB_FILE" | sudo docker exec -i "$DB_CONTAINER_NAME" psql -v ON_ERROR_STOP=1 \
    -U "$DB_USER" -d "$DB_NAME"

# ---- Restore app files ----
echo "[INFO] Restoring app files..."
if [[ -d "$TEMP_DIR/opt/capstone-app" ]]; then
    sudo mkdir -p /opt/capstone-app
    sudo cp -a "$TEMP_DIR/opt/capstone-app/." /opt/capstone-app/
    sudo chown -R svc-capstone:svc-capstone /opt/capstone-app
    sudo chmod 600 /opt/capstone-app/.env 2>/dev/null || true
fi

if [[ -d "$TEMP_DIR/opt/info-app" ]]; then
    sudo mkdir -p /opt/info-app
    sudo cp -a "$TEMP_DIR/opt/info-app/." /opt/info-app/
    sudo chown -R svc-info:svc-info /opt/info-app
    sudo chmod 600 /opt/info-app/.env 2>/dev/null || true
fi

# ---- Restore web content ----
echo "[INFO] Restoring web content..."
if [[ -d "$TEMP_DIR/var/www" ]]; then
    sudo mkdir -p /var/www
    sudo cp -a "$TEMP_DIR/var/www/." /var/www/
fi

if [[ -d "$TEMP_DIR/etc/nginx/sites-available" ]]; then
    sudo cp -a "$TEMP_DIR/etc/nginx/sites-available/." /etc/nginx/sites-available/
    # Only reload if the restored configuration is valid, so a bad backup
    # cannot take the web server down.
    if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx
        echo "[INFO] Nginx configuration restored and reloaded."
    else
        echo "[WARN] Restored Nginx config failed validation; not reloading." >&2
    fi
fi

# ---- Restart services ----
echo "[INFO] Restarting systemd services..."

if systemctl list-unit-files | grep -q "capstone-app.service"; then
    sudo systemctl restart capstone-app.service
fi

if systemctl list-unit-files | grep -q "info-app.service"; then
    sudo systemctl restart info-app.service
fi

# ---- Cleanup ----
echo "[INFO] Cleaning up temp files..."
sudo rm -rf "$TEMP_DIR"

# Clear trap on successful completion
trap - ERR EXIT
echo "[SUCCESS] System restored successfully from $BACKUP_FILE"
