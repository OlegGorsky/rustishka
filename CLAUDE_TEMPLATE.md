# Project: [NAME]
## Тип: [web|bot|parser|miniapp|ai-assistant|api-server]

## Стек по типу

**Web/Miniapp/API:** Axum, Leptos, PostgreSQL+SQLx, Redis+fred, Garage, Directus
**Bot:** teloxide, PostgreSQL+SQLx, Redis+fred
**Parser:** reqwest, scraper, PostgreSQL+SQLx
**AI-assistant:** Axum, async-openai, openrouter-rs, PostgreSQL+SQLx, Redis+fred

## Общий стек (НЕ МЕНЯТЬ)

Rust, Tokio, serde, schemars, utoipa, sqlx-cli, just, spec-kit, Beads, pass, Netdata, Vector+tracing

**Безопасность:** tower-governor, tower-http, validator, jsonwebtoken
**Ошибки:** thiserror, color-eyre

## CLI-инструменты (использовать вместо стандартных)

| Вместо | Использовать |
|--------|--------------|
| ls | eza |
| cat | bat |
| find | fd |
| grep | rg (ripgrep) |
| cd | zoxide (z) |
| du | dust |
| top | btop |
| diff | delta |

**Данные:** jq (JSON), yq (YAML), xsv (CSV)
**Git:** gitui

## Cargo-расширения

bacon, cargo-nextest, cargo-audit, cargo-tarpaulin, cargo-watch, cargo-edit, cargo-outdated, tokio-console

## Инфраструктура

**Git + Registry:** Forgejo (self-hosted)
**Reverse Proxy:** Caddy (auto HTTPS)
**Контейнеры:** Docker + Docker Compose
**Бэкапы:** Rustic
**Мониторинг:** Netdata
**Логи:** Vector

## Деплой

```bash
just ci && just deploy   # Сборка + деплой
./deploy.sh [project] rollback [tag]  # Откат
```

**Процесс deploy:** docker build → push в Forgejo Registry → ssh: docker pull + up -d → проверка /health

## Dockerfile (шаблон)

```dockerfile
FROM rust:1.75 AS builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/app /usr/local/bin/
CMD ["app"]
```

## docker-compose.yml (шаблон)

```yaml
services:
  app:
    image: forgejo.example.com/user/app:latest
    restart: unless-stopped
    env_file: .env
    networks: [backend]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
networks:
  backend:
    external: true
```

## Настройка VPS

```bash
./setup-vps.sh user@IP   # Docker, директории, сети
./up-infra.sh            # PostgreSQL, Redis, Garage, Caddy, Directus, Netdata, Vector
```

## Контекст (ЧИТАЙ ПЕРЕД РАБОТОЙ)

- `docs/schema.sql` — БД
- `docs/openapi.json` — API
- `docs/models.json` — модели
- `.sqlx/` — SQL запросы
- `.beads/` — задачи

## Команды

```bash
just ci            # fmt, clippy-strict, audit, test, build
just watch         # clippy при сохранении
just migrate       # миграции + контекст
just gen-context   # обновить docs/
just deploy        # деплой
```

## Beads

```bash
bd list / bd ready / bd add "задача" / bd done <id> / bd show <id> / bd edit <id> / bd rm <id> / bd dep add <a> <b>
```

## spec-kit

```bash
/speckit.constitution → /speckit.specify → /speckit.plan → /speckit.tasks → /speckit.implement
```

## Правила кода

- Ошибки: `Result` + `?`, без `unwrap()`
- Ошибки: `thiserror`
- Тесты для новых функций
- Документация: `///`

## Правила async

- `Clone` вместо ссылок
- State в БД/Redis, не в памяти
- Shared state: `Arc<RwLock<T>>`
- Каналы: `tokio::sync::mpsc`

## Redis vs PostgreSQL

**Redis:** сессии, кэш, очереди, rate limiting
**PostgreSQL:** бизнес-данные, история, отношения, поиск

## Git

```bash
git commit -m "feat|fix|refactor|docs|chore: описание"
```

## Структура src/

**Web/API:** main.rs, routes/, models/, db/, services/
**Bot:** main.rs, handlers/, keyboards/, states/, db/, services/
**Parser:** main.rs, spiders/, models/, db/, utils/
**AI:** main.rs, routes/, llm/, prompts/, memory/, db/, services/

## ENV

```
DATABASE_URL, REDIS_URL, S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY
TELEGRAM_BOT_TOKEN, OPENAI_API_KEY, ANTHROPIC_API_KEY
```
