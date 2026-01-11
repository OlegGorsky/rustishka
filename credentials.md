# Gorsky Infrastructure Credentials

## Server Access

| | |
|---|---|
| **IP** | `89.40.233.138` |
| **SSH** | `ssh root@gorsky-club.ru` |
| **SSH (пароль)** | `98SutVp9&Ym*` |

---

## Git (Forgejo)

| | |
|---|---|
| **URL** | https://gorsky-club.ru |
| **Логин** | `gorsky` |
| **Пароль** | `Gorsky2024` |
| **Email** | `my@gorskymail.ru` |

### Git SSH:
```bash
git clone ssh://git@gorsky-club.ru:2222/gorsky/repo.git
```

### Docker Registry:
```bash
docker login gorsky-club.ru
# логин: gorsky
# пароль: Gorsky2024
```

---

## Backup (Rustic/Restic)

| | |
|---|---|
| **URL** | `https://backup.gorsky-club.ru` |
| **Логин** | `backup` |
| **Пароль** | `BackupSecure2024!` |

### Подключение с production серверов:
```bash
export RUSTIC_REPOSITORY="rest:https://backup:BackupSecure2024!@backup.gorsky-club.ru/projectname"
export RUSTIC_PASSWORD="your-encryption-password"

# Инициализация (один раз)
rustic init

# Бэкап
rustic backup /data
```

---

## Monitoring (Netdata)

| | |
|---|---|
| **URL** | https://monitor.gorsky-club.ru |
| **Логин** | `gorsky` |
| **Пароль** | `Gorsky2024` |

---

## Logs (Vector)

Логи собираются со всех Docker контейнеров и сохраняются в:
```
/opt/forgejo/logs/YYYY-MM-DD.log
```

Формат: JSON (container_name, message, timestamp)

Просмотр логов:
```bash
# Все логи за сегодня
cat /opt/forgejo/logs/$(date +%Y-%m-%d).log | jq .

# Логи конкретного контейнера
cat /opt/forgejo/logs/$(date +%Y-%m-%d).log | jq 'select(.container_name == "forgejo")'

# Последние 50 записей
tail -50 /opt/forgejo/logs/$(date +%Y-%m-%d).log | jq .
```

---

## PostgreSQL (Forgejo DB)

| | |
|---|---|
| **Host** | `localhost` (внутри docker: `postgres`) |
| **Database** | `forgejo` |
| **User** | `forgejo` |
| **Password** | `forgejo_secret_2024` |

---

## SSH Keys

### Публичный ключ (добавлен на сервер):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEFIKpcKkFLtfbeUr1cGJ+hQeRgdrbqmpCrgnNx+Hj5 oleg@nixos-dev
```

---

## API Tokens

### Forgejo API:
```
e999a86a8cd4f165293cae99bfb8a605e13ba7c5
```

---

## Файлы на сервере

```
/opt/forgejo/
├── docker-compose.yml
├── Caddyfile
├── vector.yaml        # Конфигурация Vector
├── data/              # Forgejo данные
├── postgres-data/     # PostgreSQL
├── backups/           # Restic репозитории
├── logs/              # Vector логи (по дням)
├── caddy-data/        # SSL сертификаты
├── netdata-config/    # Netdata конфигурация
├── netdata-lib/       # Netdata данные
├── netdata-cache/     # Netdata кэш
├── restic-htpasswd    # Авторизация бэкапов
└── netdata-htpasswd   # Авторизация мониторинга
```
