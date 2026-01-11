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

## Код: стиль и формат

**Именование:**
- Типы: `PascalCase` — `UserProfile`, `OrderStatus`
- Функции/переменные: `snake_case` — `get_user`, `order_count`
- Константы: `SCREAMING_SNAKE` — `MAX_RETRIES`, `DEFAULT_TIMEOUT`
- Модули: короткие, `snake_case` — `db`, `auth`, `handlers`

**Структура файлов:**
```
// 1. imports (std → external → internal)
// 2. constants
// 3. types/structs
// 4. impl blocks
// 5. functions
// 6. tests (#[cfg(test)])
```

**Форматирование:**
- `rustfmt` — без исключений
- Строки ≤100 символов
- Группировать imports по блокам с пустой строкой

## Код: производительность

**Аллокации:**
- `&str` вместо `String` где возможно
- `Cow<'_, str>` для опционального владения
- `SmallVec` для малых коллекций (≤8 элементов)
- `Box<[T]>` вместо `Vec<T>` для фиксированных данных
- Избегать `.clone()` без необходимости

**Итераторы:**
- `.iter()` вместо `for i in 0..len`
- Ленивые цепочки: `.filter().map().take()`
- `.collect::<Vec<_>>()` только в конце
- `rayon` для CPU-bound параллелизма

**Zero-copy:**
- `bytes::Bytes` для бинарных данных
- `serde_json::RawValue` для отложенного парсинга
- `tokio::io::copy()` для потоков

**Кэширование:**
- Тяжёлые вычисления → Redis с TTL
- Компилированные regex: `lazy_static!` или `once_cell`
- Prepared statements в SQLx (по умолчанию)

## Код: надёжность

**Ошибки:**
- `Result<T, E>` везде, без `unwrap()` / `expect()` в проде
- `thiserror` для типизированных ошибок
- `?` для пробрасывания
- Логировать ошибки на границе (handler/main)

**Валидация:**
- На входе в систему (handlers), не глубже
- `validator` для структур
- Ранний возврат: `if !valid { return Err(...) }`

**Безопасность:**
- Никаких `unsafe` без код-ревью
- SQL только через SQLx параметры (`$1`, `$2`)
- Санитизация пользовательского ввода
- Rate limiting на публичных эндпоинтах

**Тесты:**
- Unit: для бизнес-логики
- Integration: для API endpoints
- `#[should_panic]` для проверки паник
- Моки через traits, не конкретные типы

## Код: async

**Правила:**
- `Clone` вместо ссылок между тасками
- State в БД/Redis, НЕ в памяти процесса
- `Arc<T>` для shared immutable
- `Arc<RwLock<T>>` только если неизбежно
- Каналы: `tokio::sync::mpsc`

**Антипаттерны:**
- `block_on` внутри async — deadlock
- `Mutex` из std в async — использовать `tokio::sync::Mutex`
- Долгие CPU операции — выносить в `spawn_blocking`

## Код: структура модулей

```
src/
├── main.rs          # точка входа, минимум логики
├── lib.rs           # pub mod declarations
├── config.rs        # конфигурация из ENV
├── error.rs         # типы ошибок (thiserror)
├── routes/          # HTTP handlers
│   ├── mod.rs
│   └── users.rs
├── models/          # структуры данных
├── db/              # слой доступа к БД
├── services/        # бизнес-логика
└── utils/           # хелперы
```

**Правила модулей:**
- Один pub тип = один файл (для крупных типов)
- `mod.rs` только для re-exports
- Приватное по умолчанию, `pub` осознанно

## Код: размеры и декомпозиция

**Лимиты строк:**
- Файл: ≤300 строк — если больше, разбивать
- Функция: ≤50 строк — если больше, выделять хелперы
- Impl block: ≤200 строк — разделять по смыслу (CRUD отдельно, бизнес-логика отдельно)

**Когда создавать новый файл:**
- Новая сущность (User, Order, Payment) → `models/user.rs`
- Новый handler group → `routes/users.rs`, `routes/orders.rs`
- Утилита используется в 2+ местах → `utils/`
- Сложная бизнес-логика → `services/billing.rs`

**Когда создавать новый модуль (папку):**
- 3+ связанных файла → выносить в подпапку
- Пример: `routes/admin/mod.rs`, `routes/admin/users.rs`, `routes/admin/settings.rs`

**Декомпозиция функций:**
```rust
// Плохо: 100+ строк в одной функции
async fn create_order(/*...*/) { /* всё здесь */ }

// Хорошо: разбито по шагам
async fn create_order(/*...*/) -> Result<Order> {
    let user = validate_user(&input).await?;
    let items = validate_items(&input.items).await?;
    let order = build_order(user, items)?;
    let saved = save_order(&db, order).await?;
    notify_user(&saved).await?;
    Ok(saved)
}
```

**Признаки что пора разбивать:**
- Скроллить чтобы понять что делает файл
- Функция не помещается на экран
- `impl` блок имеет 10+ методов
- Трудно найти нужный код
- Один файл редактируется в каждом PR

**Структура большого модуля:**
```
services/
├── mod.rs              # pub use, общие трейты
├── billing/
│   ├── mod.rs          # pub use
│   ├── invoice.rs      # создание счетов
│   ├── payment.rs      # обработка платежей
│   └── refund.rs       # возвраты
└── notification/
    ├── mod.rs
    ├── email.rs
    └── telegram.rs
```

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
