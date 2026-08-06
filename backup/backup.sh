#!/bin/bash

# Enforce strict error handling
set -euo pipefail

# Error trapping to pinpoint failures
error_handler() {
    echo "[ERROR] Backup process failed at line $1" >&2
}
trap 'error_handler $LINENO' ERR EXIT

# --help / -h
usage() {
    cat <<EOF
Usage: $0 [--help]

Dumps the PostgreSQL database (via Docker) and tars app content into a
single timestamped, compressed archive under \$BACKUP_DIR, prunes backups
older than \$RETENTION_DAYS days, and rsyncs the new archive to VM2.

No arguments are required for normal operation.
EOF
    trap - ERR EXIT
    exit 0
}
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage

# ---- Config ----
BACKUP_DIR="/var/backups/capstoneapp"
APP1_DIR="/opt/capstone-app"
APP2_DIR="/opt/info-app"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.tar.gz"
DB_DUMP_FILE="${BACKUP_DIR}/db_${TIMESTAMP}.sql"

# rsync target — fixed values, do NOT rely on $SUDO_USER (unset when run
# from cron/systemd, and set -u would kill the script on that line)
RSYNC_USER="opsadmin"
RSYNC_HOST="192.168.56.104"
RSYNC_DEST="/data/backups/capstoneapp/"   # relative to $RSYNC_USER's home on VM2, no literal ~ in quotes

# ---- Load secrets ----
ENV_FILE="/etc/capstoneapp/.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "[ERROR] Environment file $ENV_FILE not found!" >&2
    exit 1
fi

# Required vars from env file — fail fast with a clear message if missing
: "${DB_CONTAINER_NAME:?DB_CONTAINER_NAME not set in $ENV_FILE}"
: "${DB_USER:?DB_USER not set in $ENV_FILE}"
: "${DB_NAME:?DB_NAME not set in $ENV_FILE}"

echo "[INFO] Starting backup process..."
sudo mkdir -p "$BACKUP_DIR"

# ---- DB dump (via Docker) ----
# --clean --if-exists: dump includes DROP ... IF EXISTS before CREATE, so
# restore.sh works whether the table still exists (data-only wipe test) or
# has been dropped entirely (full disaster test).
echo "[INFO] Dumping the PostgreSQL database from Docker..."
sudo docker exec "$DB_CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --clean --if-exists -F p | sudo tee "$DB_DUMP_FILE" > /dev/null

# ---- Compress app files and DB dump together ----
echo "[INFO] Compressing app files and database dump..."
sudo tar -czf "$BACKUP_FILE" \
    -C / "${APP1_DIR#/}" "${APP2_DIR#/}" \
    -C "$BACKUP_DIR" "$(basename "$DB_DUMP_FILE")"

# ---- Cleanup temp SQL file (now inside the archive) ----
sudo rm -f "$DB_DUMP_FILE"

# ---- Retention: delete backups older than RETENTION_DAYS ----
echo "[INFO] Cleaning up backups older than $RETENTION_DAYS days..."
sudo find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -mtime +"$RETENTION_DAYS" -exec rm -f {} \;

# ---- Transfer to VM2 ----
echo "[INFO] Transferring backup to VM2..."
sudo -u "$RSYNC_USER" rsync -avz -e "ssh -o StrictHostKeyChecking=no" \
    "$BACKUP_FILE" "${RSYNC_USER}@${RSYNC_HOST}:${RSYNC_DEST}"

# Clear the trap on successful completion
trap - ERR EXIT
echo "[SUCCESS] Backup completed: $BACKUP_FILE"
