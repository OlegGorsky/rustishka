# Rustishka

Автоматическая установка Rust dev-окружения для работы с AI-ассистентами.

## Быстрый старт

```bash
curl -sSL https://raw.githubusercontent.com/OlegGorsky/rustishka/main/scripts/setup.sh | bash
```

Скрипт последовательно:
1. Установит все локальные инструменты
2. Настроит сервер (Git или Production)

## Что устанавливается

### Локально

**Rust CLI-инструменты:**
- `eza` - замена ls
- `bat` - замена cat
- `fd` - замена find
- `ripgrep` - замена grep
- `zoxide` - умный cd
- `dust` - анализ диска
- `delta` - git diff
- `gitui` - TUI для git
- `starship` - prompt
- `just` - task runner

**Cargo-расширения:**
- `bacon` - фоновая компиляция
- `cargo-nextest` - быстрые тесты
- `cargo-audit` - проверка безопасности
- `sqlx-cli` - миграции БД

**AI-инструменты:**
- `beads` (bd) - память между сессиями

### На сервере (Production VPS)

- PostgreSQL 16, Redis 7
- Caddy (reverse proxy + HTTPS)
- Garage (S3), Directus (CMS)
- Netdata, Vector

## Результаты

- `~/.stack-installed.txt` - локальные инструменты
- `~/.server-credentials-{IP}.txt` - доступы к серверу

## Документация

- [STACK.md](STACK.md) - полное описание стека
- [CLAUDE_TEMPLATE.md](CLAUDE_TEMPLATE.md) - шаблон для AI-ассистентов
