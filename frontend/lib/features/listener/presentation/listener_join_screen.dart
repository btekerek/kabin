import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/locale_providers.dart';
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
          sessionId: _session!.id,
          channelId: channel.id,
          channels: _session!.channels,
          sessionName: _session!.name,
          listenerUuid: listenerUuid,
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
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(t.joinSessionTitle),
        actions: const [LanguageMenu()],
      ),
      body: _session == null
          ? _buildPinEntry(t)
          : Padding(
              padding: const EdgeInsets.all(24),
              child: _buildChannelPicker(_session!, t),
            ),
    );
  }

  Widget _buildPinEntry(AppStrings t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: InputDecoration(labelText: t.listenerPinLabel),
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
                    : Text(t.findSessionButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelPicker(ListenerSessionSummary session, AppStrings t) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(session.name,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(t.pickLanguageToListenPrompt,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                apiErrorMessage(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: ListView.separated(
                itemCount: session.channels.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final channel = session.channels[index];
                  return Card(
                    child: ListTile(
                      title: Text(channel.language),
                      subtitle: channel.isSource
                          ? Text(t.originalStageAudioLabel)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !_busy,
                      onTap: () => _joinChannel(channel),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
