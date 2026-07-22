import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/big_mic_button.dart';
import '../../../core/widgets/content_column.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/profile_menu.dart';
import '../../../l10n/locale_providers.dart';
import '../../auth/state/auth_providers.dart';
import '../../chat/presentation/chat_args.dart';
import '../../chat/presentation/chat_fab.dart';
import '../domain/channel.dart';
import '../domain/session.dart';
import '../state/session_providers.dart';
import 'language_label.dart';

class SessionDashboardScreen extends ConsumerWidget {
  const SessionDashboardScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    final session = sessionAsync.valueOrNull;
    final t = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(t.sessionScreenTitle),
        actions: const [
          LanguageMenu(),
          SizedBox(width: 4),
          ProfileMenu(),
          SizedBox(width: 4),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (session) => _DashboardBody(session: session),
      ),
      floatingActionButton: session == null
          ? null
          : ChatFab(
              args: ChatArgs(
                sessionId: session.id,
                accessToken: ref.read(authSessionProvider).accessToken ?? '',
                title: t.chatTitle(session.name),
              ),
            ),
    );
  }
}

/// Owns the Guide's own AgoraChannelController. Starting the session and
/// going live are one user action here (the toggle in _SessionCard), not
/// two - see _startAndGoLive/_stopAndLeaveMic.
class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.session});

  final Session session;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  final _micController = AgoraChannelController();

  /// True while the combined start-session+go-live (or stop+leave)
  /// sequence is running - disables the toggle so it can't be double-hit.
  bool _togglingSession = false;

  bool _muted = true;
  Object? _micError;

  @override
  void initState() {
    super.initState();
    // Reopening the dashboard on an already-active session should try to
    // rejoin the mic automatically rather than leaving the guide to
    // notice it's silent and hunt for a button.
    if (widget.session.status == SessionStatus.active) {
      _connectMic();
    }
  }

  Future<void> _connectMic() async {
    setState(() => _micError = null);
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .broadcast(widget.session.id);
      await _micController.join(
        appId: result.agoraAppId,
        channelName: result.agoraChannelName,
        token: result.agoraToken,
        asBroadcaster: true,
      );
    } catch (error) {
      if (mounted) setState(() => _micError = error);
    }
  }

  Future<void> _startAndGoLive() async {
    setState(() {
      _togglingSession = true;
      _micError = null;
    });
    try {
      await ref.read(sessionDetailProvider(widget.session.id).notifier).start();
      // start() swallows its own errors into AsyncError rather than
      // throwing (see SessionDetailController._transition) - check the
      // resulting status before touching the mic, otherwise a rejected
      // transition would still try to go live.
      final latest = ref.read(sessionDetailProvider(widget.session.id));
      if (latest.value?.status != SessionStatus.active) return;
      await _connectMic();
    } finally {
      if (mounted) setState(() => _togglingSession = false);
    }
  }

  Future<void> _stopAndLeaveMic() async {
    setState(() => _togglingSession = true);
    try {
      await _micController.leave();
      if (mounted) setState(() => _muted = true);
      await ref.read(sessionDetailProvider(widget.session.id).notifier).stop();
    } finally {
      if (mounted) setState(() => _togglingSession = false);
    }
  }

  Future<void> _endSession() async {
    setState(() => _togglingSession = true);
    try {
      try {
        await _micController.leave();
      } catch (_) {
        // Ending the session should proceed even if hanging up the mic
        // failed - there's nothing left to serve it anyway.
      }
      if (mounted) setState(() => _muted = true);
      await ref.read(sessionDetailProvider(widget.session.id).notifier).end();
    } finally {
      if (mounted) setState(() => _togglingSession = false);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _micController.setMicMuted(next);
    if (mounted) setState(() => _muted = next);
  }

  /// Single tap target for BigMicButton - retries the mic connection if
  /// it failed, otherwise toggles mute. Mirrors BroadcastingScreen's
  /// _handleMicTap.
  void _handleMicTap() {
    if (_micController.status == AgoraConnectionStatus.failed) {
      _connectMic();
    } else {
      _toggleMute();
    }
  }

  @override
  void dispose() {
    _micController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final detailState = ref.watch(sessionDetailProvider(session.id));
    final busy = _togglingSession || detailState.isLoading;
    final targetChannels =
        session.channels.where((channel) => !channel.isSource).toList();
    final t = ref.watch(appStringsProvider);

    return ContentColumn(
      maxWidth: 640,
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(session.name, style: Theme.of(context).textTheme.headlineSmall),
          if (session.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(session.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          _SessionCard(
            sourceLanguage: session.sourceLanguage,
            status: session.status,
            busy: busy,
            micStatus: _micController.status,
            micStatusStream: _micController.statusStream,
            muted: _muted,
            micError: _micError,
            onToggle: (goingLive) =>
                goingLive ? _startAndGoLive() : _stopAndLeaveMic(),
            onMicTap: _handleMicTap,
          ),
          const SizedBox(height: 24),
          _CodeCard(
            label: t.listenerCodeLabel,
            code: session.listenerCode,
            description: t.listenerCodeDescription,
          ),
          if (targetChannels.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              t.interpreterChannelCodesHeader,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 8),
            for (final channel in targetChannels) ...[
              _ChannelCodeCard(channel: channel),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (session.canEnd)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: busy ? null : _endSession,
                  child: Text(t.endSessionButton),
                ),
            ],
          ),
          if (detailState.hasError) ...[
            const SizedBox(height: 16),
            Text(
              apiErrorMessage(detailState.error as Object),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Source-language status card: session status pill up top, and the one
/// toggle that both starts/stops the session and takes the guide's mic
/// live/off with it - this replaces the previous Start/Stop/End +
/// Go Live/Mute/Stop broadcasting six-button spread.
class _SessionCard extends ConsumerWidget {
  const _SessionCard({
    required this.sourceLanguage,
    required this.status,
    required this.busy,
    required this.micStatus,
    required this.micStatusStream,
    required this.muted,
    required this.micError,
    required this.onToggle,
    required this.onMicTap,
  });

  final String sourceLanguage;
  final SessionStatus status;
  final bool busy;
  final AgoraConnectionStatus micStatus;
  final Stream<AgoraConnectionStatus> micStatusStream;
  final bool muted;
  final Object? micError;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ended = status == SessionStatus.ended;
    final t = ref.watch(appStringsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.sourceLanguageLabel,
                          style: Theme.of(context).textTheme.labelMedium),
                      LanguageLabel(
                        sourceLanguage,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(t.startStopSessionLabel,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                if (ended)
                  Text(t.statusEnded,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline))
                else
                  Switch(
                    value: status == SessionStatus.active,
                    onChanged: busy ? null : onToggle,
                  ),
              ],
            ),
            if (status == SessionStatus.active) ...[
              const SizedBox(height: 20),
              Center(
                child: StreamBuilder<AgoraConnectionStatus>(
                  stream: micStatusStream,
                  initialData: micStatus,
                  builder: (context, snapshot) => BigMicButton(
                    status: snapshot.data ?? AgoraConnectionStatus.disconnected,
                    muted: muted,
                    onTap: onMicTap,
                  ),
                ),
              ),
            ],
            if (micError != null) ...[
              const SizedBox(height: 8),
              Text(
                apiErrorMessage(micError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends ConsumerWidget {
  const _StatusPill({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = ref.watch(appStringsProvider);
    final (background, foreground, label) = switch (status) {
      SessionStatus.notStarted => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          t.statusPillNotStarted,
        ),
      SessionStatus.active => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          t.statusPillActive,
        ),
      SessionStatus.ended => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          t.statusPillEnded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: foreground)),
    );
  }
}

class _CodeCard extends ConsumerWidget {
  const _CodeCard(
      {required this.label, required this.code, required this.description});

  final String label;
  final String code;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  Text(code, style: Theme.of(context).textTheme.headlineMedium),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: t.copyTooltip,
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCodeCard extends ConsumerWidget {
  const _ChannelCodeCard({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final languageNames = ref.watch(languageNamesProvider);
    final languageLabel = languageDisplayLabel(languageNames, channel.language);
    // Only non-source channels reach this widget (see targetChannels in
    // _DashboardBodyState.build) - those always carry a code.
    return _CodeCard(
      label: t.channelCodeLabel(languageLabel),
      code: channel.interpreterCode!,
      description: t.channelCodeDescription(languageLabel),
    );
  }
}
