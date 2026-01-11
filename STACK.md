# Стек разработки

## Базовые инструменты

| Компонент | Инструмент |
|-----------|------------|
| Язык | Rust |
| Async runtime | Tokio |
| Пакетный менеджер | Cargo |
| Версия Rust | rustup |

## CLI-инструменты

### Замены стандартных команд

| Старое | Новое | Что даёт |
|--------|-------|----------|
| `ls` | eza | Цвета, иконки, git-статус |
| `cat` | bat | Подсветка синтаксиса |
| `find` | fd | Проще синтаксис, быстрее |
| `grep` | ripgrep (rg) | В разы быстрее |
| `cd` | zoxide | Умный переход (помнит историю) |
| `du` | dust | Визуализация размера папок |
| `top` | btop | Красивый мониторинг |
| `diff` | delta | Красивые диффы для git |

### Для разработки

| Инструмент | Что делает |
|------------|------------|
| tokei | Статистика кода (строки, языки) |
| hyperfine | Бенчмарки CLI команд |
| watchexec | Перезапуск при изменении файлов |
| gitui | TUI для git (Rust) |
| starship | Красивый промпт терминала |

### Для работы с данными

| Инструмент | Что делает |
|------------|------------|
| jq | Работа с JSON |
| yq | Работа с YAML |
| xsv | Работа с CSV |

### Установка

```bash
# Rust CLI
cargo install eza bat fd-find ripgrep zoxide dust tokei hyperfine watchexec-cli gitui starship delta xsv

# Системные
sudo apt install btop jq yq

# Алиасы в .bashrc/.zshrc
alias ls="eza --icons"
alias cat="bat"
alias find="fd"
alias grep="rg"
eval "$(zoxide init bash)"  # или zsh
eval "$(starship init bash)"  # или zsh
```

### Cargo-расширения

```bash
cargo install cargo-audit      # Аудит безопасности
cargo install cargo-tarpaulin  # Покрытие тестами
cargo install cargo-watch      # Авто-перезапуск
cargo install cargo-edit       # cargo add/rm/upgrade
cargo install cargo-outdated   # Проверка обновлений
cargo install sqlx-cli         # Миграции БД
cargo install bacon            # Watch-режим (clippy/test при сохранении)
cargo install cargo-nextest    # Быстрые тесты
cargo install tokio-console    # Дебаг async задач
```

---

## Языки и фреймворки

| Компонент | Инструмент |
|-----------|------------|
| Язык | Rust |
| Веб-бэкенд | Axum |
| Фронтенд | Leptos |
| Telegram-боты | teloxide |
| Парсеры | reqwest + scraper |
| OpenAI API | async-openai |
| OpenRouter API | openrouter-rs |

## Безопасность

| Компонент | Инструмент |
|-----------|------------|
| Rate limiting | tower-governor |
| CORS | tower-http |
| Валидация данных | validator |
| JWT авторизация | jsonwebtoken |

## Обработка ошибок

| Компонент | Инструмент |
|-----------|------------|
| Типизированные ошибки | thiserror |
| Читаемые stack traces | color-eyre |

## Производительность

| Компонент | Инструмент |
|-----------|------------|
| Сериализация | serde |
| Быстрый JSON | simd-json (опционально) |

## База данных и хранилище

| Компонент | Инструмент |
|-----------|------------|
| БД | PostgreSQL |
| ORM/Запросы | SQLx |
| Миграции | sqlx-cli |
| Кэш | Redis |
| Redis клиент | fred (Rust, async, pool) |
| Object Storage | Garage (S3-совместимый, Rust) |

## Инфраструктура

| Компонент | Инструмент |
|-----------|------------|
| Git + Registry | Forgejo |
| Reverse Proxy | Caddy (auto HTTPS) |
| CMS/Админка | Directus |
| Контейнеризация | Docker + Docker Compose |
| Секреты | pass + GPG + Git |

## Разработка и CI/CD

| Компонент | Инструмент |
|-----------|------------|
| Проектирование | spec-kit |
| Таск-раннер | just |
| API-документация | utoipa (OpenAPI) |
| Схемы моделей | schemars (JSON Schema) |
| Память AI / Задачи | Beads |
| AI-конфиг | CLAUDE.md |

## Мониторинг и логирование

| Компонент | Инструмент |
|-----------|------------|
| Мониторинг сервера | Netdata |
| Сбор логов | Vector (Rust) |
| Логирование в приложении | tracing + tracing-subscriber |
| Бэкапы | Rustic (Rust) |

---

## Автогенерация контекста

| Что | Инструмент | Файл |
|-----|------------|------|
| Структура БД | pg_dump | `docs/schema.sql` |
| API эндпоинты | utoipa | `docs/openapi.json` |
| Rust модели | schemars | `docs/models.json` |
| SQL запросы | SQLx | `.sqlx/` |
| Задачи AI | Beads | `.beads/` |

---

## Структура проекта

```
project/
├── CLAUDE.md              # Контекст для AI
├── justfile               # Таски
├── Cargo.toml
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── .beads/                # Beads задачи
├── .sqlx/                 # SQLx метаданные
├── migrations/            # Миграции БД
├── docs/
│   ├── schema.sql         # Структура БД
│   ├── openapi.json       # API эндпоинты
│   └── models.json        # Rust модели
└── src/
    ├── main.rs
    ├── routes/            # API хендлеры
    ├── models/            # Структуры данных
    ├── db/                # Запросы к БД
    └── services/          # Бизнес-логика
```

---

## Инфраструктура

### Локально (твой ПК)

```
Локально
├── pass + GPG (секреты)
├── Claude Code / OpenCode
├── Cargo, Rust, CLI-инструменты
└── just (сборка, деплой)
```

### Git-сервер (отдельный VPS)

```
Git-сервер (~$5-10/мес, 2-4GB RAM, 100GB+ SSD)
├── Forgejo (git + docker registry)
├── Все репозитории всех проектов
├── Все Docker-образы
├── secrets.git (зашифрованные GPG)
└── Rustic (бэкапы всех проектов)
    ├── project-1/ (БД, uploads)
    ├── project-2/
    └── ...
```

### Продакшен VPS (на каждый проект/группу проектов)

```
VPS проекта
├── Caddy (reverse proxy, HTTPS)
├── PostgreSQL
├── Redis
├── Garage (S3 storage)
├── Directus (админка)
├── Netdata (мониторинг)
├── Vector (сбор логов)
└── Приложения (контейнеры)
```

### Схема взаимодействия

```
Твой ПК                    Git-сервер                 VPS проекта
├── код                    ├── Forgejo                ├── docker pull
├── pass (секреты)   ───►  ├── Registry         ───►  ├── приложение
└── just deploy            └── все репозитории        └── БД, кэш
```

---

## justfile (таски)

```just
# CI/CD
ci: fmt clippy-strict audit test build

fmt:
    cargo fmt --check

clippy:
    cargo clippy -- -D warnings

clippy-strict:
    cargo clippy -- -D warnings \
        -D clippy::unwrap_used \
        -D clippy::expect_used \
        -D clippy::panic \
        -D clippy::todo \
        -D clippy::unimplemented

audit:
    cargo audit

test:
    cargo nextest run

coverage:
    cargo tarpaulin --out Html

# Watch-режим (авто-проверка при сохранении)
watch:
    bacon clippy

watch-test:
    bacon test

docs:
    cargo doc --no-deps

build:
    cargo build --release

# Code review (запусти перед деплоем)
review:
    @echo "=== Изменения для review ==="
    git diff --staged --stat
    @echo "\n=== Запроси у AI ===" 
    @echo "Проверь: баги, безопасность, производительность, соответствие архитектуре"
    git diff --staged

deploy: ci
    ./deploy.sh

# База данных
migrate:
    sqlx migrate run
    just gen-context

migrate-new name:
    sqlx migrate add {{name}}

# Генерация контекста для AI
gen-context:
    pg_dump --schema-only $DATABASE_URL > docs/schema.sql
    cargo sqlx prepare
    curl -s http://localhost:3000/api-docs/openapi.json > docs/openapi.json
    cargo run --bin gen-schemas > docs/models.json
```

---

## Процесс работы

### Новый VPS (один раз)
```bash
./setup-vps.sh user@IP
```

### Поднять инфраструктуру (один раз)
```bash
./up-infra.sh
```

### Разработка (ежедневно)
```
Claude Code / OpenCode → пишешь код
                      ↓
                 just ci
                      ↓
          git commit + push в Forgejo
```

### Деплой
```bash
just deploy
```

### Откат
```bash
./deploy.sh myapp rollback v1.2.3
```

---

## Переезд на новый ПК

```bash
# 1. Установить pass и gnupg
sudo apt install pass gnupg

# 2. Импортировать GPG ключ
gpg --import private-key.gpg

# 3. Склонировать секреты
git clone git@forgejo:secrets.git ~/.password-store

# 4. Готово
pass show project/api-key
```
