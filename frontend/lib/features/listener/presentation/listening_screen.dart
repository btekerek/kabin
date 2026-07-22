import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/agora/agora_join_result.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/locale_providers.dart';
import '../data/listener_status_socket.dart';
import '../state/listener_providers.dart';
import 'listening_args.dart';

/// Owns one AgoraChannelController for the lifetime of this screen -
/// joins on entry (audience role, no mic), leaves and disposes on exit.
/// Needs Riverpod (unlike before) to reach listenerRepositoryProvider
/// when the language dropdown triggers a channel switch.
class ListeningScreen extends ConsumerStatefulWidget {
  const ListeningScreen({super.key, required this.args});

  final ListeningArgs args;

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen> {
  final _controller = AgoraChannelController();
  late ListenerStatusSocket _statusSocket;
  late int _channelId;
  late AgoraJoinResult _joinResult;
  Object? _connectError;
  String? _sessionStatus;
  bool _switching = false;

  bool get _sessionEnded => _sessionStatus == 'ended';

  @override
  void initState() {
    super.initState();
    _channelId = widget.args.channelId;
    _joinResult = widget.args.joinResult;
    _statusSocket = ListenerStatusSocket();
    _connect();
    _connectStatusSocket();
  }

  void _connectStatusSocket() {
    _statusSocket.statusUpdates.listen((status) {
      if (mounted) setState(() => _sessionStatus = status);
    });
    _statusSocket.connect(
      channelId: _channelId,
      listenerUuid: widget.args.listenerUuid,
    );
  }

  Future<void> _connect() async {
    try {
      await _controller.join(
        appId: _joinResult.agoraAppId,
        channelName: _joinResult.agoraChannelName,
        token: _joinResult.agoraToken,
        asBroadcaster: false,
      );
    } catch (error) {
      if (mounted) setState(() => _connectError = error);
    }
  }

  /// Rejoining SessionJoinView with the same listenerUuid but a
  /// different channelId switches this listener's channel server-side
  /// (see ListenerRepository.join) rather than erroring - so this is
  /// just a normal join for fresh credentials, then a normal
  /// AgoraChannelController.join() (which already leaves any existing
  /// connection first) to move the audio, plus a fresh status socket
  /// scoped to the new channel.
  Future<void> _switchChannel(int newChannelId) async {
    if (newChannelId == _channelId || _switching) return;
    setState(() {
      _switching = true;
      _connectError = null;
    });
    try {
      final result = await ref.read(listenerRepositoryProvider).join(
            sessionId: widget.args.sessionId,
            listenerUuid: widget.args.listenerUuid,
            channelId: newChannelId,
          );
      _statusSocket.dispose();
      _statusSocket = ListenerStatusSocket();
      setState(() {
        _channelId = newChannelId;
        _joinResult = result;
      });
      await _connect();
      _connectStatusSocket();
    } catch (error) {
      if (mounted) setState(() => _connectError = error);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _leave() async {
    await _controller.leave();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    _statusSocket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(widget.args.sessionName),
        actions: const [LanguageMenu()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_sessionEnded) ...[
                  const _EndedBanner(),
                  const SizedBox(height: 24),
                ],
                Text(t.listeningInLabel,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  value: _channelId,
                  items: [
                    for (final channel in widget.args.channels)
                      DropdownMenuItem(
                        value: channel.id,
                        child: Text(channel.language),
                      ),
                  ],
                  onChanged: _switching || _sessionEnded
                      ? null
                      : (value) {
                          if (value != null) _switchChannel(value);
                        },
                ),
                const SizedBox(height: 16),
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.statusStream,
                  initialData: _controller.status,
                  builder: (context, snapshot) =>
                      Text(_statusLabel(t, snapshot.data)),
                ),
                if (_connectError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    t.connectFailedMessage,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton(onPressed: _leave, child: Text(t.leaveButton)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(AppStrings t, AgoraConnectionStatus? status) {
    if (_sessionEnded) return t.sessionEndedStatusLabel;
    switch (status) {
      case AgoraConnectionStatus.connecting:
        return t.connectingLabel;
      case AgoraConnectionStatus.connected:
        return t.listeningStatusLabel;
      case AgoraConnectionStatus.failed:
        return t.connectionFailedLabel;
      case AgoraConnectionStatus.disconnected:
      case null:
        return t.disconnectedLabel;
    }
  }
}

class _EndedBanner extends ConsumerWidget {
  const _EndedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final t = ref.watch(appStringsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        t.sessionEndedBannerMessage,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}
