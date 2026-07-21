# kabin

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running on a real Android/iOS device

Desktop and web targets need nothing extra - plain `flutter run` (or
`flutter run -d windows`, etc.) works as-is, since
`lib/core/network/api_config.dart` defaults those to `127.0.0.1:8000`.

A real phone (or the emulator) can't reach the backend over `127.0.0.1`
though - it needs your machine's actual LAN IP. That IP is never
hardcoded in this repo (this project will eventually go public), so pass
it explicitly only when running on a phone:

1. Find your LAN IP: run `ipconfig`, look under your Wi-Fi adapter's
   "IPv4 Address" (something like `192.168.1.x`).
2. Run: `flutter run --dart-define=API_BASE_URL=http://192.168.1.x:8000`

That's it - no aliases or profile setup needed. Just remember to add the
flag on phone runs; desktop/web runs don't need it.
