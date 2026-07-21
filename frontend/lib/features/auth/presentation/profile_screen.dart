import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/profile_menu.dart';
import '../state/auth_providers.dart';

/// Reached from the account dropdown on HomeScreen. Shows the avatar and
/// a change-password form - both UI shells only for now. Neither the
/// avatar upload nor the password change actually calls a backend
/// endpoint yet (there isn't one), so both actions surface a "coming
/// soon" notice instead of silently doing nothing or pretending to
/// succeed.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon.')),
    );
  }

  void _submitPasswordChange() {
    if (!_formKey.currentState!.validate()) return;
    _comingSoon();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).valueOrNull?.email;
    final initial =
        (email != null && email.isNotEmpty) ? email[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const KabinAppBarTitle('Profile'),
        actions: const [ProfileMenu(), SizedBox(width: 4)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            child: Text(initial,
                                style: const TextStyle(fontSize: 32)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: Theme.of(context).colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _comingSoon,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.photo_camera_outlined,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (email != null)
                        Text(email,
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('CHANGE PASSWORD',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PasswordField(
                        controller: _currentPasswordController,
                        labelText: 'Current password',
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Current password is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _newPasswordController,
                        labelText: 'New password',
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'New password is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm new password',
                        validator: (value) =>
                            value != _newPasswordController.text
                                ? 'Passwords do not match'
                                : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitPasswordChange,
                        child: const Text('UPDATE PASSWORD'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
