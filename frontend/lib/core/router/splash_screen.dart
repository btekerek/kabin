import 'package:flutter/material.dart';

/// Shown only while authControllerProvider is resolving its initial
/// bootstrap (checking whether a stored refresh token still works).
/// The router redirects away from here the instant that resolves
/// either way.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
