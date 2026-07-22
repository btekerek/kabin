import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/password_field.dart';
import '../../../l10n/locale_providers.dart';
import '../state/auth_providers.dart';

/// The guide/interpreter login form - one segment of LandingScreen's
/// tabs, not a route of its own (the app's landing screen when logged
/// out is LandingScreen, with this as its second tab; see LandingScreen
/// for why listener join gets top billing instead).
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final t = ref.watch(appStringsProvider);

    return LayoutBuilder(
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
                    TextFormField(
                      controller: _identifierController,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      decoration:
                          InputDecoration(labelText: t.emailOrUsernameLabel),
                      validator: (value) => (value == null || value.isEmpty)
                          ? t.emailOrUsernameRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _passwordController,
                      labelText: t.passwordLabel,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) => (value == null || value.isEmpty)
                          ? t.passwordRequired
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (authState.hasError) ...[
                      const SizedBox(height: 16),
                      Text(
                        apiErrorMessage(authState.error as Object),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: authState.isLoading ? null : _submit,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t.logIn),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(t.noAccountRegisterPrompt),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
