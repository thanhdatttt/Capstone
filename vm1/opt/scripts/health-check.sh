#!/bin/bash
# health-check.sh - Capstone Linux System Health Monitor
set -euo pipefail

error_handler() {
    echo "[ERROR] Health-check script failed at line $1" >&2
}
trap 'error_handler $LINENO' ERR EXIT

usage() {
    cat << "EOF"
Usage: health-check.sh [OPTIONS]

Options:
  -c, --cpu THRESHOLD    CPU threshold percentage (default: 80)
  -m, --mem THRESHOLD    Memory threshold percentage (default: 85)
  -d, --disk THRESHOLD   Disk threshold percentage (default: 80)
  -h, --help             Display this help message and exit

Description:
  Inspects system health (CPU, RAM, Disk, listening ports, and services).
  If anomalies are detected, logs to /var/log/health-check.log and
  dispatches an email alert via msmtp.
EOF
    trap - ERR EXIT
    exit 0
}

# Default thresholds
CPU_THRESH=80
MEM_THRESH=85
DISK_THRESH=80
ALERT_EMAIL="namhaohuynh@gmail.com"
FROM_EMAIL="hownameee@gmail.com"
LOG_FILE="/var/log/health-check.log"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cpu) CPU_THRESH="$2"; shift 2 ;;
        -m|--mem) MEM_THRESH="$2"; shift 2 ;;
        -d|--disk) DISK_THRESH="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

echo "=================================================="
echo "    LINUX CAPSTONE SYSTEM HEALTH CHECK"
echo "    Host: $(hostname) | Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

ISSUES=()

# 1. Check CPU Usage
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int($1)}')
CPU_USAGE=$(( 100 - CPU_IDLE ))
if [ "$CPU_USAGE" -ge "$CPU_THRESH" ]; then
    ISSUES+=("CPU usage is HIGH: ${CPU_USAGE}% (Threshold: ${CPU_THRESH}%)")
    echo "[-] CPU Usage:      ${CPU_USAGE}% [ALERT]"
else
    echo "[+] CPU Usage:      ${CPU_USAGE}% [OK]"
fi

# 2. Check RAM Usage
MEM_USAGE=$(free -m | awk '/Mem:/ {printf "%d", $3/$2 * 100}')
if [ "$MEM_USAGE" -ge "$MEM_THRESH" ]; then
    ISSUES+=("RAM usage is HIGH: ${MEM_USAGE}% (Threshold: ${MEM_THRESH}%)")
    echo "[-] RAM Usage:      ${MEM_USAGE}% [ALERT]"
else
    echo "[+] RAM Usage:      ${MEM_USAGE}% [OK]"
fi

# 3. Check Disk Usage (/ and /data)
while read -r mountpoint use_pct; do
    pct_num=${use_pct%\%}
    if [ "$pct_num" -ge "$DISK_THRESH" ]; then
        ISSUES+=("Disk usage on $mountpoint is HIGH: $use_pct (Threshold: ${DISK_THRESH}%)")
        echo "[-] Disk ($mountpoint):   $use_pct [ALERT]"
    else
        echo "[+] Disk ($mountpoint):   $use_pct [OK]"
    fi
done < <(df -h / /data | awk 'NR>1 {print $6, $5}')

# 4. Check Required Listening Ports (80, 443, 3000, 4000, 5432)
PORTS=(80 443 3000 4000 5432)
for port in "${PORTS[@]}"; do
    if ss -tulpn | grep -q ":${port} "; then
        echo "[+] Port $port:        LISTENING [OK]"
    else
        ISSUES+=("Port $port is NOT listening!")
        echo "[-] Port $port:        NOT LISTENING [ALERT]"
    fi
done

# 5. Check Systemd & Docker Services
SERVICES=("nginx" "capstone-app" "info-app" "docker")
for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        echo "[+] Service $svc: ACTIVE [OK]"
    else
        ISSUES+=("Service '$svc' is DOWN/INACTIVE!")
        echo "[-] Service $svc: INACTIVE [ALERT]"
    fi
done

# 6. Trigger Alert if issues found
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo "--------------------------------------------------"
    echo "[!] Warning: ${#ISSUES[@]} issue(s) detected. Triggering alert..."

    ALERT_MSG="🚨 [ALERT] System Health Anomaly Detected on $(hostname)
Time: $(date '+%Y-%m-%d %H:%M:%S')

Issues:
"
    for issue in "${ISSUES[@]}"; do
        ALERT_MSG+="- $issue
"
    done

    # Log to file
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] HEALTH_CHECK_ALERT: ${ISSUES[*]}" | sudo tee -a "$LOG_FILE" >/dev/null

    # Send Email via msmtp
    echo -e "Subject: 🚨 [ALERT] System Issues on $(hostname)\nFrom: ${FROM_EMAIL}\nTo: ${ALERT_EMAIL}\n\n${ALERT_MSG}" | msmtp "$ALERT_EMAIL" || true
    echo "[+] Email alert sent to $ALERT_EMAIL via msmtp."
else
    echo "--------------------------------------------------"
    echo "[+] All health metrics and services are OK."
fi

trap - ERR EXIT
