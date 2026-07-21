import 'package:flutter/material.dart';

import '../agora/agora_channel_controller.dart';

class BigMicButton extends StatelessWidget {
  const BigMicButton({
    super.key,
    required this.status,
    required this.muted,
    required this.onTap,
  });

  final AgoraConnectionStatus status;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color color, IconData icon, String label, bool enabled) =
        switch (status) {
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

    final Color iconColor = switch (status) {
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
            onTap: enabled ? onTap : null,
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
