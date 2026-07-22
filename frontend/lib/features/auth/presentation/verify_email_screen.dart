import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../l10n/locale_providers.dart';
import '../state/auth_providers.dart';

/// Shown right after registration - the account exists but is inactive
/// until the 6-digit code just emailed to [email] is confirmed (see
/// RegisterView/VerifyEmailView). On success, authControllerProvider
/// flips to the logged-in state itself (verifyEmail behaves like
/// login()), so the router's own redirect takes it from here - this
/// screen doesn't navigate on success itself.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _submitting = false;
  Object? _submitError;
  bool _resending = false;
  String? _resendMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(
            email: widget.email,
            code: _codeController.text.trim(),
          );
    } catch (error) {
      if (mounted) setState(() => _submitError = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resendMessage = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendVerification(widget.email);
      if (mounted) {
        setState(
            () => _resendMessage = ref.read(appStringsProvider).resendCodeSent);
      }
    } catch (error) {
      if (mounted) setState(() => _resendMessage = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return Scaffold(
      appBar: AppBar(
        title: KabinAppBarTitle(t.verifyEmailTitle),
        actions: const [LanguageMenu()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                maxWidth: 440,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t.codeSentMessage(widget.email),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: InputDecoration(
                          labelText: t.verificationCodeLabel,
                          counterText: '',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length != 6)
                                ? t.enterSixDigitCode
                                : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_submitError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          apiErrorMessage(_submitError!),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(t.verifyButton),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _resending ? null : _resend,
                        child: Text(t.resendCodePrompt),
                      ),
                      if (_resendMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _resendMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
