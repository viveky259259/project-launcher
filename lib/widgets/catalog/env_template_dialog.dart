import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';
import 'package:launcher_models/launcher_models.dart';
import 'package:launcher_theme/launcher_theme.dart';

import '../../services/catalog_service.dart';

/// Dialog that collects values for "ask" variables in an [EnvTemplate] and
/// then writes the resulting `.env` file via [CatalogService.instance.applyEnvTemplate].
///
/// Usage:
/// ```dart
/// final applied = await showDialog<bool>(
///   context: context,
///   builder: (_) => EnvTemplateDialog(
///     repoPath: '/path/to/cloned/repo',
///     template: template,
///   ),
/// );
/// ```
///
/// Returns `true` when the template was applied, `false` / `null` when
/// cancelled.
class EnvTemplateDialog extends StatefulWidget {
  const EnvTemplateDialog({
    super.key,
    required this.repoPath,
    required this.template,
  });

  /// Absolute path to the cloned repo directory.
  final String repoPath;

  /// The env template to apply.
  final EnvTemplate template;

  @override
  State<EnvTemplateDialog> createState() => _EnvTemplateDialogState();
}

class _EnvTemplateDialogState extends State<EnvTemplateDialog> {
  final _formKey = GlobalKey<FormState>();

  /// Controller for each editable variable (type=ask and type=default).
  late final Map<String, TextEditingController> _controllers;

  bool _isApplying = false;
  String? _errorMessage;
  String? _warningMessage;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (final entry in widget.template.vars.entries) {
      final name = entry.key;
      final envVar = entry.value;
      if (envVar.type == 'default' || envVar.type == 'ask') {
        _controllers[name] = TextEditingController(
          text: envVar.type == 'default' ? (envVar.value ?? '') : '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isApplying = true;
      _errorMessage = null;
      _warningMessage = null;
    });

    // Collect user values (ask + user-edited default vars)
    final userValues = <String, String>{};
    for (final entry in _controllers.entries) {
      userValues[entry.key] = entry.value.text.trim();
    }

    // Remove default-type vars from userValues so applyEnvTemplate uses its
    // template value path — but since the user may have edited the field we
    // pass all values in and handle defaults ourselves:
    // We rebuild the template substituting default values with what the user
    // typed (they may have changed it).
    final mergedUserValues = <String, String>{};
    for (final entry in widget.template.vars.entries) {
      final name = entry.key;
      final envVar = entry.value;
      if (envVar.type == 'ask') {
        mergedUserValues[name] = _controllers[name]?.text.trim() ?? '';
      }
      // For type=default, build an overridden template with the user value
    }

    // Build a patched template where default values reflect what the user typed
    final patchedVars = Map<String, EnvVar>.from(widget.template.vars);
    for (final name in _controllers.keys) {
      final envVar = widget.template.vars[name]!;
      if (envVar.type == 'default') {
        patchedVars[name] = envVar.copyWith(
          value: _controllers[name]!.text.trim(),
        );
      }
    }
    final patchedTemplate = widget.template.copyWith(vars: patchedVars);

    try {
      await CatalogService.instance.applyEnvTemplate(
        widget.repoPath,
        patchedTemplate,
        mergedUserValues,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      log('EnvTemplateDialog._apply error: $e');
      // Check if the service warned about .env.new
      final msg = e.toString();
      if (msg.contains('.env.new')) {
        setState(() {
          _isApplying = false;
          _warningMessage =
              '.env already existed — values written to .env.new instead.';
        });
        // Still counts as success for the caller
        if (mounted) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _isApplying = false;
          _errorMessage = msg.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skin = AppSkin.maybeOf(context);
    final accentColor = skin?.colors.accent ?? cs.primary;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              _Header(
                templateName: widget.template.name,
                accentColor: accentColor,
                cs: cs,
              ),

              // ── Scrollable variable list ─────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fill in the required values for this repo\'s .env:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      ...widget.template.vars.entries.map(
                        (entry) => _VarRow(
                          name: entry.key,
                          envVar: entry.value,
                          controller: _controllers[entry.key],
                          accentColor: accentColor,
                          cs: cs,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        UkAlert(
                          message: _errorMessage!,
                          type: UkAlertType.danger,
                          dismissible: false,
                        ),
                      ],
                      if (_warningMessage != null) ...[
                        const SizedBox(height: 12),
                        UkAlert(
                          message: _warningMessage!,
                          type: UkAlertType.warning,
                          dismissible: false,
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Footer buttons ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    UkButton(
                      label: 'Cancel',
                      variant: UkButtonVariant.outline,
                      onPressed: _isApplying
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 12),
                    UkButton(
                      label: _isApplying ? 'Applying...' : 'Apply .env',
                      variant: UkButtonVariant.primary,
                      icon: _isApplying ? null : Icons.check_rounded,
                      onPressed: _isApplying ? null : _apply,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.templateName,
    required this.accentColor,
    required this.cs,
  });

  final String templateName;
  final Color accentColor;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              Icons.settings_input_component_rounded,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply Env Template',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  templateName,
                  style: AppTypography.mono(
                    fontSize: 12,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
            style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _VarRow extends StatelessWidget {
  const _VarRow({
    required this.name,
    required this.envVar,
    required this.controller,
    required this.accentColor,
    required this.cs,
  });

  final String name;
  final EnvVar envVar;
  final TextEditingController? controller;
  final Color accentColor;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (envVar.type) {
        'vault' => _VaultRow(
            name: name,
            vaultPath: envVar.vaultPath ?? name,
            cs: cs,
          ),
        'ask' => _EditableRow(
            name: name,
            controller: controller!,
            isRequired: true,
            placeholder: name,
            helperText: null,
            accentColor: accentColor,
            cs: cs,
          ),
        _ /* default */ => _EditableRow(
            name: name,
            controller: controller!,
            isRequired: false,
            placeholder: name,
            helperText: envVar.value != null && envVar.value!.isNotEmpty
                ? 'default: ${envVar.value}'
                : null,
            accentColor: accentColor,
            cs: cs,
          ),
      },
    );
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.name,
    required this.controller,
    required this.isRequired,
    required this.placeholder,
    required this.helperText,
    required this.accentColor,
    required this.cs,
  });

  final String name;
  final TextEditingController controller;
  final bool isRequired;
  final String placeholder;
  final String? helperText;
  final Color accentColor;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: AppTypography.mono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 2),
          Text(
            helperText!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 6),
        UkTextField(
          controller: controller,
          hint: placeholder,
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty)
                  ? '$name is required'
                  : null
              : null,
          size: UkFieldSize.medium,
        ),
      ],
    );
  }
}

class _VaultRow extends StatelessWidget {
  const _VaultRow({
    required this.name,
    required this.vaultPath,
    required this.cs,
  });

  final String name;
  final String vaultPath;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: AppTypography.mono(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pull from Vault: $vaultPath',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
