#!/usr/bin/env bash
# ==============================================================================
#  Microsoft Office 2010 on Linux (Clean Uninstaller)
#  Author: bratiska6-pixel
#  License: MIT
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${RED}"
echo "=============================================================="
echo "   Удаление Microsoft Office 2010 и префикса Wine            "
echo "=============================================================="
echo -e "${NC}"

read -rp "Вы уверены, что хотите полностью удалить Microsoft Office и префикс ~/.wine-office? [y/N]: " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[YyДд]$ ]]; then
    echo "Отмена операции."
    exit 0
fi

echo -e "${YELLOW}Остановка активных процессов Wine...${NC}"
WINEPREFIX="${HOME}/.wine-office" wineserver -k 2>/dev/null || true

echo -e "${YELLOW}Удаление префикса ~/.wine-office...${NC}"
rm -rf "${HOME}/.wine-office"

echo -e "${YELLOW}Удаление скриптов запуска...${NC}"
rm -f "${HOME}/office-word.sh" "${HOME}/office-excel.sh" "${HOME}/office-powerpoint.sh"

echo -e "${YELLOW}Удаление desktop-ярлыков...${NC}"
rm -f "${HOME}/.local/share/applications"/ms-*.desktop
rm -f "${HOME}/Desktop"/ms-*.desktop 2>/dev/null || true
rm -f "${HOME}/Рабочий стол"/ms-*.desktop 2>/dev/null || true

update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

echo -e "\n${BOLD}${GREEN}Microsoft Office и все созданные ярлыки успешно удалены из системы.${NC}\n"
