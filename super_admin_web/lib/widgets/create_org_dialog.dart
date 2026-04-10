import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import '../services/super_admin_api.dart';

/// Shows a dialog to create a new organization.
/// Returns [CreateOrgRequest] if submitted, null if cancelled.
Future<CreateOrgRequest?> showCreateOrgDialog(BuildContext context) async {
  return showDialog<CreateOrgRequest>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _CreateOrgDialog(),
  );
}

class _CreateOrgDialog extends StatefulWidget {
  const _CreateOrgDialog();

  @override
  State<_CreateOrgDialog> createState() => _CreateOrgDialogState();
}

class _CreateOrgDialogState extends State<_CreateOrgDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _slugCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _seatsCtrl;
  late final TextEditingController _githubOrgCtrl;
  String _plan = 'starter';

  @override
  void initState() {
    super.initState();
    _slugCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _seatsCtrl = TextEditingController(text: '10');
    _githubOrgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _nameCtrl.dispose();
    _seatsCtrl.dispose();
    _githubOrgCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final req = CreateOrgRequest(
      slug: _slugCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      plan: _plan,
      seats: int.tryParse(_seatsCtrl.text.trim()) ?? 10,
      githubOrg: _githubOrgCtrl.text.trim(),
    );
    Navigator.of(context).pop(req);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Organization'),
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
                controller: _slugCtrl,
                label: 'Slug',
                hint: 'e.g. acme-corp (lowercase, no spaces)',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Slug is required';
                  final slug = v.trim();
                  if (!RegExp(r'^[a-z0-9][a-z0-9\-]*[a-z0-9]$').hasMatch(slug) &&
                      slug.length > 1) {
                    return 'Lowercase alphanumeric and hyphens only';
                  }
                  if (slug.length == 1 && !RegExp(r'^[a-z0-9]$').hasMatch(slug)) {
                    return 'Lowercase alphanumeric and hyphens only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              UkTextField(
                controller: _nameCtrl,
                label: 'Organization Name',
                hint: 'e.g. Acme Corp',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              UkSelect<String>(
                label: 'Plan',
                options: const [
                  UkOption('Starter', 'starter'),
                  UkOption('Pro', 'pro'),
                  UkOption('Enterprise', 'enterprise'),
                ],
                value: _plan,
                onChanged: (v) {
                  if (v != null) setState(() => _plan = v);
                },
              ),
              const SizedBox(height: 12),
              UkTextField(
                controller: _seatsCtrl,
                label: 'Seats',
                hint: 'Number of seats',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Seats required';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              UkTextField(
                controller: _githubOrgCtrl,
                label: 'GitHub Org',
                hint: 'e.g. acme-corp',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'GitHub org is required' : null,
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
          label: 'Create Org',
          size: UkButtonSize.small,
          onPressed: _submit,
        ),
      ],
    );
  }
}
