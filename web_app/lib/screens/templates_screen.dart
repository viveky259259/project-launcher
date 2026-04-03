import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_models/launcher_models.dart';
import '../services/admin_api.dart';
import '../widgets/admin_navbar.dart';
import '../widgets/confirm_dialog.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  Catalog? _catalog;
  bool _loading = true;
  String? _error;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await AdminApi.getCatalog();
      setState(() {
        _catalog = catalog;
        _loading = false;
      });
    } catch (e) {
      if (e is AdminApiException && e.statusCode == 404) {
        setState(() {
          _catalog = Catalog(version: '0.1.0', githubOrg: AdminApi.orgSlug, repos: [], envTemplates: []);
          _loading = false;
        });
      } else {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _addTemplate() async {
    final result = await _showTemplateDialog();
    if (result == null) return;
    setState(() {
      _catalog = _catalog?.copyWith(
        envTemplates: [...?_catalog?.envTemplates, result],
      );
    });
  }

  Future<void> _editTemplate(EnvTemplate template) async {
    final result = await _showTemplateDialog(existing: template);
    if (result == null) return;
    setState(() {
      final templates = _catalog?.envTemplates
              .map((t) => t == template ? result : t)
              .toList() ??
          [];
      _catalog = _catalog?.copyWith(envTemplates: templates);
    });
  }

  Future<void> _deleteTemplate(EnvTemplate template) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete template "${template.name}"?',
      message:
          'Repos referencing this template will lose their env configuration.',
    );
    if (!confirmed) return;
    setState(() {
      final templates =
          _catalog?.envTemplates.where((t) => t != template).toList() ?? [];
      _catalog = _catalog?.copyWith(envTemplates: templates);
    });
  }

  Future<EnvTemplate?> _showTemplateDialog({EnvTemplate? existing}) {
    return showDialog<EnvTemplate>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TemplateFormDialog(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminNavbar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Failed to load templates: $_error'),
          const SizedBox(height: 16),
          UkButton(label: 'Retry', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final templates = _catalog?.envTemplates ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Env Templates (${templates.length})',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              UkButton(
                label: '+ Add Template',
                size: UkButtonSize.small,
                icon: Icons.add_rounded,
                onPressed: _addTemplate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: templates.isEmpty
                ? Center(
                    child: Text(
                      'No env templates yet.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final t = templates[i];
                      final isExpanded = _expanded.contains(t.name);
                      return _TemplateCard(
                        template: t,
                        isExpanded: isExpanded,
                        onToggle: () => setState(() {
                          if (isExpanded) {
                            _expanded.remove(t.name);
                          } else {
                            _expanded.add(t.name);
                          }
                        }),
                        onEdit: () => _editTemplate(t),
                        onDelete: () => _deleteTemplate(t),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isExpanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final EnvTemplate template;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.description_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  UkBadge(
                    '${template.vars.length} vars',
                    variant: UkBadgeVariant.neutral,
                  ),
                  const SizedBox(width: 12),
                  UkButton(
                    label: 'Edit',
                    variant: UkButtonVariant.outline,
                    size: UkButtonSize.small,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: cs.error, size: 18),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.3)),
            ...template.vars.entries.map(
              (e) => _VarRow(name: e.key, envVar: e.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _VarRow extends StatelessWidget {
  const _VarRow({required this.name, required this.envVar});

  final String name;
  final EnvVar envVar;

  Color _typeColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (envVar.type) {
      'ask' => cs.error,
      'vault' => cs.tertiary,
      _ => cs.primary,
    };
  }

  String get _displayValue {
    return switch (envVar.type) {
      'ask' => '(required — user must enter)',
      'vault' => envVar.vaultPath ?? '',
      _ => envVar.value ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _typeColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: cs.onSurface,
                  ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                envVar.type,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: typeColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              _displayValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: envVar.type != 'ask' ? 'monospace' : null,
                    fontStyle:
                        envVar.type == 'ask' ? FontStyle.italic : null,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template form dialog
// ---------------------------------------------------------------------------

class _TemplateFormDialog extends StatefulWidget {
  const _TemplateFormDialog({this.existing});

  final EnvTemplate? existing;

  @override
  State<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends State<_TemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late List<_VarEntry> _vars;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _vars = widget.existing?.vars.entries
            .map((e) => _VarEntry.fromEnvVar(e.key, e.value))
            .toList() ??
        [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final v in _vars) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVar() {
    setState(() => _vars.add(_VarEntry()));
  }

  void _removeVar(int i) {
    setState(() {
      _vars[i].dispose();
      _vars.removeAt(i);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final vars = <String, EnvVar>{};
    for (final v in _vars) {
      final key = v.keyCtrl.text.trim();
      if (key.isEmpty) continue;
      vars[key] = EnvVar(
        type: v.type,
        value: v.type == 'default' ? v.valueCtrl.text.trim() : null,
        vaultPath: v.type == 'vault' ? v.valueCtrl.text.trim() : null,
      );
    }

    final template = EnvTemplate(
      name: _nameCtrl.text.trim(),
      vars: vars,
    );
    Navigator.of(context).pop(template);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Template' : 'Add Template'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UkTextField(
                controller: _nameCtrl,
                label: 'Template Name',
                hint: 'e.g. api-gateway',
                enabled: !_isEdit,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Variables',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  UkButton(
                    label: '+ Add Var',
                    variant: UkButtonVariant.text,
                    size: UkButtonSize.small,
                    onPressed: _addVar,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < _vars.length; i++)
                        _VarFormRow(
                          entry: _vars[i],
                          onRemove: () => _removeVar(i),
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
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
          label: _isEdit ? 'Save' : 'Create',
          size: UkButtonSize.small,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _VarEntry {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;
  String type; // 'ask' | 'default' | 'vault'

  _VarEntry()
      : keyCtrl = TextEditingController(),
        valueCtrl = TextEditingController(),
        type = 'default';

  factory _VarEntry.fromEnvVar(String key, EnvVar envVar) {
    final e = _VarEntry();
    e.keyCtrl.text = key;
    e.valueCtrl.text = envVar.value ?? envVar.vaultPath ?? '';
    e.type = envVar.type;
    return e;
  }

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _VarFormRow extends StatelessWidget {
  const _VarFormRow({
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  final _VarEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: UkTextField(
              controller: entry.keyCtrl,
              label: 'Key',
              hint: 'DATABASE_URL',
              size: UkFieldSize.small,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: UkSelect<String>(
              label: 'Type',
              options: const [
                UkOption('default', 'default'),
                UkOption('ask', 'ask'),
                UkOption('vault', 'vault'),
              ],
              value: entry.type,
              size: UkFieldSize.small,
              onChanged: (v) {
                if (v != null) {
                  entry.type = v;
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: UkTextField(
              controller: entry.valueCtrl,
              label: entry.type == 'vault' ? 'Vault Path' : 'Default Value',
              hint: entry.type == 'vault'
                  ? 'acme/api-key'
                  : entry.type == 'ask'
                      ? '(user will be prompted)'
                      : 'redis://localhost:6379',
              size: UkFieldSize.small,
              enabled: entry.type != 'ask',
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.remove_circle_outline_rounded,
                color: cs.error, size: 18),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 48),
          ),
        ],
      ),
    );
  }
}
