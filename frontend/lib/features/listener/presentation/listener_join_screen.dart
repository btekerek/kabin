import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../domain/listener_channel.dart';
import '../domain/listener_session_summary.dart';
import '../state/listener_providers.dart';
import 'listening_args.dart';

/// No account needed - a Listener identifies themselves with a PIN
/// (found via SessionLookupView) and a persisted UUID (ListenerIdentity),
/// never a login. See ADR-002.
class ListenerJoinScreen extends ConsumerStatefulWidget {
  const ListenerJoinScreen({super.key});

  @override
  ConsumerState<ListenerJoinScreen> createState() => _ListenerJoinScreenState();
}

class _ListenerJoinScreenState extends ConsumerState<ListenerJoinScreen> {
  final _pinController = TextEditingController();

  ListenerSessionSummary? _session;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(listenerRepositoryProvider)
          .lookup(_pinController.text.trim());
      setState(() => _session = session);
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinChannel(ListenerChannel channel) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final listenerUuid = await ref.read(listenerUuidProvider.future);
      final result = await ref.read(listenerRepositoryProvider).join(
            sessionId: _session!.id,
            listenerUuid: listenerUuid,
            channelId: channel.id,
          );
      if (!mounted) return;
      context.push(
        '/listen',
        extra: ListeningArgs(
          joinResult: result,
          channelLanguage: channel.language,
          sessionName: _session!.name,
        ),
      );
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a session')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _session == null
            ? _buildPinEntry()
            : _buildChannelPicker(_session!),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: const InputDecoration(labelText: 'Listener PIN'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            apiErrorMessage(_error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _lookup,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Find session'),
        ),
      ],
    );
  }

  Widget _buildChannelPicker(ListenerSessionSummary session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(session.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Pick a language to listen in:'),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            apiErrorMessage(_error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: session.channels.length,
            itemBuilder: (context, index) {
              final channel = session.channels[index];
              return ListTile(
                title: Text(channel.language),
                subtitle: channel.isSource
                    ? const Text('Original (stage) audio')
                    : null,
                trailing: const Icon(Icons.chevron_right),
                enabled: !_busy,
                onTap: () => _joinChannel(channel),
              );
            },
          ),
        ),
      ],
    );
  }
}
