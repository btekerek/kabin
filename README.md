# Kabin

Real-time event interpretation platform — a mobile-first app that puts the
interpretation booth of a conference into everyone's pocket. A session has
one source language (the stage) and one or more target language channels.
Three roles: Guide (session owner), Interpreter (joins a channel), and
Listener (no account, joins with a code).

See the top of this repo's project brief for the full spec (roles, data
model, i18n, operational rules). This README is the "clone to running" path.

## Stack

- **Backend**: Django + Django REST Framework + PostgreSQL, JWT auth
  (djangorestframework-simplejwt, dual access/refresh tokens), Django
  Channels for WebSockets, drf-spectacular for OpenAPI docs.
- **Frontend**: Flutter (mobile-first, Android first), `dio` for
  networking, `agora_rtc_engine` for media, `shared_preferences` for
  listener identity persistence.
- **Media**: Agora (personal free-tier account for now; company account
  later is just a credential swap).

## Prerequisites

- Python 3.12+
- PostgreSQL 16 (local install or Docker)
- Flutter SDK (stable channel) — for the frontend
- Node not required for this repo

## Backend setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt

cp .env.example .env            # fill in real values (see below)

# Postgres: create a local database matching your .env values, e.g.
#   createdb kabin

python manage.py migrate
python manage.py createsuperuser  # optional, for /admin
python manage.py runserver
```

API docs once running: `http://localhost:8000/api/docs/`
Health check: `http://localhost:8000/api/health/`

Run tests: `pytest` (from `backend/`)
Lint/format: `ruff check .` / `ruff format .` (from `backend/`)

### Agora credentials

`AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in `.env` come from a personal
free Agora account for now. Never commit `.env` — only `.env.example`
(with placeholders) is tracked.

## Frontend setup

```bash
cd frontend
flutter pub get
```

**First time only** (this repo does not yet have `android/`/`ios/`
platform folders committed): run

```bash
flutter create --org com.kabin --project-name kabin .
```

from inside `frontend/` once. This backfills the platform folders without
touching the existing `lib/`, `test/`, or `pubspec.yaml` (flutter create
merges into an existing project rather than overwriting your Dart code).
Commit the generated `android/`/`ios/` folders after that; nobody needs to
run this again.

Then run against a running backend:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000  # Android emulator
```

Lint: `flutter analyze` · Format: `dart format --set-exit-if-changed .` ·
Tests: `flutter test`

## Project structure

```
backend/
  config/        Django settings, URLs, ASGI/WSGI entrypoints
  apps/
    core/        cross-cutting infra: health check, custom exception handler
    accounts/    User model (Guide/Interpreter accounts)
    sessions/    Session, Channel, Message, RaiseHandEntry, ... (added next slice)
    realtime/    Django Channels consumers + WS routing
frontend/
  lib/
    core/        shared infra (API client, etc. — added with the auth slice)
    features/    per-role screens and flows
    l10n/        single Dart string catalog (TR/EN/DE/FR/ES/AR)
docs/adr/        architecture decision records
.github/workflows/ci.yml   backend + frontend CI
```

## CI

GitHub Actions runs on every push/PR: backend job (ruff + pytest against a
Postgres service container), frontend job (dart format, flutter analyze,
flutter test). `main` is protected — everything lands via PR with green CI.

## Contributing (solo-dev discipline, still enforced)

- Branch per change: `feat/<name>`, `fix/<name>`, `chore/<name>`.
- Conventional Commits, small atomic commits, PR + self-review even solo.
- Never commit `.env`, build artifacts, or generated files.
- Record significant decisions as ADRs in `docs/adr/`.

## Status

Scaffold complete: Django project + apps, Flutter skeleton, CI, repo
hygiene. Auth (dual-token JWT) is the first vertical slice — see
`docs/adr/` once ADR-001 is written.
