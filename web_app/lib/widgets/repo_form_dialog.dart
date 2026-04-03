import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_models/launcher_models.dart';

/// Dialog for adding or editing a CatalogRepo.
/// Returns the updated/new [CatalogRepo], or null if cancelled.
Future<CatalogRepo?> showRepoFormDialog(
  BuildContext context, {
  CatalogRepo? existing,
  List<String> templateNames = const [],
}) async {
  return showDialog<CatalogRepo>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RepoFormDialog(
      existing: existing,
      templateNames: templateNames,
    ),
  );
}

class _RepoFormDialog extends StatefulWidget {
  const _RepoFormDialog({
    this.existing,
    required this.templateNames,
  });

  final CatalogRepo? existing;
  final List<String> templateNames;

  @override
  State<_RepoFormDialog> createState() => _RepoFormDialogState();
}

class _RepoFormDialogState extends State<_RepoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _tagsCtrl;
  late bool _required;
  late String? _selectedTemplate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final repo = widget.existing;
    _nameCtrl = TextEditingController(text: repo?.name ?? '');
    _urlCtrl = TextEditingController(text: repo?.url ?? '');
    _tagsCtrl = TextEditingController(text: repo?.tags.join(', ') ?? '');
    _required = repo?.required ?? false;
    _selectedTemplate = repo?.envTemplateName;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final repo = CatalogRepo(
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      required: _required,
      tags: tags,
      envTemplateName: _selectedTemplate,
    );
    Navigator.of(context).pop(repo);
  }

  @override
  Widget build(BuildContext context) {
    final templateOptions = [
      const UkOption<String?>('None', null),
      ...widget.templateNames.map((t) => UkOption<String?>(t, t)),
    ];

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Repo' : 'Add Repo'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UkTextField(
                controller: _nameCtrl,
                label: 'Repo Name',
                hint: 'e.g. api-gateway',
                enabled: !_isEdit,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              UkTextField(
                controller: _urlCtrl,
                label: 'URL',
                hint: 'https://github.com/acme/api-gateway',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'URL is required' : null,
              ),
              const SizedBox(height: 12),
              UkTextField(
                controller: _tagsCtrl,
                label: 'Tags',
                hint: 'backend, required (comma-separated)',
              ),
              const SizedBox(height: 12),
              UkSelect<String?>(
                label: 'Env Template',
                options: templateOptions,
                value: _selectedTemplate,
                onChanged: (v) => setState(() => _selectedTemplate = v),
              ),
              const SizedBox(height: 16),
              UkSwitch(
                value: _required,
                label: 'Required for all members',
                onChanged: (v) => setState(() => _required = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        UkButton(
          label: 'Cancel',
          variant: UkButtonVariant.outline,
          size: UkButtonSize.small,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        const SizedBox(width: 8),
        UkButton(
          label: _isEdit ? 'Save Changes' : 'Add Repo',
          size: UkButtonSize.small,
          onPressed: _submit,
        ),
      ],
    );
  }
}
