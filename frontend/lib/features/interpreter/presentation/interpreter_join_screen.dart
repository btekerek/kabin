import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/profile_menu.dart';
import '../../../l10n/locale_providers.dart';
import '../domain/interpreter_join_result.dart';
import '../state/interpreter_providers.dart';
import 'broadcasting_args.dart';

/// Authenticated entry point for claiming an interpreter channel - a
/// code alone claims it, so unlike the Listener flow there's no
/// separate lookup step before joining.
class InterpreterJoinScreen extends ConsumerStatefulWidget {
  const InterpreterJoinScreen({super.key});

  @override
  ConsumerState<InterpreterJoinScreen> createState() =>
      _InterpreterJoinScreenState();
}

class _InterpreterJoinScreenState extends ConsumerState<InterpreterJoinScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    InterpreterJoinResult? joinResult;
    try {
      joinResult = await ref.read(interpreterRepositoryProvider).join(code);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (joinResult == null || !mounted) return;

    context.push(
      '/broadcast',
      extra: BroadcastingArgs(joinResult: joinResult, interpreterCode: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(t.joinAsInterpreterTitle),
        actions: const [
          LanguageMenu(),
          SizedBox(width: 4),
          ProfileMenu(),
          SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration:
                      InputDecoration(labelText: t.channelCodeInputLabel),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    apiErrorMessage(_error!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(t.joinChannelButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
