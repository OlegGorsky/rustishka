#!/bin/bash
# Установка локальных инструментов (кроссплатформенный)
# v2: с интеллектуальным поиском пакетов

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_skip() { echo -e "${YELLOW}→${NC} $1 (уже установлен)"; }
log_install() { echo -e "${YELLOW}⬇${NC} Устанавливаю $1..."; }
log_update() { echo -e "${CYAN}↑${NC} Обновляю $1..."; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_search() { echo -e "${CYAN}🔍${NC} Ищу альтернативу для $1..."; }

INSTALLED=()
SKIPPED=()
UPDATED=()
FAILED=()

# Файл кэша найденных маппингов
CACHE_FILE="$HOME/.nix-pkg-cache.txt"

echo "=========================================="
echo "   Установка локального окружения v2"
echo "=========================================="
echo ""

# --- Определение ОС и пакетного менеджера ---
detect_os() {
    if [ -f /etc/NIXOS ] || [ -d /nix ]; then
        OS="nixos"
        PKG_MGR="nix"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        PKG_MGR="brew"
    elif command -v apt &>/dev/null; then
        OS="debian"
        PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
        OS="fedora"
        PKG_MGR="dnf"
    elif command -v pacman &>/dev/null; then
        OS="arch"
        PKG_MGR="pacman"
    else
        OS="unknown"
        PKG_MGR="unknown"
    fi
}

detect_os
echo "ОС: $OS, Пакетный менеджер: $PKG_MGR"
echo ""

# ===========================================
# NixOS: интеллектуальная установка
# ===========================================
if [ "$PKG_MGR" = "nix" ]; then
    echo "--- NixOS: установка через nix profile ---"
    echo ""

    # Проверить кэш на наличие маппинга
    get_cached_name() {
        local pkg="$1"
        if [ -f "$CACHE_FILE" ]; then
            grep "^$pkg=" "$CACHE_FILE" 2>/dev/null | cut -d'=' -f2
        fi
    }

    # Сохранить маппинг в кэш
    save_to_cache() {
        local original="$1"
        local actual="$2"
        # Удалить старую запись если есть
        if [ -f "$CACHE_FILE" ]; then
            grep -v "^$original=" "$CACHE_FILE" > "$CACHE_FILE.tmp" 2>/dev/null || true
            mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        fi
        echo "$original=$actual" >> "$CACHE_FILE"
    }

    # Поиск пакета в nixpkgs (только ТОЧНОЕ совпадение)
    find_nix_package() {
        local pkg="$1"

        local results=$(nix search nixpkgs "$pkg" --json 2>/dev/null)

        if [ -z "$results" ] || [ "$results" = "{}" ]; then
            return 1
        fi

        # Ищем ТОЛЬКО точное совпадение имени пакета
        local found=$(echo "$results" | jq -r --arg pkg "$pkg" '
            to_entries |
            map(select(.key | split(".") | last | ascii_downcase == ($pkg | ascii_downcase))) |
            .[0].key // empty
        ' | sed 's/legacyPackages\.x86_64-linux\.//')

        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi

        # Если точного совпадения нет — не угадываем, возвращаем ошибку
        return 1
    }

    # Умная установка пакета
    smart_nix_install() {
        local pkg="$1"
        local bin_name="${2:-$pkg}"  # имя бинарника для проверки

        # Проверяем, установлен ли уже
        if command -v "$bin_name" &>/dev/null; then
            log_skip "$pkg (бинарник $bin_name найден)"
            SKIPPED+=("$pkg")
            return 0
        fi

        # Проверяем в nix profile (точное совпадение имени пакета)
        # Убираем ANSI коды и ищем точное имя
        if nix profile list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "^Name:\s+${pkg}$"; then
            log_skip "$pkg (в nix profile)"
            SKIPPED+=("$pkg")
            return 0
        fi

        # Проверяем кэш
        local cached=$(get_cached_name "$pkg")
        if [ -n "$cached" ] && [ "$cached" != "$pkg" ]; then
            log_info "Использую кэшированное имя: $pkg → $cached"
            pkg="$cached"
        fi

        log_install "$pkg"

        # Пробуем установить напрямую
        if nix profile install "nixpkgs#$pkg" 2>/dev/null; then
            log_ok "$pkg установлен"
            INSTALLED+=("$pkg")
            return 0
        fi

        # Не удалось — ищем альтернативу
        log_search "$pkg"
        local found=$(find_nix_package "$pkg")

        if [ -n "$found" ] && [ "$found" != "$pkg" ]; then
            log_info "Найдена альтернатива: $pkg → $found"
            if nix profile install "nixpkgs#$found" 2>/dev/null; then
                log_ok "$found установлен (вместо $pkg)"
                save_to_cache "$pkg" "$found"
                INSTALLED+=("$found")
                return 0
            fi
        fi

        # Последний шанс — cargo install
        log_info "Пробую установить через cargo..."
        # Маппинг имён пакетов для cargo
        local cargo_name="$pkg"
        case "$pkg" in
            fd) cargo_name="fd-find" ;;
            dust) cargo_name="du-dust" ;;
            delta) cargo_name="git-delta" ;;
            watchexec) cargo_name="watchexec-cli" ;;
        esac

        # На NixOS нужен nix-shell с компилятором
        if [ "$OS" = "nixos" ]; then
            if nix-shell -p gcc pkg-config openssl --run "cargo install $cargo_name" 2>/dev/null; then
                log_ok "$pkg установлен через cargo (nix-shell)"
                INSTALLED+=("$pkg (cargo)")
                return 0
            fi
        elif command -v cargo &>/dev/null; then
            if cargo install "$cargo_name" 2>/dev/null; then
                log_ok "$pkg установлен через cargo"
                INSTALLED+=("$pkg (cargo)")
                return 0
            fi
        fi

        log_error "Не удалось установить $pkg"
        FAILED+=("$pkg")
        return 1
    }

    # Список пакетов: название -> бинарник (если отличается)
    declare -A NIX_PACKAGES=(
        # CLI замены
        ["eza"]="eza"
        ["bat"]="bat"
        ["fd"]="fd"
        ["ripgrep"]="rg"
        ["zoxide"]="zoxide"
        ["dust"]="dust"
        ["delta"]="delta"
        ["btop"]="btop"
        # Для разработки
        ["tokei"]="tokei"
        ["hyperfine"]="hyperfine"
        ["gitui"]="gitui"
        ["starship"]="starship"
        ["just"]="just"
        ["watchexec"]="watchexec"
        # Для данных
        ["jq"]="jq"
        ["yq"]="yq"
        ["xsv"]="xsv"
        # Cargo расширения
        ["cargo-audit"]="cargo-audit"
        ["cargo-watch"]="cargo-watch"
        ["cargo-nextest"]="cargo-nextest"
        ["cargo-tarpaulin"]="cargo-tarpaulin"
        ["cargo-edit"]="cargo"
        ["cargo-outdated"]="cargo-outdated"
        ["bacon"]="bacon"
        ["sqlx-cli"]="sqlx"
        ["tokio-console"]="tokio-console"
        # Бэкапы
        ["rustic"]="rustic"
        # Node.js
        ["fnm"]="fnm"
        # Секреты
        ["pass"]="pass"
        ["gnupg"]="gpg"
    )

    for pkg in "${!NIX_PACKAGES[@]}"; do
        bin_name="${NIX_PACKAGES[$pkg]}"
        smart_nix_install "$pkg" "$bin_name"
    done

    echo ""
    echo "--- Node.js (fnm + pnpm) ---"

    # fnm уже должен быть установлен через nix
    if command -v fnm &>/dev/null; then
        eval "$(fnm env)"

        # Node.js
        if ! command -v node &>/dev/null; then
            log_install "Node.js LTS"
            fnm install --lts
            fnm default lts-latest
            log_ok "Node.js установлен"
            INSTALLED+=("node")
        else
            log_skip "Node.js $(node --version)"
            SKIPPED+=("node")
        fi

        # pnpm
        if ! command -v pnpm &>/dev/null; then
            log_install "pnpm"
            npm install -g pnpm
            log_ok "pnpm установлен"
            INSTALLED+=("pnpm")
        else
            log_skip "pnpm"
            SKIPPED+=("pnpm")
        fi
    fi

    echo ""
    echo "--- AI инструменты ---"

    # Beads
    if ! command -v bd &>/dev/null; then
        log_install "beads"
        if command -v cargo &>/dev/null; then
            if cargo install beads 2>/dev/null; then
                log_ok "beads установлен"
                INSTALLED+=("beads")
            else
                log_error "Не удалось установить beads"
                FAILED+=("beads")
            fi
        else
            log_info "cargo не найден, пропускаю beads"
            FAILED+=("beads")
        fi
    else
        log_skip "beads"
        SKIPPED+=("beads")
    fi

    # Specify CLI (spec-driven development)
    if ! command -v specify &>/dev/null; then
        log_install "specify-cli"
        if command -v uv &>/dev/null; then
            uv tool install specify-cli --from git+https://github.com/github/spec-kit.git 2>/dev/null && log_ok "specify-cli установлен" && INSTALLED+=("specify-cli") || FAILED+=("specify-cli")
        elif command -v pipx &>/dev/null; then
            pipx install git+https://github.com/github/spec-kit.git 2>/dev/null && log_ok "specify-cli установлен" && INSTALLED+=("specify-cli") || FAILED+=("specify-cli")
        else
            log_info "Нужен uv или pipx для specify-cli"
            FAILED+=("specify-cli")
        fi
    else
        log_skip "specify-cli"
        SKIPPED+=("specify-cli")
    fi

# ===========================================
# Другие ОС: стандартная логика
# ===========================================
else
    # --- Функции для других ОС ---
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

    pkg_install() {
        local pkg=$1
        local pkg_macos=${2:-$1}

        case $PKG_MGR in
            brew) brew install "$pkg_macos" ;;
            apt) sudo apt install -y "$pkg" ;;
            dnf) sudo dnf install -y "$pkg" ;;
            pacman) sudo pacman -S --noconfirm "$pkg" ;;
        esac
    }

    # --- Системные зависимости ---
    echo "--- Системные пакеты ---"

    case $PKG_MGR in
        brew) brew update ;;
        apt) sudo apt update -qq ;;
        dnf) sudo dnf check-update -q || true ;;
        pacman) sudo pacman -Sy ;;
    esac

    check_and_install "curl" "command -v curl" "pkg_install curl"
    check_and_install "git" "command -v git" "pkg_install git"
    check_and_install "jq" "command -v jq" "pkg_install jq"

    # Dev tools
    case $PKG_MGR in
        brew)
            if ! xcode-select -p &>/dev/null; then
                log_install "Xcode CLI tools"
                xcode-select --install
                INSTALLED+=("xcode-cli")
            else
                log_skip "Xcode CLI tools"
                SKIPPED+=("xcode-cli")
            fi
            ;;
        apt)
            check_and_install "build-essential" "dpkg -s build-essential" "sudo apt install -y build-essential"
            check_and_install "libssl-dev" "dpkg -s libssl-dev" "sudo apt install -y libssl-dev"
            check_and_install "pkg-config" "command -v pkg-config" "sudo apt install -y pkg-config"
            ;;
        dnf)
            check_and_install "gcc" "command -v gcc" "sudo dnf groupinstall -y 'Development Tools'"
            check_and_install "openssl-devel" "rpm -q openssl-devel" "sudo dnf install -y openssl-devel"
            ;;
        pacman)
            check_and_install "base-devel" "pacman -Q base-devel" "sudo pacman -S --noconfirm base-devel"
            check_and_install "openssl" "pacman -Q openssl" "sudo pacman -S --noconfirm openssl"
            ;;
    esac

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
    cargo_install_or_update "rustic-rs" "rustic"

    echo ""
    # --- Системные (btop, yq) ---
    echo "--- Системные утилиты ---"
    check_and_install "btop" "command -v btop" "pkg_install btop"
    check_and_install "yq" "command -v yq" "pkg_install yq"

    echo ""
    # --- Cargo расширения ---
    echo "--- Cargo расширения ---"

    cargo_install_or_update "cargo-audit" "cargo-audit"
    cargo_install_or_update "cargo-watch" "cargo-watch"
    cargo_install_or_update "cargo-nextest" "cargo-nextest"
    cargo_install_or_update "cargo-tarpaulin" "cargo-tarpaulin"
    cargo_install_or_update "cargo-edit" "cargo-add"
    cargo_install_or_update "cargo-outdated" "cargo-outdated"
    cargo_install_or_update "tokio-console" "tokio-console"
    cargo_install_or_update "bacon" "bacon"
    cargo_install_or_update "sqlx-cli" "sqlx"

    echo ""
    # --- AI инструменты ---
    echo "--- AI инструменты ---"
    cargo_install_or_update "beads" "bd"

    # Specify CLI (spec-driven development)
    if ! command -v specify &>/dev/null; then
        log_install "specify-cli"
        if command -v uv &>/dev/null; then
            uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
        elif command -v pipx &>/dev/null; then
            pipx install git+https://github.com/github/spec-kit.git
        elif command -v pip &>/dev/null; then
            pip install --user git+https://github.com/github/spec-kit.git
        else
            log_error "Нужен uv, pipx или pip для установки specify-cli"
            FAILED+=("specify-cli")
        fi
        if command -v specify &>/dev/null; then
            log_ok "specify-cli установлен"
            INSTALLED+=("specify-cli")
        fi
    else
        log_skip "specify-cli"
        SKIPPED+=("specify-cli")
    fi

    echo ""
    # --- fnm + Node.js + pnpm ---
    echo "--- Node.js (fnm + pnpm) ---"

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

    export PATH="$HOME/.local/share/fnm:$PATH"
    if command -v fnm &>/dev/null; then
        eval "$(fnm env)"
    fi

    if command -v node &>/dev/null; then
        log_skip "Node.js $(node --version)"
        SKIPPED+=("node")
    else
        log_install "Node.js LTS"
        fnm install --lts
        fnm default lts-latest
        fnm use lts-latest
        log_ok "Node.js $(node --version) установлен"
        INSTALLED+=("node")
    fi

    if command -v pnpm &>/dev/null; then
        log_skip "pnpm $(pnpm --version)"
        SKIPPED+=("pnpm")
    else
        log_install "pnpm"
        npm install -g pnpm
        log_ok "pnpm установлен"
        INSTALLED+=("pnpm")
    fi
fi

# ===========================================
# Общая часть для всех ОС
# ===========================================

echo ""
# --- Настройка shell ---
echo "--- Настройка shell ---"

CURRENT_SHELL=$(basename "$SHELL")
case $CURRENT_SHELL in
    zsh)
        SHELL_RC="$HOME/.zshrc"
        SHELL_NAME="zsh"
        ;;
    fish)
        SHELL_RC="$HOME/.config/fish/config.fish"
        SHELL_NAME="fish"
        mkdir -p "$HOME/.config/fish"
        ;;
    *)
        SHELL_RC="$HOME/.bashrc"
        SHELL_NAME="bash"
        ;;
esac

add_to_rc() {
    if ! grep -q "$1" "$SHELL_RC" 2>/dev/null; then
        echo "$1" >> "$SHELL_RC"
        echo "  Добавлено: $1"
    fi
}

echo "Shell: $SHELL_NAME, конфиг: $SHELL_RC"

if [ "$SHELL_NAME" = "fish" ]; then
    add_to_rc 'alias ls="eza --icons"'
    add_to_rc 'alias cat="bat"'
    add_to_rc 'alias find="fd"'
    add_to_rc 'alias grep="rg"'
    add_to_rc 'zoxide init fish | source'
    add_to_rc 'starship init fish | source'
    add_to_rc 'set -gx PATH $HOME/.cargo/bin $PATH'
    add_to_rc 'fnm env | source'
else
    add_to_rc 'alias ls="eza --icons"'
    add_to_rc 'alias cat="bat"'
    add_to_rc 'alias find="fd"'
    add_to_rc 'alias grep="rg"'
    add_to_rc 'eval "$(zoxide init '"$SHELL_NAME"')"'
    add_to_rc 'eval "$(starship init '"$SHELL_NAME"')"'
    add_to_rc 'export PATH="$HOME/.cargo/bin:$PATH"'
    add_to_rc 'eval "$(fnm env)"'
fi

log_ok "Shell настроен"

echo ""
echo "=========================================="
echo "   Результаты установки"
echo "=========================================="

REPORT_FILE="$HOME/.stack-installed.txt"
{
    echo "# Установленные инструменты"
    echo "# Дата: $(date)"
    echo "# ОС: $OS"
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
if [ -f "$CACHE_FILE" ]; then
    echo "Кэш маппингов: $CACHE_FILE"
fi
echo ""
echo "Перезапусти терминал или выполни: source $SHELL_RC"
