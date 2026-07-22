import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/agora/agora_channel_controller.dart';
import '../../../core/agora/agora_dual_channel_controller.dart';
import '../../../core/agora/agora_join_result.dart';
import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/big_mic_button.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/profile_menu.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/locale_providers.dart';
import '../../auth/state/auth_providers.dart';
import '../../chat/presentation/chat_args.dart';
import '../../chat/presentation/chat_fab.dart';
import '../../listener/domain/listener_channel.dart';
import '../../sessions/domain/channel.dart';
import '../data/mic_presence_socket.dart';
import '../domain/interpreter_join_result.dart';
import '../state/interpreter_providers.dart';
import 'broadcasting_args.dart';

class BroadcastingScreen extends ConsumerStatefulWidget {
  const BroadcastingScreen({super.key, required this.args});

  final BroadcastingArgs args;

  @override
  ConsumerState<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends ConsumerState<BroadcastingScreen> {
  final _controller = AgoraDualChannelController();
  MicPresenceSocket _micPresence = MicPresenceSocket();
  final _liveInterpreterIds = <int>{};
  Object? _connectError;
  Object? _leaveError;
  Object? _relayError;
  Object? _targetError;
  bool _muted = true;
  bool _leaving = false;
  bool _switchingRelay = false;
  bool _switchingTarget = false;
  late String _sessionStatus;

  // Mutable: an interpreter can switch both their target (output)
  // channel and their relay (source) channel live from this screen -
  // see _switchTarget/_switchRelay. Everything below starts from
  // widget.args.joinResult and is replaced wholesale on a target
  // switch, since that's effectively a brand new claim.
  late Channel _channel;
  late String _interpreterCode;
  late AgoraJoinResult _primaryJoin;
  late RelayJoinResult? _relay;
  late List<ListenerChannel> _availableRelayChannels;
  late List<ListenerChannel> _availableTargetChannels;

  bool get _canBroadcast => _sessionStatus == 'active';

  @override
  void initState() {
    super.initState();
    _channel = widget.args.joinResult.channel;
    _interpreterCode = widget.args.interpreterCode;
    _sessionStatus = _channel.sessionStatus;
    _primaryJoin = widget.args.joinResult.joinResult;
    _relay = widget.args.joinResult.relay;
    _availableRelayChannels = widget.args.joinResult.availableRelayChannels;
    _availableTargetChannels = widget.args.joinResult.availableTargetChannels;
    _connect();
    _connectMicPresence();
  }

  void _connectMicPresence() {
    _micPresence.events.listen((event) {
      final myId = ref.read(authControllerProvider).valueOrNull?.id;
      if (event.userId == myId) return;
      setState(() {
        if (event.live) {
          _liveInterpreterIds.add(event.userId);
        } else {
          _liveInterpreterIds.remove(event.userId);
        }
      });
    });
    _micPresence.statusRequests.listen((_) {
      if (!_muted) _micPresence.sendMicState(true);
    });
    // Pushed instantly by _SessionTransitionView.after_transition when
    // the guide starts/stops/ends the session - lets the mic gate
    // unlock without a reconnect if the interpreter joined early. Ending
    // also force-mutes a still-live mic - _canBroadcast alone only stops
    // a *future* unmute, it doesn't touch one already in progress.
    _micPresence.sessionStatusUpdates.listen((status) {
      if (!mounted) return;
      setState(() => _sessionStatus = status);
      if (status == 'ended' && !_muted) _toggleMute();
    });
    _micPresence.connect(
      channelId: _channel.id,
      accessToken: ref.read(authSessionProvider).accessToken ?? '',
    );
  }

  Future<void> _connect() async {
    final relay = _relay;
    try {
      await _controller.join(
        appId: _primaryJoin.agoraAppId,
        primaryChannelName: _primaryJoin.agoraChannelName,
        primaryToken: _primaryJoin.agoraToken,
        secondaryChannelName: relay?.joinResult.agoraChannelName,
        secondaryToken: relay?.joinResult.agoraToken,
      );
    } catch (error) {
      if (mounted) setState(() => _connectError = error);
    }
  }

  /// Fetches fresh credentials for [target] and swaps the secondary
  /// (relay) connection over to it without touching the interpreter's
  /// own live mic - see AgoraDualChannelController.switchSecondary.
  Future<void> _switchRelay(int relayChannelId) async {
    if (relayChannelId == _relay?.channel.id) return;
    setState(() {
      _switchingRelay = true;
      _relayError = null;
    });
    try {
      final result = await ref.read(interpreterRepositoryProvider).setRelay(
            channelId: _channel.id,
            relayChannelId: relayChannelId,
          );
      await _controller.switchSecondary(
        channelName: result.joinResult.agoraChannelName,
        token: result.joinResult.agoraToken,
      );
      if (mounted) setState(() => _relay = result);
    } catch (error) {
      if (mounted) setState(() => _relayError = error);
    } finally {
      if (mounted) setState(() => _switchingRelay = false);
    }
  }

  /// Moves this interpreter's own claim to [targetChannelId] - a
  /// different language to translate into. There's no way to swap just
  /// the primary connection's channel in the Agora SDK, so this leaves
  /// and rejoins both connections (and reconnects mic-presence, which is
  /// scoped to the old channel id) rather than trying to patch state in
  /// place.
  Future<void> _switchTarget(int targetChannelId) async {
    if (targetChannelId == _channel.id) return;
    setState(() {
      _switchingTarget = true;
      _targetError = null;
    });
    try {
      final result =
          await ref.read(interpreterRepositoryProvider).switchChannel(
                channelId: _channel.id,
                targetChannelId: targetChannelId,
              );
      _micPresence.dispose();
      _micPresence = MicPresenceSocket();
      _liveInterpreterIds.clear();
      setState(() {
        _channel = result.channel;
        _interpreterCode = result.channel.interpreterCode!;
        _primaryJoin = result.joinResult;
        _relay = result.relay;
        _availableRelayChannels = result.availableRelayChannels;
        _availableTargetChannels = result.availableTargetChannels;
        _muted = true;
      });
      await _connect();
      _connectMicPresence();
    } catch (error) {
      if (mounted) setState(() => _targetError = error);
    } finally {
      if (mounted) setState(() => _switchingTarget = false);
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _controller.setMicMuted(next);
    _micPresence.sendMicState(!next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _handleMicTap() async {
    if (_controller.primaryStatus == AgoraConnectionStatus.failed) {
      _connect();
      return;
    }
    if (_muted && _liveInterpreterIds.isNotEmpty) {
      final proceed = await _confirmBroadcastOverMic();
      if (proceed != true) return;
    }
    _toggleMute();
  }

  Future<bool?> _confirmBroadcastOverMic() {
    final t = ref.read(appStringsProvider);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.anotherInterpreterLiveTitle),
        content: Text(t.anotherInterpreterLiveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.turnOnAnywayButton),
          ),
        ],
      ),
    );
  }

  Future<void> _leave() async {
    setState(() {
      _leaving = true;
      _leaveError = null;
    });
    try {
      await _controller.leave();
      await ref.read(interpreterRepositoryProvider).leave(_interpreterCode);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _leaveError = error);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _micPresence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(_channel.language),
        actions: const [
          LanguageMenu(),
          SizedBox(width: 4),
          ProfileMenu(),
          SizedBox(width: 4),
        ],
      ),
      floatingActionButton: ChatFab(
        args: ChatArgs(
          sessionId: _channel.sessionId,
          channelId: _channel.id,
          accessToken: ref.read(authSessionProvider).accessToken ?? '',
          title: t.chatLabel,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_sessionStatus == 'ended') ...[
                  const _EndedBanner(),
                  const SizedBox(height: 16),
                ],
                _LanguagePickers(
                  targetChannelId: _channel.id,
                  availableTargetChannels: _availableTargetChannels,
                  onTargetChanged: _switchingTarget ? null : _switchTarget,
                  relayChannelId: _relay?.channel.id,
                  availableRelayChannels: _availableRelayChannels,
                  onRelayChanged: _switchingRelay ? null : _switchRelay,
                  busy: _switchingTarget || _switchingRelay,
                ),
                if (_targetError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.switchLanguageError(apiErrorMessage(_targetError!)),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_relayError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.switchRelayError(apiErrorMessage(_relayError!)),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.primaryStatusStream,
                  initialData: _controller.primaryStatus,
                  builder: (context, snapshot) =>
                      Text(_primaryStatusLabel(t, snapshot.data)),
                ),
                if (_relay != null)
                  StreamBuilder<AgoraConnectionStatus>(
                    stream: _controller.secondaryStatusStream,
                    initialData: _controller.secondaryStatus,
                    builder: (context, snapshot) {
                      final status = snapshot.data;
                      if (status != AgoraConnectionStatus.failed) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          t.relayAudioFailedMessage,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
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
                if (_leaveError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    t.leaveError(apiErrorMessage(_leaveError!)),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                StreamBuilder<AgoraConnectionStatus>(
                  stream: _controller.primaryStatusStream,
                  initialData: _controller.primaryStatus,
                  builder: (context, snapshot) => BigMicButton(
                    status: snapshot.data ?? AgoraConnectionStatus.disconnected,
                    muted: _muted,
                    onTap: _leaving ? () {} : _handleMicTap,
                    enabled: _canBroadcast,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: _leaving ? null : _leave,
                  child: Text(t.leaveButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _primaryStatusLabel(AppStrings t, AgoraConnectionStatus? status) {
    switch (status) {
      case AgoraConnectionStatus.connecting:
        return t.connectingLabel;
      case AgoraConnectionStatus.connected:
        return _muted ? t.connectedLabel : t.broadcastingLabel;
      case AgoraConnectionStatus.failed:
        return t.connectionFailedLabel;
      case AgoraConnectionStatus.disconnected:
      case null:
        return t.disconnectedLabel;
    }
  }
}

/// Two simple dropdowns: which channel this interpreter broadcasts
/// *into* (target language) and which channel they listen to *while*
/// interpreting (source language). Keyed by channel id rather than by
/// [ListenerChannel] object identity, since the "current" value often
/// comes from a different response than the options list.
class _LanguagePickers extends ConsumerWidget {
  const _LanguagePickers({
    required this.targetChannelId,
    required this.availableTargetChannels,
    required this.onTargetChanged,
    required this.relayChannelId,
    required this.availableRelayChannels,
    required this.onRelayChanged,
    required this.busy,
  });

  final int targetChannelId;
  final List<ListenerChannel> availableTargetChannels;
  final ValueChanged<int>? onTargetChanged;

  final int? relayChannelId;
  final List<ListenerChannel> availableRelayChannels;
  final ValueChanged<int>? onRelayChanged;

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: _LanguageDropdown(
            label: t.sourceDropdownLabel,
            value: relayChannelId,
            options: availableRelayChannels,
            onChanged: relayChannelId == null ? null : onRelayChanged,
            enabled: !busy,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _LanguageDropdown(
            label: t.targetDropdownLabel,
            value: targetChannelId,
            options: availableTargetChannels,
            onChanged: onTargetChanged,
            enabled: !busy,
          ),
        ),
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final int? value;
  final List<ListenerChannel> options;
  final ValueChanged<int>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        DropdownButton<int>(
          isExpanded: true,
          value: value,
          items: [
            for (final option in options)
              DropdownMenuItem(value: option.id, child: Text(option.language)),
          ],
          onChanged: enabled && onChanged != null
              ? (id) {
                  if (id != null) onChanged!(id);
                }
              : null,
        ),
      ],
    );
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
