import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/profile_menu.dart';
import '../state/auth_providers.dart';

/// Reached from the account dropdown on HomeScreen. Shows the avatar, a
/// change-username form, and a change-password form. The password form
/// is still a UI shell (no backend endpoint yet), so it surfaces a
/// "coming soon" notice; the username form is fully wired to
/// AuthController.updateUsername().
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _usernameFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _updatingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _usernameController.text =
        ref.read(authControllerProvider).valueOrNull?.username ?? '';
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon.')),
    );
  }

  void _submitPasswordChange() {
    if (!_passwordFormKey.currentState!.validate()) return;
    _comingSoon();
  }

  Future<void> _submitUsernameChange() async {
    if (!_usernameFormKey.currentState!.validate()) return;
    setState(() {
      _updatingUsername = true;
      _usernameError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateUsername(_usernameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated.')),
        );
      }
    } catch (error) {
      setState(() => _usernameError = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _updatingUsername = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final username = user?.username;
    final initial = (username != null && username.isNotEmpty)
        ? username[0].toUpperCase()
        : '?';

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
                      if (user?.email != null)
                        Text(user!.email,
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('USERNAME',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 12),
                Form(
                  key: _usernameFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration:
                            const InputDecoration(labelText: 'Username'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Username is required'
                                : null,
                      ),
                      if (_usernameError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _usernameError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            _updatingUsername ? null : _submitUsernameChange,
                        child: _updatingUsername
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('SAVE USERNAME'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('CHANGE PASSWORD',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 12),
                Form(
                  key: _passwordFormKey,
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
