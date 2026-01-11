#!/bin/bash
# Установка локальных инструментов

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_skip() { echo -e "${YELLOW}→${NC} $1 (уже установлен)"; }
log_install() { echo -e "${YELLOW}⬇${NC} Устанавливаю $1..."; }
log_update() { echo -e "${CYAN}↑${NC} Обновляю $1..."; }
log_error() { echo -e "${RED}✗${NC} $1"; }

CYAN='\033[0;36m'

INSTALLED=()
SKIPPED=()
UPDATED=()
FAILED=()

check_and_install() {
    local name=$1
    local check_cmd=$2
    local install_cmd=$3

    if eval "$check_cmd" &>/dev/null; then
        log_skip "$name"
        SKIPPED+=("$name")
    else
        log_install "$name"
        if eval "$install_cmd"; then
            log_ok "$name установлен"
            INSTALLED+=("$name")
        else
            log_error "Не удалось установить $name"
            FAILED+=("$name")
        fi
    fi
}

# Установка или обновление cargo пакета
cargo_install_or_update() {
    local name=$1
    local bin_name=${2:-$1}

    if command -v "$bin_name" &>/dev/null; then
        log_update "$name"
        if cargo install "$name" 2>&1 | grep -q "Replacing"; then
            log_ok "$name обновлён"
            UPDATED+=("$name")
        else
            log_skip "$name (актуальная версия)"
            SKIPPED+=("$name")
        fi
    else
        log_install "$name"
        if cargo install "$name"; then
            log_ok "$name установлен"
            INSTALLED+=("$name")
        else
            log_error "Не удалось установить $name"
            FAILED+=("$name")
        fi
    fi
}

echo "=========================================="
echo "   Установка локального окружения"
echo "=========================================="
echo ""

# --- Системные зависимости ---
echo "--- Системные пакеты ---"
sudo apt update -qq

check_and_install "curl" "command -v curl" "sudo apt install -y curl"
check_and_install "git" "command -v git" "sudo apt install -y git"
check_and_install "build-essential" "dpkg -s build-essential" "sudo apt install -y build-essential"
check_and_install "pkg-config" "command -v pkg-config" "sudo apt install -y pkg-config"
check_and_install "libssl-dev" "dpkg -s libssl-dev" "sudo apt install -y libssl-dev"
check_and_install "gnupg" "command -v gpg" "sudo apt install -y gnupg"
check_and_install "pass" "command -v pass" "sudo apt install -y pass"
check_and_install "btop" "command -v btop" "sudo apt install -y btop"
check_and_install "jq" "command -v jq" "sudo apt install -y jq"
check_and_install "yq" "command -v yq" "sudo apt install -y yq"

echo ""
# --- Rust ---
echo "--- Rust ---"
if command -v rustc &>/dev/null; then
    log_skip "Rust $(rustc --version | cut -d' ' -f2)"
    SKIPPED+=("rust")
else
    log_install "Rust"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    log_ok "Rust установлен"
    INSTALLED+=("rust")
fi

# Убедимся что cargo в PATH
export PATH="$HOME/.cargo/bin:$PATH"

echo ""
# --- Rust CLI инструменты ---
echo "--- Rust CLI инструменты ---"

cargo_install_or_update "eza" "eza"
cargo_install_or_update "bat" "bat"
cargo_install_or_update "fd-find" "fd"
cargo_install_or_update "ripgrep" "rg"
cargo_install_or_update "zoxide" "zoxide"
cargo_install_or_update "du-dust" "dust"
cargo_install_or_update "git-delta" "delta"
cargo_install_or_update "tokei" "tokei"
cargo_install_or_update "hyperfine" "hyperfine"
cargo_install_or_update "gitui" "gitui"
cargo_install_or_update "starship" "starship"
cargo_install_or_update "xsv" "xsv"
cargo_install_or_update "just" "just"
cargo_install_or_update "watchexec-cli" "watchexec"

echo ""
# --- Cargo расширения ---
echo "--- Cargo расширения ---"

cargo_install_or_update "cargo-audit" "cargo-audit"
cargo_install_or_update "cargo-tarpaulin" "cargo-tarpaulin"
cargo_install_or_update "cargo-watch" "cargo-watch"
cargo_install_or_update "cargo-edit" "cargo-add"
cargo_install_or_update "cargo-outdated" "cargo-outdated"
cargo_install_or_update "cargo-nextest" "cargo-nextest"
cargo_install_or_update "bacon" "bacon"
cargo_install_or_update "sqlx-cli" "sqlx"
cargo_install_or_update "tokio-console" "tokio-console"

echo ""
# --- Beads ---
echo "--- Beads (AI память) ---"
cargo_install_or_update "beads" "bd"

echo ""
# --- fnm + Node.js + pnpm ---
echo "--- Node.js (fnm + pnpm) ---"

# fnm
if command -v fnm &>/dev/null; then
    log_skip "fnm $(fnm --version)"
    SKIPPED+=("fnm")
else
    log_install "fnm"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"
    log_ok "fnm установлен"
    INSTALLED+=("fnm")
fi

# Убедимся что fnm в PATH
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm &>/dev/null; then
    eval "$(fnm env)"
fi

# Node.js LTS
if command -v node &>/dev/null; then
    CURRENT_NODE=$(node --version)
    log_skip "Node.js $CURRENT_NODE"
    SKIPPED+=("node")
    # Проверяем обновления
    LATEST_LTS=$(fnm list-remote | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | tail -1)
    if [ "$CURRENT_NODE" != "$LATEST_LTS" ]; then
        echo -e "${YELLOW}→${NC} Доступно обновление: $LATEST_LTS"
    fi
else
    log_install "Node.js LTS"
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest
    log_ok "Node.js $(node --version) установлен"
    INSTALLED+=("node")
fi

# pnpm
if command -v pnpm &>/dev/null; then
    log_update "pnpm"
    CURRENT_PNPM=$(pnpm --version)
    npm install -g pnpm
    NEW_PNPM=$(pnpm --version)
    if [ "$CURRENT_PNPM" != "$NEW_PNPM" ]; then
        log_ok "pnpm обновлён: $CURRENT_PNPM → $NEW_PNPM"
        UPDATED+=("pnpm")
    else
        log_skip "pnpm $CURRENT_PNPM (актуальная версия)"
        SKIPPED+=("pnpm")
    fi
else
    log_install "pnpm"
    npm install -g pnpm
    log_ok "pnpm установлен"
    INSTALLED+=("pnpm")
fi

echo ""
# --- spec-kit ---
echo "--- spec-kit (проектирование) ---"
if command -v pnpm &>/dev/null; then
    check_and_install "spec-kit" "pnpm exec spec-kit --version 2>/dev/null || npx spec-kit --version 2>/dev/null" "pnpm add -g @anthropic/spec-kit"
else
    log_error "pnpm не установлен, пропускаю spec-kit"
    FAILED+=("spec-kit")
fi

echo ""
# --- Настройка shell ---
echo "--- Настройка shell ---"

SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

add_to_rc() {
    if ! grep -q "$1" "$SHELL_RC" 2>/dev/null; then
        echo "$1" >> "$SHELL_RC"
        echo "  Добавлено: $1"
    fi
}

echo "Добавляю алиасы и инициализацию в $SHELL_RC..."

add_to_rc 'alias ls="eza --icons"'
add_to_rc 'alias cat="bat"'
add_to_rc 'alias find="fd"'
add_to_rc 'alias grep="rg"'
add_to_rc 'eval "$(zoxide init bash)"'
add_to_rc 'eval "$(starship init bash)"'
add_to_rc 'export PATH="$HOME/.cargo/bin:$PATH"'
add_to_rc 'eval "$(fnm env)"'

log_ok "Shell настроен"

echo ""
echo "=========================================="
echo "   Результаты установки"
echo "=========================================="

# Сохраняем отчёт
REPORT_FILE="$HOME/.stack-installed.txt"
{
    echo "# Установленные инструменты"
    echo "# Дата: $(date)"
    echo ""
    echo "## Установлено:"
    for item in "${INSTALLED[@]}"; do echo "- $item"; done
    echo ""
    echo "## Обновлено:"
    for item in "${UPDATED[@]}"; do echo "- $item"; done
    echo ""
    echo "## Актуальные:"
    for item in "${SKIPPED[@]}"; do echo "- $item"; done
    echo ""
    echo "## Ошибки:"
    for item in "${FAILED[@]}"; do echo "- $item"; done
} > "$REPORT_FILE"

echo ""
echo -e "${GREEN}Установлено:${NC} ${#INSTALLED[@]}"
echo -e "${CYAN}Обновлено:${NC} ${#UPDATED[@]}"
echo -e "${YELLOW}Актуальные:${NC} ${#SKIPPED[@]}"
echo -e "${RED}Ошибок:${NC} ${#FAILED[@]}"
echo ""
echo "Отчёт сохранён: $REPORT_FILE"
echo ""
echo "Перезапусти терминал или выполни: source $SHELL_RC"
