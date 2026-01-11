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
log_info "Подключаюсь к $SERVER_USER@$SERVER_IP:$SERVER_PORT..."

# --- Функция выполнения на сервере ---
run_remote() {
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP" "$1"
}

# --- Проверка подключения ---
if ! run_remote "echo 'OK'" &>/dev/null; then
    log_error "Не удалось подключиться. Проверь SSH-ключ."
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
run_remote '
mkdir -p /data/postgres
cat > /apps/postgres-compose.yml << EOF
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: app
    volumes:
      - /data/postgres:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  backend:
    external: true
EOF
cd /apps && docker compose -f postgres-compose.yml up -d
'
log_ok "PostgreSQL установлен"

# Redis
log_install "Установка Redis"
run_remote '
mkdir -p /data/redis
cat > /apps/redis-compose.yml << EOF
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    volumes:
      - /data/redis:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  backend:
    external: true
EOF
cd /apps && docker compose -f redis-compose.yml up -d
'
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
run_remote '
cat > /apps/directus-compose.yml << EOF
services:
  directus:
    image: directus/directus:latest
    container_name: directus
    restart: unless-stopped
    environment:
      KEY: ${DIRECTUS_KEY:-random-key-change-me}
      SECRET: ${DIRECTUS_SECRET:-random-secret-change-me}
      DB_CLIENT: pg
      DB_HOST: postgres
      DB_PORT: 5432
      DB_DATABASE: app
      DB_USER: app
      DB_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      ADMIN_EMAIL: admin@example.com
      ADMIN_PASSWORD: ${DIRECTUS_ADMIN_PASSWORD:-changeme}
    ports:
      - "8055:8055"
    networks:
      - backend
    depends_on:
      - postgres

networks:
  backend:
    external: true
EOF
cd /apps && docker compose -f directus-compose.yml up -d
'
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

# Сохраняем данные доступа
CREDENTIALS_FILE="$HOME/.server-credentials-$SERVER_IP.txt"
{
    echo "# Доступы к серверу $SERVER_IP"
    echo "# Дата: $(date)"
    echo ""
    echo "SERVER_IP=$SERVER_IP"
    echo "SERVER_USER=$SERVER_USER"
    echo "SERVER_PORT=$SERVER_PORT"
    echo ""
    echo "POSTGRES_URL=postgres://app:changeme@$SERVER_IP:5432/app"
    echo "REDIS_URL=redis://$SERVER_IP:6379"
    echo "DIRECTUS_URL=http://$SERVER_IP:8055"
    echo "GARAGE_URL=http://$SERVER_IP:3900"
    echo "NETDATA_URL=http://$SERVER_IP:19999"
} > "$CREDENTIALS_FILE"

echo "Доступы сохранены: $CREDENTIALS_FILE"
echo ""
echo "Directus: http://$SERVER_IP:8055"
echo "Garage:   http://$SERVER_IP:3900"
echo "Netdata:  http://$SERVER_IP:19999"
echo ""
echo -e "${YELLOW}⚠${NC}  Не забудь сменить пароли в compose-файлах!"
