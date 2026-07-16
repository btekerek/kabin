import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../domain/language.dart';
import '../state/session_providers.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetFilterController = TextEditingController();

  String? _sourceLanguageCode;
  final Set<String> _targetLanguageCodes = {};

  bool _submitting = false;
  Object? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _targetFilterController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceLanguageCode == null) {
      setState(() => _submitError = 'Pick a source (stage) language.');
      return;
    }
    if (_targetLanguageCodes.isEmpty) {
      setState(() => _submitError = 'Pick at least one target language.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final session = await ref.read(sessionRepositoryProvider).createSession(
            name: _nameController.text.trim(),
            sourceLanguage: _sourceLanguageCode!,
            targetLanguages: _targetLanguageCodes.toList(),
          );
      ref.invalidate(sessionListProvider);
      if (mounted) {
        context.pushReplacement('/sessions/${session.id}');
      }
    } catch (error) {
      setState(() => _submitError = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languagesAsync = ref.watch(languagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New session')),
      body: languagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (languages) => _buildForm(languages),
      ),
    );
  }

  Widget _buildForm(List<Language> languages) {
    final filter = _targetFilterController.text.trim().toLowerCase();
    final filteredForTargets = filter.isEmpty
        ? languages
        : languages
            .where((language) => language.name.toLowerCase().contains(filter))
            .toList();

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Session name'),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Session name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _sourceLanguageCode,
              decoration: const InputDecoration(
                  labelText: 'Source language (the stage)'),
              items: [
                for (final language in languages)
                  DropdownMenuItem(
                      value: language.code, child: Text(language.name)),
              ],
              onChanged: (value) => setState(() => _sourceLanguageCode = value),
            ),
            const SizedBox(height: 16),
            Text('Target languages',
                style: Theme.of(context).textTheme.titleSmall),
            TextField(
              controller: _targetFilterController,
              decoration: const InputDecoration(
                hintText: 'Filter languages...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: filteredForTargets.length,
                itemBuilder: (context, index) {
                  final language = filteredForTargets[index];
                  return CheckboxListTile(
                    dense: true,
                    title: Text(language.name),
                    value: _targetLanguageCodes.contains(language.code),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _targetLanguageCodes.add(language.code);
                      } else {
                        _targetLanguageCodes.remove(language.code);
                      }
                    }),
                  );
                },
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(
                apiErrorMessage(_submitError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create session'),
            ),
          ],
        ),
      ),
    );
  }
}
