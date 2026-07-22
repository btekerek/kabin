import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/locale_providers.dart';

/// A password TextFormField with a built-in show/hide toggle (eye icon).
/// Owns its own obscure/visible state internally so every password field
/// in the app (login, register, confirm) gets the toggle for free without
/// each screen re-managing a bool.
class PasswordField extends ConsumerStatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  ConsumerState<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends ConsumerState<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appStringsProvider);
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          tooltip: _obscure ? t.showPasswordTooltip : t.hidePasswordTooltip,
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
    );
  }
}
