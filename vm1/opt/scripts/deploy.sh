#!/bin/bash
# deploy.sh - Safe Deployment Script with Automated Rollback
set -euo pipefail

error_handler() {
    echo "[ERROR] Deployment failed at line $1" >&2
}
trap 'error_handler $LINENO' ERR EXIT

usage() {
    cat << "EOF"
Usage: deploy.sh [OPTIONS]

Options:
  -a, --app APP_NAME     Application to deploy (capstone-app | info-app)
  -s, --src SOURCE_DIR   Path to new application source code directory
  -h, --help             Display this help message and exit

Description:
  Safely deploys new application code:
  1. Creates an immediate pre-deployment backup.
  2. Copies new files and fixes ownership / permissions.
  3. Tests configuration and restarts systemd service.
  4. Performs health check.
  5. If validation fails, automatically rolls back to the last working state.
EOF
    trap - ERR EXIT
    exit 0
}

APP_NAME="capstone-app"
SOURCE_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--app) APP_NAME="$2"; shift 2 ;;
        -s|--src) SOURCE_DIR="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

TARGET_DIR="/opt/${APP_NAME}"
SERVICE_NAME="${APP_NAME}.service"
BACKUP_BASE="/data/backups/deployments"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE}/${APP_NAME}_backup_${TIMESTAMP}"

if [ ! -d "$TARGET_DIR" ]; then
    echo "[ERROR] Target directory $TARGET_DIR does not exist!" >&2
    exit 1
fi

if [ -z "$SOURCE_DIR" ]; then
    echo "[INFO] No --src specified. Performing safe service test and reload on existing $TARGET_DIR..."
elif [ ! -d "$SOURCE_DIR" ]; then
    echo "[ERROR] Source directory $SOURCE_DIR does not exist!" >&2
    exit 1
fi

# Determine service user
if [ "$APP_NAME" == "capstone-app" ]; then
    SVC_USER="svc-capstone"
    HEALTH_URL="http://127.0.0.1:3000/api/health"
elif [ "$APP_NAME" == "info-app" ]; then
    SVC_USER="svc-info"
    HEALTH_URL="http://127.0.0.1:4000/"
else
    SVC_USER="root"
    HEALTH_URL="http://127.0.0.1/"
fi

echo "=================================================="
echo "    SAFE DEPLOYMENT & ROLLBACK ENGINE"
echo "    App: $APP_NAME | User: $SVC_USER"
echo "=================================================="

# Step 1: Pre-deployment backup
echo "[1/5] Creating pre-deployment backup..."
sudo mkdir -p "$BACKUP_BASE"
sudo cp -a "$TARGET_DIR" "$BACKUP_DIR"
echo "[+] Backup saved to: $BACKUP_DIR"

# Rollback function
rollback() {
    echo "--------------------------------------------------"
    echo "[!] CRITICAL: Deployment verification failed! Initiating Rollback..."
    sudo cp -a "$BACKUP_DIR/." "$TARGET_DIR/"
    sudo chown -R "$SVC_USER:$SVC_USER" "$TARGET_DIR"
    sudo chmod 600 "$TARGET_DIR/.env" 2>/dev/null || true
    sudo systemctl restart "$SERVICE_NAME"
    echo "[+] System rolled back to previous working state."
    echo "--------------------------------------------------"
    trap - ERR EXIT
    exit 1
}

# Step 2: Deploy new code if source provided
if [ -n "$SOURCE_DIR" ]; then
    echo "[2/5] Copying new files to $TARGET_DIR..."
    sudo cp -a "$SOURCE_DIR/." "$TARGET_DIR/"
    sudo chown -R "$SVC_USER:$SVC_USER" "$TARGET_DIR"
    sudo chmod 600 "$TARGET_DIR/.env" 2>/dev/null || true
fi

# Step 3: Syntax / Configuration test
echo "[3/5] Testing code syntax..."
if [ -f "$TARGET_DIR/server.js" ]; then
    if ! node -c "$TARGET_DIR/server.js" 2>/dev/null; then
        echo "[-] Syntax check failed for server.js!"
        rollback
    fi
    echo "[+] Syntax test passed."
fi

# Step 4: Restart Service
echo "[4/5] Restarting systemd service: $SERVICE_NAME..."
if ! sudo systemctl restart "$SERVICE_NAME"; then
    echo "[-] Service restart failed!"
    rollback
fi

# Step 5: Post-deployment Health Check
echo "[5/5] Performing post-deployment health check..."
sleep 2

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "[-] Service $SERVICE_NAME is not active!"
    rollback
fi

# Check HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then
    echo "[+] Health check endpoint responded with HTTP $HTTP_CODE [OK]"
else
    echo "[-] Health check failed (HTTP $HTTP_CODE)!"
    rollback
fi

echo "=================================================="
echo "[SUCCESS] Deployment completed and verified for $APP_NAME!"
echo "=================================================="
trap - ERR EXIT
