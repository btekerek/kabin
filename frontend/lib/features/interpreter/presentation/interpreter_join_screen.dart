import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../auth/state/auth_providers.dart';
import '../state/interpreter_providers.dart';
import 'broadcasting_args.dart';

/// Authenticated (Interpreter role) entry point - a code alone claims a
/// channel (see ADR-003), so unlike the Listener flow there's no
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
    try {
      final result = await ref.read(interpreterRepositoryProvider).join(code);
      if (!mounted) return;
      context.push(
        '/broadcast',
        extra: BroadcastingArgs(joinResult: result, interpreterCode: code),
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
      appBar: AppBar(
        title: const Text('Join as interpreter'),
        // This is the Interpreter role's landing screen (see
        // app_router.dart's redirect logic) - there's nowhere else in
        // the app's own nav stack to go back to, so without this the
        // account had no way out at all except killing the app. Mirrors
        // the logout action on SessionListScreen, the Guide equivalent.
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: const InputDecoration(labelText: 'Channel code'),
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
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Join channel'),
            ),
          ],
        ),
      ),
    );
  }
}
