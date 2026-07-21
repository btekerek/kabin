import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_error_message.dart';
import '../../../core/widgets/kabin_app_bar_title.dart';
import '../../../core/widgets/profile_menu.dart';
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
  // Description isn't sent anywhere yet - the API doesn't have a field for
  // it. Collecting it in the UI now so the form's finished; wiring it up
  // is one of the deferred backend-branch items.
  final _descriptionController = TextEditingController();

  // Single-select in practice (the sheet enforces at most one code here),
  // but kept as a Set so both fields can share the same picker sheet and
  // the same "mutate this set in place" pattern.
  final Set<String> _sourceLanguageCodes = {};
  final Set<String> _targetLanguageCodes = {};

  bool _submitting = false;
  Object? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceLanguageCodes.isEmpty) {
      setState(() => _submitError = 'Pick a source language.');
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
            sourceLanguage: _sourceLanguageCodes.first,
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

  /// Opens the near-fullscreen picker sheet. It mutates [selectedCodes]
  /// directly (same Set instance) as rows are tapped/checked, so however
  /// it gets dismissed - a single-select tap, the OK button, keyboard
  /// done, drag down, tapping outside - whatever's in the set when it
  /// closes is what sticks. We only need one setState afterwards, to
  /// refresh the summary field/chips on this screen.
  Future<void> _openLanguagePicker({
    required String title,
    required List<Language> languages,
    required Set<String> selectedCodes,
    required bool multiSelect,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LanguagePickerSheet(
        title: title,
        languages: languages,
        selectedCodes: selectedCodes,
        multiSelect: multiSelect,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final languagesAsync = ref.watch(languagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const KabinAppBarTitle('New session'),
        actions: const [ProfileMenu(), SizedBox(width: 4)],
      ),
      body: languagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error))),
        data: (languages) => _buildForm(languages),
      ),
    );
  }

  Widget _buildForm(List<Language> languages) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                _LanguagePickerField(
                  labelText: 'Source language',
                  languages: languages,
                  selectedCodes: _sourceLanguageCodes,
                  onTap: () => _openLanguagePicker(
                    title: 'Source language',
                    languages: languages,
                    selectedCodes: _sourceLanguageCodes,
                    multiSelect: false,
                  ),
                ),
                const SizedBox(height: 16),
                _LanguagePickerField(
                  labelText: 'Target languages',
                  languages: languages,
                  selectedCodes: _targetLanguageCodes,
                  onTap: () => _openLanguagePicker(
                    title: 'Target languages',
                    languages: languages,
                    selectedCodes: _targetLanguageCodes,
                    multiSelect: true,
                  ),
                ),
                if (_targetLanguageCodes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final language in languages)
                        if (_targetLanguageCodes.contains(language.code))
                          InputChip(
                            label: Text(language.name),
                            onDeleted: () => setState(() =>
                                _targetLanguageCodes.remove(language.code)),
                          ),
                    ],
                  ),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    apiErrorMessage(_submitError!),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
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
                      : const Text('CREATE SESSION'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tappable "field" both language pickers show on the form itself -
/// styled exactly like a normal outlined input (same decoration as
/// Session name/Description above it), but read-only: tapping opens the
/// near-fullscreen picker sheet instead of a keyboard.
class _LanguagePickerField extends StatelessWidget {
  const _LanguagePickerField({
    required this.labelText,
    required this.languages,
    required this.selectedCodes,
    required this.onTap,
  });

  final String labelText;
  final List<Language> languages;
  final Set<String> selectedCodes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedNames = [
      for (final language in languages)
        if (selectedCodes.contains(language.code)) language.name,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedNames.isEmpty ? 'Search language' : selectedNames.join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: selectedNames.isEmpty
              ? TextStyle(
                  color:
                      Theme.of(context).inputDecorationTheme.hintStyle?.color)
              : null,
        ),
      ),
    );
  }
}

/// Near-fullscreen picker sheet shared by both the source and target
/// language fields, so they look and behave identically apart from one
/// thing: single-select (source) closes the sheet the moment a row is
/// tapped, multi-select (target) leaves it open with checkboxes so
/// several languages can be picked in one go, closed via the OK button
/// pinned to the bottom, the keyboard's done action, or a swipe-down.
///
/// Mutates [selectedCodes] in place as rows are picked/checked - see
/// _openLanguagePicker above for why that's simpler than threading a
/// return value through every possible dismiss path.
class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.title,
    required this.languages,
    required this.selectedCodes,
    required this.multiSelect,
  });

  final String title;
  final List<Language> languages;
  final Set<String> selectedCodes;
  final bool multiSelect;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectSingle(Language language) {
    widget.selectedCodes
      ..clear()
      ..add(language.code);
    Navigator.of(context).pop();
  }

  void _toggleMulti(Language language, bool checked) {
    setState(() {
      if (checked) {
        widget.selectedCodes.add(language.code);
      } else {
        widget.selectedCodes.remove(language.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.languages
        : widget.languages
            .where((language) => language.name.toLowerCase().contains(_query))
            .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (widget.multiSelect)
                    Text(
                      '${widget.selectedCodes.length} selected',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Search language',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                onSubmitted: (_) => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final language = filtered[index];
                  final selected = widget.selectedCodes.contains(language.code);
                  if (widget.multiSelect) {
                    return CheckboxListTile(
                      title: Text(language.name),
                      value: selected,
                      onChanged: (checked) =>
                          _toggleMulti(language, checked ?? false),
                    );
                  }
                  return ListTile(
                    title: Text(language.name),
                    trailing: selected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => _selectSingle(language),
                  );
                },
              ),
            ),
            if (widget.multiSelect)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
