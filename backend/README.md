# Kabin Backend

Real-time event interpretation platform, backend service. A session has
one source language (the stage) and one or more target language
channels. Three roles: Guide (session owner), Interpreter (joins a
channel), and Listener (no account, joins with a code).

This is the backend half of Kabin. The Flutter client lives in a
separate repo: [translator_mobile](https://github.com/SertacDastan/translator_mobile).

## Stack

Django + Django REST Framework + MySQL, JWT auth
(djangorestframework-simplejwt, dual access/refresh tokens), Django
Channels for WebSockets, drf-spectacular for OpenAPI docs, Agora for
real-time audio.

## Prerequisites

- Python 3.12+
- MySQL 8 (local install or Docker)

## Setup

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt

cp .env.example .env            # fill in real values (see below)

# MySQL: create a local database + user matching your .env values, e.g.
#   mysql -u root -p -e "CREATE DATABASE kabin CHARACTER SET utf8mb4; \
#     CREATE USER 'kabin'@'localhost' IDENTIFIED BY 'kabin'; \
#     GRANT ALL ON kabin.* TO 'kabin'@'localhost';"

python manage.py migrate
python manage.py createsuperuser  # optional, for /admin
python manage.py runserver
```

API docs once running: `http://localhost:8000/api/docs/`
Health check: `http://localhost:8000/api/health/`

Run tests: `pytest`
Lint/format: `ruff check .` / `ruff format .`

### Agora credentials

`AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in `.env` come from a
personal free Agora account for now. Never commit `.env` - only
`.env.example` (with placeholders) is tracked.

## Project structure

```
config/        Django settings, URLs, ASGI/WSGI entrypoints
apps/
  core/        cross-cutting infra: health check, exception handler, language registry
  accounts/    User model, auth, registration, password reset
  sessions/    Session, Channel, Message models and views
  realtime/    Django Channels consumers + WS routing
```

## Contributing

- Branch per change: `feat/<name>`, `fix/<name>`, `chore/<name>`.
- Small atomic commits, one-line commit messages.
- Never commit `.env`, build artifacts, or generated files.
- `main` is protected - everything lands via PR with green CI.
