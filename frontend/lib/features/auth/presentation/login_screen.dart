import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../core/widgets/password_field.dart';
import '../../../l10n/locale_providers.dart';
import '../state/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

    return Scaffold(
      // No AppBar - this is the app's landing screen when logged out, and
      // the "Kabin" heading + form below already make it obvious what it
      // is; a redundant "Log in" title bar just wastes vertical space.
      // The language switcher still needs to live somewhere though (a
      // Turkish speaker's very first screen is this one), so it's a
      // small top-right overlay instead of a full AppBar.
      body: Stack(
        children: [
          LayoutBuilder(
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
                            'Kabin',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _identifierController,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration: InputDecoration(
                                labelText: t.emailOrUsernameLabel),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? t.emailOrUsernameRequired
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          PasswordField(
                            controller: _passwordController,
                            labelText: t.passwordLabel,
                            autofillHints: const [AutofillHints.password],
                            validator: (value) =>
                                (value == null || value.isEmpty)
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
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(t.logIn),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: Text(t.noAccountRegisterPrompt),
                          ),
                          TextButton(
                            onPressed: () => context.push('/join'),
                            child: Text(t.listenerJoinPrompt),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: LanguageMenu(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
