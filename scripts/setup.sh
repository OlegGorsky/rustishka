#!/bin/bash
# Главный скрипт настройки окружения
# Запуск: curl -sSL https://raw.githubusercontent.com/OlegGorsky/rustishka/main/scripts/setup.sh | bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/OlegGorsky/rustishka/main/scripts"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       Rustishka Dev Environment        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Установка: локальные инструменты + сервер"
echo ""

# Создаём временную директорию
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

download_script() {
    local name=$1
    echo -e "${YELLOW}⬇${NC} Загружаю $name..."
    curl -sSL "$REPO_URL/$name" -o "$TEMP_DIR/$name"
    chmod +x "$TEMP_DIR/$name"
}

# === ЭТАП 1: ЛОКАЛЬНАЯ УСТАНОВКА ===
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}   Этап 1: Локальная установка${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

download_script "setup-local.sh"
bash "$TEMP_DIR/setup-local.sh"

# === ЭТАП 2: НАСТРОЙКА СЕРВЕРА ===
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}   Этап 2: Настройка сервера${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

download_script "setup-server.sh"
bash "$TEMP_DIR/setup-server.sh"

# === ИТОГИ ===
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Установка завершена!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

echo "Созданные файлы:"
echo ""

if [ -f "$HOME/.stack-installed.txt" ]; then
    echo "  ~/.stack-installed.txt - список локальных инструментов"
fi

CREDS_FILE=$(ls "$HOME"/.server-credentials-*.txt 2>/dev/null | head -1 || true)
if [ -n "$CREDS_FILE" ]; then
    echo "  $CREDS_FILE - доступы к серверу"
fi

echo ""
echo -e "${YELLOW}Перезапусти терминал для применения алиасов!${NC}"
echo ""
