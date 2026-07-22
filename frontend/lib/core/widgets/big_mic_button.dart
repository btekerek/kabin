import 'package:flutter/material.dart';

import '../agora/agora_channel_controller.dart';

class BigMicButton extends StatelessWidget {
  const BigMicButton({
    super.key,
    required this.status,
    required this.muted,
    required this.onTap,
    this.enabled = true,
  });

  final AgoraConnectionStatus status;
  final bool muted;
  final VoidCallback onTap;

  /// Set to false to force the disabled look regardless of [status] -
  /// e.g. a session that isn't active yet, where broadcasting isn't
  /// allowed even once the Agora connection itself succeeds.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color color, IconData icon, String label, bool statusEnabled) =
        !enabled
            ? (
                scheme.surfaceContainerHighest,
                Icons.mic_off,
                'MIC UNAVAILABLE',
                false,
              )
            : switch (status) {
                AgoraConnectionStatus.connecting ||
                AgoraConnectionStatus.disconnected =>
                  (
                    scheme.surfaceContainerHighest,
                    Icons.mic_none,
                    'CONNECTING...',
                    false,
                  ),
                AgoraConnectionStatus.failed => (
                    scheme.errorContainer,
                    Icons.refresh,
                    'RETRY',
                    true,
                  ),
                AgoraConnectionStatus.connected => (
                    muted ? scheme.surfaceContainerHighest : scheme.primary,
                    muted ? Icons.mic_off : Icons.mic,
                    muted ? 'UNMUTE' : 'MUTE',
                    true,
                  ),
              };

    final Color iconColor = !enabled
        ? scheme.onSurfaceVariant
        : switch (status) {
            AgoraConnectionStatus.connected =>
              muted ? scheme.onSurfaceVariant : scheme.onPrimary,
            AgoraConnectionStatus.failed => scheme.onErrorContainer,
            _ => scheme.onSurfaceVariant,
          };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: statusEnabled ? onTap : null,
            child: SizedBox(
              width: 132,
              height: 132,
              child: Icon(icon, size: 52, color: iconColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
