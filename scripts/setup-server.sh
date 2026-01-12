#!/bin/bash
# Настройка Production VPS для проекта

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_install() { echo -e "${YELLOW}⬇${NC} $1..."; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Генерация случайного пароля
gen_password() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

# Генерируем пароли для всех сервисов
POSTGRES_PASSWORD=$(gen_password)
POSTGRES_USER="app"
POSTGRES_DB="app"
REDIS_PASSWORD=$(gen_password)
DIRECTUS_KEY=$(gen_password)
DIRECTUS_SECRET=$(gen_password)
DIRECTUS_ADMIN_EMAIL="admin@example.com"
DIRECTUS_ADMIN_PASSWORD=$(gen_password)

# --- Запрос данных ---
echo "=========================================="
echo "   Настройка Production VPS"
echo "=========================================="
echo ""

read -p "IP сервера: " SERVER_IP
read -p "Пользователь [root]: " SERVER_USER
SERVER_USER=${SERVER_USER:-root}
read -p "SSH порт [22]: " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-22}

echo ""
echo "Метод подключения:"
echo "  1) SSH-ключ (рекомендуется)"
echo "  2) Пароль"
read -p "Выбор [1]: " AUTH_METHOD
AUTH_METHOD=${AUTH_METHOD:-1}

if [ "$AUTH_METHOD" = "2" ]; then
    read -s -p "Пароль: " SERVER_PASSWORD
    echo ""

    # Проверяем наличие sshpass
    if ! command -v sshpass &>/dev/null; then
        log_info "Устанавливаю sshpass..."
        if command -v apt &>/dev/null; then
            sudo apt install -y sshpass
        elif command -v brew &>/dev/null; then
            brew install hudochenkov/sshpass/sshpass
        elif command -v nix-env &>/dev/null; then
            nix-env -iA nixpkgs.sshpass
        else
            log_error "Установи sshpass вручную или используй SSH-ключ"
            exit 1
        fi
    fi
fi

echo ""
log_info "Подключаюсь к $SERVER_USER@$SERVER_IP:$SERVER_PORT..."

# --- Функция выполнения на сервере ---
run_remote() {
    if [ "$AUTH_METHOD" = "2" ]; then
        sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP" "$1"
    else
        ssh -o StrictHostKeyChecking=no -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP" "$1"
    fi
}

# --- Проверка подключения ---
if ! run_remote "echo 'OK'" 2>/dev/null; then
    log_error "Не удалось подключиться. Проверь данные."
    exit 1
fi
log_ok "Подключение успешно"

# --- Обновление системы ---
echo ""
log_install "Обновление системы"
run_remote "apt update && apt upgrade -y"
log_ok "Система обновлена"

# --- Docker ---
echo ""
log_install "Установка Docker"
run_remote '
if command -v docker &>/dev/null; then
    echo "Docker уже установлен"
else
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi
'
log_ok "Docker установлен"

# --- Docker Compose ---
log_install "Проверка Docker Compose"
run_remote '
if docker compose version &>/dev/null; then
    echo "Docker Compose уже установлен"
else
    apt install -y docker-compose-plugin
fi
'
log_ok "Docker Compose готов"

# --- Создание структуры директорий ---
echo ""
log_install "Создание директорий"
run_remote 'mkdir -p /apps /data /backups'
log_ok "Директории созданы"

# --- Docker network ---
log_install "Создание Docker network"
run_remote 'docker network create backend 2>/dev/null || true'
log_ok "Network backend создана"

# === ПРОДАКШЕН VPS ===
echo ""
echo "--- Установка сервисов ---"

# PostgreSQL
log_install "Установка PostgreSQL"
run_remote "
mkdir -p /data/postgres
cat > /apps/postgres-compose.yml << 'EOFCOMPOSE'
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: $POSTGRES_USER
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_DB: $POSTGRES_DB
    volumes:
      - /data/postgres:/var/lib/postgresql/data
    ports:
      - '127.0.0.1:5432:5432'
    networks:
      - backend
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U $POSTGRES_USER']
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  backend:
    external: true
EOFCOMPOSE
cd /apps && docker compose -f postgres-compose.yml up -d
"
log_ok "PostgreSQL установлен"

# Redis
log_install "Установка Redis"
run_remote "
mkdir -p /data/redis
cat > /apps/redis-compose.yml << 'EOFCOMPOSE'
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --requirepass $REDIS_PASSWORD
    volumes:
      - /data/redis:/data
    ports:
      - '127.0.0.1:6379:6379'
    networks:
      - backend
    healthcheck:
      test: ['CMD', 'redis-cli', '-a', '$REDIS_PASSWORD', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  backend:
    external: true
EOFCOMPOSE
cd /apps && docker compose -f redis-compose.yml up -d
"
log_ok "Redis установлен"

# Caddy
log_install "Установка Caddy"
run_remote '
mkdir -p /data/caddy /apps/caddy
cat > /apps/caddy/Caddyfile << EOF
# Добавь домены здесь
# example.com {
#     reverse_proxy app:3000
# }
EOF
cat > /apps/caddy-compose.yml << EOF
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /apps/caddy/Caddyfile:/etc/caddy/Caddyfile
      - /data/caddy:/data
    networks:
      - backend

networks:
  backend:
    external: true
EOF
cd /apps && docker compose -f caddy-compose.yml up -d
'
log_ok "Caddy установлен"

# Garage (S3)
log_install "Установка Garage (S3)"
run_remote '
mkdir -p /data/garage
cat > /apps/garage-compose.yml << EOF
services:
  garage:
    image: dxflrs/garage:latest
    container_name: garage
    restart: unless-stopped
    volumes:
      - /data/garage:/var/lib/garage
    ports:
      - "3900:3900"
    networks:
      - backend

networks:
  backend:
    external: true
EOF
cd /apps && docker compose -f garage-compose.yml up -d
'
log_ok "Garage установлен (порт 3900)"

# Directus
log_install "Установка Directus"
run_remote "
cat > /apps/directus-compose.yml << 'EOFCOMPOSE'
services:
  directus:
    image: directus/directus:latest
    container_name: directus
    restart: unless-stopped
    environment:
      KEY: $DIRECTUS_KEY
      SECRET: $DIRECTUS_SECRET
      DB_CLIENT: pg
      DB_HOST: postgres
      DB_PORT: 5432
      DB_DATABASE: $POSTGRES_DB
      DB_USER: $POSTGRES_USER
      DB_PASSWORD: $POSTGRES_PASSWORD
      ADMIN_EMAIL: $DIRECTUS_ADMIN_EMAIL
      ADMIN_PASSWORD: $DIRECTUS_ADMIN_PASSWORD
    ports:
      - '8055:8055'
    networks:
      - backend
    depends_on:
      - postgres

networks:
  backend:
    external: true
EOFCOMPOSE
cd /apps && docker compose -f directus-compose.yml up -d
"
log_ok "Directus установлен (порт 8055)"

# --- Netdata ---
echo ""
log_install "Установка Netdata"
run_remote '
if [ ! -d "/opt/netdata" ]; then
    curl -sSL https://get.netdata.cloud/kickstart.sh | bash -s -- --dont-wait
fi
'
log_ok "Netdata установлен (порт 19999)"

# --- Vector ---
log_install "Установка Vector"
run_remote '
if ! command -v vector &>/dev/null; then
    curl -sSL https://sh.vector.dev | bash -s -- -y
fi
'
log_ok "Vector установлен"

# --- Итоги ---
echo ""
echo "=========================================="
echo "   Установка завершена!"
echo "=========================================="
echo ""

# Сохраняем данные доступа в Markdown
CREDENTIALS_FILE="$HOME/.server-$SERVER_IP.md"
{
    echo "# Сервер $SERVER_IP"
    echo ""
    echo "> Создано: $(date)"
    echo ""
    echo "## SSH доступ"
    echo ""
    echo "\`\`\`bash"
    echo "ssh -p $SERVER_PORT $SERVER_USER@$SERVER_IP"
    echo "\`\`\`"
    echo ""
    echo "| Параметр | Значение |"
    echo "|----------|----------|"
    echo "| IP | \`$SERVER_IP\` |"
    echo "| User | \`$SERVER_USER\` |"
    echo "| Port | \`$SERVER_PORT\` |"
    echo ""
    echo "---"
    echo ""
    echo "## PostgreSQL"
    echo ""
    echo "| Параметр | Значение |"
    echo "|----------|----------|"
    echo "| Host | \`$SERVER_IP\` (или \`postgres\` из Docker) |"
    echo "| Port | \`5432\` |"
    echo "| Database | \`$POSTGRES_DB\` |"
    echo "| User | \`$POSTGRES_USER\` |"
    echo "| Password | \`$POSTGRES_PASSWORD\` |"
    echo ""
    echo "\`\`\`bash"
    echo "# Connection string"
    echo "DATABASE_URL=\"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$SERVER_IP:5432/$POSTGRES_DB\""
    echo "\`\`\`"
    echo ""
    echo "---"
    echo ""
    echo "## Redis"
    echo ""
    echo "| Параметр | Значение |"
    echo "|----------|----------|"
    echo "| Host | \`$SERVER_IP\` (или \`redis\` из Docker) |"
    echo "| Port | \`6379\` |"
    echo "| Password | \`$REDIS_PASSWORD\` |"
    echo ""
    echo "\`\`\`bash"
    echo "# Connection string"
    echo "REDIS_URL=\"redis://:$REDIS_PASSWORD@$SERVER_IP:6379\""
    echo "\`\`\`"
    echo ""
    echo "---"
    echo ""
    echo "## Directus (CMS)"
    echo ""
    echo "| Параметр | Значение |"
    echo "|----------|----------|"
    echo "| URL | http://$SERVER_IP:8055 |"
    echo "| Admin Email | \`$DIRECTUS_ADMIN_EMAIL\` |"
    echo "| Admin Password | \`$DIRECTUS_ADMIN_PASSWORD\` |"
    echo ""
    echo "---"
    echo ""
    echo "## Garage (S3)"
    echo ""
    echo "| Параметр | Значение |"
    echo "|----------|----------|"
    echo "| URL | http://$SERVER_IP:3900 |"
    echo ""
    echo "> Требуется дополнительная настройка: \`garage status\`, \`garage layout\`"
    echo ""
    echo "---"
    echo ""
    echo "## Мониторинг"
    echo ""
    echo "| Сервис | URL |"
    echo "|--------|-----|"
    echo "| Netdata | http://$SERVER_IP:19999 |"
    echo ""
    echo "---"
    echo ""
    echo "## ENV для приложения"
    echo ""
    echo "\`\`\`bash"
    echo "# .env"
    echo "DATABASE_URL=\"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres:5432/$POSTGRES_DB\""
    echo "REDIS_URL=\"redis://:$REDIS_PASSWORD@redis:6379\""
    echo "DIRECTUS_URL=\"http://directus:8055\""
    echo "S3_ENDPOINT=\"http://garage:3900\""
    echo "\`\`\`"
} > "$CREDENTIALS_FILE"

# Также сохраняем .env файл
ENV_FILE="$HOME/.env-$SERVER_IP"
{
    echo "# Server: $SERVER_IP"
    echo "# Generated: $(date)"
    echo ""
    echo "# PostgreSQL"
    echo "DATABASE_URL=\"postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$SERVER_IP:5432/$POSTGRES_DB\""
    echo "POSTGRES_USER=\"$POSTGRES_USER\""
    echo "POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\""
    echo "POSTGRES_DB=\"$POSTGRES_DB\""
    echo ""
    echo "# Redis"
    echo "REDIS_URL=\"redis://:$REDIS_PASSWORD@$SERVER_IP:6379\""
    echo "REDIS_PASSWORD=\"$REDIS_PASSWORD\""
    echo ""
    echo "# Directus"
    echo "DIRECTUS_URL=\"http://$SERVER_IP:8055\""
    echo "DIRECTUS_KEY=\"$DIRECTUS_KEY\""
    echo "DIRECTUS_SECRET=\"$DIRECTUS_SECRET\""
    echo "DIRECTUS_ADMIN_EMAIL=\"$DIRECTUS_ADMIN_EMAIL\""
    echo "DIRECTUS_ADMIN_PASSWORD=\"$DIRECTUS_ADMIN_PASSWORD\""
    echo ""
    echo "# S3 (Garage)"
    echo "S3_ENDPOINT=\"http://$SERVER_IP:3900\""
} > "$ENV_FILE"

echo -e "${GREEN}Документация сохранена:${NC}"
echo "  📄 $CREDENTIALS_FILE"
echo "  🔐 $ENV_FILE"
echo ""
echo -e "${CYAN}Сервисы:${NC}"
echo "  Directus: http://$SERVER_IP:8055"
echo "  Garage:   http://$SERVER_IP:3900"
echo "  Netdata:  http://$SERVER_IP:19999"
echo ""
echo -e "${GREEN}Логин в Directus:${NC}"
echo "  Email:    $DIRECTUS_ADMIN_EMAIL"
echo "  Password: $DIRECTUS_ADMIN_PASSWORD"
