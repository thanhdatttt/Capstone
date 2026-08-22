#!/bin/bash
# log-rotate.sh - Log Rotation and Archival Tool
set -euo pipefail

error_handler() {
    echo "[ERROR] Log rotation failed at line $1" >&2
}
trap 'error_handler $LINENO' ERR EXIT

usage() {
    cat << "EOF"
Usage: log-rotate.sh [OPTIONS]

Options:
  -f, --file LOG_FILE    Path to log file to rotate (default: /var/log/health-check.log)
  -k, --keep COUNT       Number of rotated generations to keep (default: 5)
  -h, --help             Display this help message and exit

Description:
  Rotates, compresses with gzip, and manages retention of log files.
  Keeps N generations and purges older logs to prevent disk exhaustion.
EOF
    trap - ERR EXIT
    exit 0
}

LOG_FILE="/var/log/health-check.log"
KEEP=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file) LOG_FILE="$2"; shift 2 ;;
        -k|--keep) KEEP="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ ! -f "$LOG_FILE" ]; then
    echo "[WARN] Log file $LOG_FILE does not exist. Creating empty log file..."
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chmod 666 "$LOG_FILE"
fi

echo "=================================================="
echo "    LOG ROTATION & RETENTION ENGINE"
echo "    Target: $LOG_FILE | Keep: $KEEP generations"
echo "=================================================="

# 1. Rotate existing compressed archives (e.g. log.4.gz -> log.5.gz)
for (( i=KEEP; i>=1; i-- )); do
    OLD_FILE="${LOG_FILE}.${i}.gz"
    NEXT_FILE="${LOG_FILE}.$((i+1)).gz"

    if [ "$i" -eq "$KEEP" ] && [ -f "$OLD_FILE" ]; then
        echo "[+] Purging oldest generation: $OLD_FILE"
        sudo rm -f "$OLD_FILE"
    elif [ -f "$OLD_FILE" ]; then
        sudo mv "$OLD_FILE" "$NEXT_FILE"
    fi
done

# 2. Move current log to .1
echo "[+] Rotating current log..."
sudo cp "$LOG_FILE" "${LOG_FILE}.1"
sudo truncate -s 0 "$LOG_FILE"

# 3. Compress .1 with gzip
echo "[+] Compressing ${LOG_FILE}.1..."
sudo gzip -f "${LOG_FILE}.1"

echo "=================================================="
echo "[SUCCESS] Log rotation complete! Current archives:"
ls -lh "${LOG_FILE}"* 2>/dev/null || true
echo "=================================================="
trap - ERR EXIT
