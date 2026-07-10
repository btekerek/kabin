import 'package:flutter/material.dart';

/// Scaffold entrypoint. Real app wiring (routing per role, API base URL
/// via --dart-define=API_BASE_URL, Dio client with token refresh, Agora
/// engine init) is added starting with the auth vertical slice.
void main() {
  runApp(const KabinApp());
}

class KabinApp extends StatelessWidget {
  const KabinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Kabin',
      home: Scaffold(
        body: Center(child: Text('Kabin — scaffold')),
      ),
    );
  }
}
