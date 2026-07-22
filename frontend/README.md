# Kabin Mobile

Real-time event interpretation platform, mobile-first Flutter app. A
session has one source language (the stage) and one or more target
language channels. Three roles: Guide (session owner), Interpreter
(joins a channel), and Listener (no account, joins with a code).

This is the Flutter client for Kabin. The backend lives in a separate
repo: [translator_BE](https://github.com/SertacDastan/translator_BE).

## Stack

Flutter (mobile-first, Android first), `dio` for networking,
`agora_rtc_engine` for media, `shared_preferences` for listener
identity persistence, Riverpod for state management.

## Setup

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000  # Android emulator
```

Lint: `flutter analyze` · Format: `dart format --set-exit-if-changed .` · Tests: `flutter test`

## Running on a real Android/iOS device

Desktop and web targets need nothing extra - plain `flutter run` (or
`flutter run -d windows`, etc.) works as-is, since
`lib/core/network/api_config.dart` defaults those to `127.0.0.1:8000`.

A real phone (or the emulator) can't reach the backend over `127.0.0.1`
though - it needs your machine's actual LAN IP. That IP is never
hardcoded in this repo, so pass it explicitly only when running on a
phone:

1. Find your LAN IP: run `ipconfig`, look under your Wi-Fi adapter's
   "IPv4 Address" (something like `192.168.1.x`).
2. Run: `flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000`

That's it - no aliases or profile setup needed. Just remember to add
the flag on phone runs; desktop/web runs don't need it.

## Project structure

```
lib/
  core/        shared infra (API client, auth, network, agora, etc.)
  features/    per-role screens and flows
  l10n/        single Dart string catalog (EN/TR)
```

## Contributing

- Branch per change: `feat/<name>`, `fix/<name>`, `chore/<name>`.
- Small atomic commits, one-line commit messages.
- `main` is protected - everything lands via PR with green CI.
