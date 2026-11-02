#!/usr/bin/env bash
# ==============================================================================
#  Microsoft Office 2010 on Linux (Automated Wine Setup)
#  Author: bratiska6-pixel
#  License: MIT
# ==============================================================================

set -euo pipefail

# Цвета для вывода в терминал
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

echo -e "${BOLD}${BLUE}"
echo "=============================================================="
echo "   Microsoft Office 2010 (Wine Installer for Linux)           "
echo "   Word • Excel • PowerPoint • Outlook                       "
echo "=============================================================="
echo -e "${NC}"

WINE_PREFIX_DIR="${HOME}/.wine-office"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_ENTRY_DIR="${HOME}/.local/share/applications"

mkdir -p "${BIN_DIR}" "${DESKTOP_ENTRY_DIR}"
export PATH="${BIN_DIR}:${PATH}"

# 1. Проверка прав sudo и установка системных пакетов
info "1/6. Проверка системных пакетов и зависимостей..."
MISSING_PKGS=()
for pkg in wine wine32 wine64 winbind cabextract unzip curl; do
    if ! dpkg -l | grep -qE "^ii\s+${pkg}"; then
        MISSING_PKGS+=("${pkg}")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    warn "Отсутствуют необходимые пакеты: ${MISSING_PKGS[*]}"
    info "Установка системных пакетов через sudo apt..."
    sudo dpkg --add-architecture i386
    sudo apt update
    sudo apt install -y wine wine32 wine64 winbind cabextract unzip curl
    success "Системные пакеты установлены."
else
    success "Все необходимые системные пакеты уже установлены."
fi

# 2. Установка / обновление Winetricks
info "2/6. Проверка winetricks..."
if ! command -v winetricks &>/dev/null; then
    info "Скачивание актуальной версии winetricks..."
    curl -sSL https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -o "${BIN_DIR}/winetricks"
    chmod +x "${BIN_DIR}/winetricks"
    success "Winetricks установлен в ${BIN_DIR}/winetricks"
else
    success "Winetricks найден: $(command -v winetricks)"
fi

# 3. Поиск дистрибутива Microsoft Office 2010
info "3/6. Поиск установочных файлов Microsoft Office 2010..."
OFFICE_SETUP_DIR=""

SEARCH_CANDIDATES=(
    "./MS Office 2010 Pro Plus/x86"
    "./x86"
    "${HOME}/Загрузки/MS Office 2010 Pro Plus/x86"
    "${HOME}/Downloads/MS Office 2010 Pro Plus/x86"
    "${HOME}/Загрузки/x86"
    "${HOME}/Downloads/x86"
)

for cand in "${SEARCH_CANDIDATES[@]}"; do
    if [ -f "${cand}/setup.exe" ]; then
        OFFICE_SETUP_DIR="${cand}"
        break
    fi
done

if [ -z "${OFFICE_SETUP_DIR}" ]; then
    echo -e "${YELLOW}Не удалось автоматически найти папку x86 с setup.exe.${NC}"
    read -rp "Укажите абсолютный путь к папке дистрибутива Office (где лежит setup.exe): " USER_INPUT_PATH
    if [ -f "${USER_INPUT_PATH}/setup.exe" ]; then
        OFFICE_SETUP_DIR="${USER_INPUT_PATH}"
    elif [ -f "${USER_INPUT_PATH}/x86/setup.exe" ]; then
        OFFICE_SETUP_DIR="${USER_INPUT_PATH}/x86"
    else
        error "По указанному пути файл setup.exe не найден: ${USER_INPUT_PATH}"
    fi
fi

# Нормализуем путь
OFFICE_SETUP_DIR="$(cd "${OFFICE_SETUP_DIR}" && pwd)"
success "Найден инсталлятор Office в: ${OFFICE_SETUP_DIR}"

# 4. Создание и настройка 32-битного префикса Wine
info "4/6. Инициализация и настройка префикса Wine (~/.wine-office)..."
export WINEPREFIX="${WINE_PREFIX_DIR}"
export WINEARCH=win32
export DISPLAY="${DISPLAY:-:0}"

if [ ! -d "${WINE_PREFIX_DIR}" ]; then
    wineboot -u
    wineserver -w
fi

info "Установка шрифтов (corefonts) и режима Windows 7..."
winetricks -q corefonts win7
wineserver -w

info "Настройка DLL Overrides (msxml6, riched20, riched30, usp10)..."
wine reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "msxml6" /d "native,builtin" /f
wine reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "riched20" /d "native,builtin" /f
wine reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "riched30" /d "native,builtin" /f
wine reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v "usp10" /d "native,builtin" /f
wineserver -w
success "Префикс успешно подготовлен."

# 5. Устранение бага 1603 (ArpWrite) и запуск инсталлятора
info "5/6. Подготовка файла конфигурации config.xml..."
CONFIG_DIR="${OFFICE_SETUP_DIR}/ProPlus.WW"
if [ ! -d "${CONFIG_DIR}" ]; then
    # Ищем любой каталог конфигурации (*.WW)
    CONFIG_DIR="$(find "${OFFICE_SETUP_DIR}" -maxdepth 1 -type d -name "*.WW" | head -n 1)"
fi

if [ -d "${CONFIG_DIR}" ]; then
    cat << 'EOF' > "${CONFIG_DIR}/config.xml"
<Configuration Product="ProPlus">
	<Display Level="full" CompletionNotice="yes" SuppressModal="no" AcceptEula="yes" />
	<Setting Id="SETUPEXE_DOARPWRITE" Value="0" />
	<Setting Id="SETUP_REBOOT" Value="Never" />
</Configuration>
EOF
    success "Патч config.xml успешно применён в ${CONFIG_DIR}."
fi

echo -e "\n${BOLD}${YELLOW}>>> Внимание: Сейчас откроется графическое окно установки Microsoft Office.${NC}"
echo -e "${YELLOW}1. Нажмите «Установить» (или «Настройка» для выбора компонентов).${NC}"
echo -e "${YELLOW}2. Дождитесь завершения шкалы установки (2–4 минуты).${NC}"
echo -e "${YELLOW}3. По завершении нажмите «Закрыть».${NC}\n"

cd "${OFFICE_SETUP_DIR}"
# taskset -c 0 nice -n 19 устраняет падение MSI от состояния гонки потоков на быстрых многоядерных процессорах
taskset -c 0 nice -n 19 wine setup.exe /config "${CONFIG_DIR##*/}/config.xml"
wineserver -w

# Отключение самовосстановления и проверки лицензий NoReReg
info "Применение твика реестра NoReReg..."
wine reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\14.0\Word\Options" /v "NoReReg" /t REG_DWORD /d 1 /f
wine reg add "HKEY_CURRENT_USER\Software\Microsoft\Office\14.0\Excel\Options" /v "NoReReg" /t REG_DWORD /d 1 /f
wineserver -w
success "Твики реестра успешно применены."

# 6. Создание скриптов запуска и ярлыков рабочего стола
info "6/6. Создание скриптов запуска и ярлыков..."

# Скрипт Word
cat << EOF > "${HOME}/office-word.sh"
#!/bin/bash
export WINEPREFIX="${WINE_PREFIX_DIR}"
export WINEARCH=win32
export DISPLAY="\${DISPLAY:-:0}"
wine "\$WINEPREFIX/drive_c/Program Files/Microsoft Office/Office14/WINWORD.EXE" "\$@"
EOF

# Скрипт Excel
cat << EOF > "${HOME}/office-excel.sh"
#!/bin/bash
export WINEPREFIX="${WINE_PREFIX_DIR}"
export WINEARCH=win32
export DISPLAY="\${DISPLAY:-:0}"
wine "\$WINEPREFIX/drive_c/Program Files/Microsoft Office/Office14/EXCEL.EXE" "\$@"
EOF

# Скрипт PowerPoint
cat << EOF > "${HOME}/office-powerpoint.sh"
#!/bin/bash
export WINEPREFIX="${WINE_PREFIX_DIR}"
export WINEARCH=win32
export DISPLAY="\${DISPLAY:-:0}"
wine "\$WINEPREFIX/drive_c/Program Files/Microsoft Office/Office14/POWERPNT.EXE" "\$@"
EOF

chmod +x "${HOME}/office-word.sh" "${HOME}/office-excel.sh" "${HOME}/office-powerpoint.sh"

# Desktop-ярлык Word
cat << EOF > "${DESKTOP_ENTRY_DIR}/ms-word.desktop"
[Desktop Entry]
Name=Microsoft Word 2010
Comment=Текстовый процессор Microsoft Word
Exec=${HOME}/office-word.sh %F
Icon=x-office-document
Terminal=false
Type=Application
Categories=Office;WordProcessor;
MimeType=application/msword;application/vnd.openxmlformats-officedocument.wordprocessingml.document;
EOF

# Desktop-ярлык Excel
cat << EOF > "${DESKTOP_ENTRY_DIR}/ms-excel.desktop"
[Desktop Entry]
Name=Microsoft Excel 2010
Comment=Табличный процессор Microsoft Excel
Exec=${HOME}/office-excel.sh %F
Icon=x-office-spreadsheet
Terminal=false
Type=Application
Categories=Office;Spreadsheet;
MimeType=application/vnd.ms-excel;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;
EOF

# Desktop-ярлык PowerPoint
cat << EOF > "${DESKTOP_ENTRY_DIR}/ms-powerpoint.desktop"
[Desktop Entry]
Name=Microsoft PowerPoint 2010
Comment=Программа презентаций Microsoft PowerPoint
Exec=${HOME}/office-powerpoint.sh %F
Icon=x-office-presentation
Terminal=false
Type=Application
Categories=Office;Presentation;
MimeType=application/vnd.ms-powerpoint;application/vnd.openxmlformats-officedocument.presentationml.presentation;
EOF

chmod +x "${DESKTOP_ENTRY_DIR}"/ms-*.desktop

# Копируем на Рабочий стол (учитываем локализации "Desktop" и "Рабочий стол")
for dt_dir in "${HOME}/Desktop" "${HOME}/Рабочий стол"; do
    if [ -d "${dt_dir}" ]; then
        cp "${DESKTOP_ENTRY_DIR}"/ms-*.desktop "${dt_dir}/"
        chmod +x "${dt_dir}"/ms-*.desktop
        for f in "${dt_dir}"/ms-*.desktop; do
            gio set "${f}" metadata::trusted true 2>/dev/null || true
        done
        success "Ярлыки добавлены на Рабочий стол: ${dt_dir}"
    fi
done

update-desktop-database "${DESKTOP_ENTRY_DIR}" 2>/dev/null || true

echo -e "\n${BOLD}${GREEN}=============================================================="
echo "   Установка успешно завершена!"
echo "   Вы можете запускать Word, Excel и PowerPoint с Рабочего стола"
echo "   или из меню приложений системы."
echo "==============================================================${NC}\n"
