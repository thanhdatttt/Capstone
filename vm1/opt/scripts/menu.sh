#!/bin/bash
# menu.sh - Interactive Operations & Automation CLI Menu
set -euo pipefail

trap 'echo -e "\n[INFO] Exiting menu. Goodbye!"; exit 0' INT

# Color definitions
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPTS_DIR="/opt/scripts"

show_header() {
    clear
    echo -e "${CYAN}======================================================================${NC}"
    echo -e "${GREEN}    LINUX SYSTEM OPERATIONS & AUTOMATION MANAGEMENT TOOLKIT${NC}"
    echo -e "${CYAN}    Host: $(hostname) | User: $(whoami) | $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}======================================================================${NC}"
}

pause() {
    echo -e "\n${YELLOW}Press [Enter] key to return to main menu...${NC}"
    read -r
}

while true; do
    show_header
    echo -e "  ${YELLOW}1.${NC} 🚀 Safe Deployment & Rollback       (deploy.sh)"
    echo -e "  ${YELLOW}2.${NC} 💾 Automated Backup & Rsync to VM2  (backup.sh)"
    echo -e "  ${YELLOW}3.${NC} 🔄 Restore Database & App           (restore.sh)"
    echo -e "  ${YELLOW}4.${NC} 🩺 System Health Check & Alerting   (health-check.sh)"
    echo -e "  ${YELLOW}5.${NC} 📜 Rotate & Compress Logs           (log-rotate.sh)"
    echo -e "  ${YELLOW}6.${NC} 🛡️ Security & Service Quick Status"
    echo -e "  ${RED}0.${NC} 🚪 Exit"
    echo -e "${CYAN}----------------------------------------------------------------------${NC}"
    read -rp "Please enter your choice [0-6]: " choice

    case "$choice" in
        1)
            echo -e "\n${GREEN}--- [1] SAFE DEPLOYMENT ---${NC}"
            echo "Select app to deploy:"
            echo "  1) capstone-app (Express CRUD)"
            echo "  2) info-app (SysInfo Service)"
            read -rp "Choice [1-2]: " app_choice
            if [ "$app_choice" == "1" ]; then
                sudo "$SCRIPTS_DIR/deploy.sh" --app capstone-app
            elif [ "$app_choice" == "2" ]; then
                sudo "$SCRIPTS_DIR/deploy.sh" --app info-app
            else
                echo -e "${RED}[!] Invalid app choice.${NC}"
            fi
            pause
            ;;
        2)
            echo -e "\n${GREEN}--- [2] RUNNING AUTOMATED BACKUP ---${NC}"
            sudo "$SCRIPTS_DIR/backup.sh"
            pause
            ;;
        3)
            echo -e "\n${GREEN}--- [3] SYSTEM RESTORE ---${NC}"
            echo "Available backup archives:"
            shopt -s nullglob
            backups=(/data/backups/capstoneapp/backup_*.tar.gz)
            shopt -u nullglob
            if [ ${#backups[@]} -eq 0 ]; then
                echo -e "${RED}[!] No backup archives found in /data/backups/capstoneapp/${NC}"
            else
                for i in "${!backups[@]}"; do
                    echo "  $((i+1))) ${backups[$i]}"
                done
                read -rp "Select backup number to restore [1-${#backups[@]}]: " b_choice
                if [[ "$b_choice" =~ ^[0-9]+$ ]] && [ "$b_choice" -ge 1 ] && [ "$b_choice" -le "${#backups[@]}" ]; then
                    selected_file="${backups[$((b_choice-1))]}"
                    read -rp "Are you SURE you want to restore from $selected_file? (y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        sudo "$SCRIPTS_DIR/restore.sh" "$selected_file"
                    else
                        echo "[INFO] Restore cancelled."
                    fi
                else
                    echo -e "${RED}[!] Invalid selection.${NC}"
                fi
            fi
            pause
            ;;
        4)
            echo -e "\n${GREEN}--- [4] SYSTEM HEALTH CHECK ---${NC}"
            sudo "$SCRIPTS_DIR/health-check.sh"
            pause
            ;;
        5)
            echo -e "\n${GREEN}--- [5] LOG ROTATION ---${NC}"
            sudo "$SCRIPTS_DIR/log-rotate.sh" --file /var/log/health-check.log --keep 5
            pause
            ;;
        6)
            echo -e "\n${GREEN}--- [6] QUICK SYSTEM STATUS ---${NC}"
            echo -e "${YELLOW}* Systemd Services:${NC}"
            systemctl is-active nginx capstone-app info-app docker fail2ban
            echo -e "\n${YELLOW}* Listening Ports:${NC}"
            ss -tulpn | grep -E ':(80|443|3000|4000|5432) '
            echo -e "\n${YELLOW}* Disk Usage:${NC}"
            df -h / /data
            pause
            ;;
        0)
            echo -e "\n${GREEN}Exiting. Have a great day!${NC}"
            exit 0
            ;;
        *)
            echo -e "\n${RED}[ERROR] Invalid option '$choice'. Please choose from 0 to 6.${NC}"
            sleep 1
            ;;
    esac
done
