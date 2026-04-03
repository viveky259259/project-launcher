import 'package:flutter/material.dart';
import 'package:launcher_kit/launcher_kit.dart';

/// Shows a simple "Are you sure?" confirmation dialog.
/// Returns true if confirmed, false/null if cancelled.
Future<bool> showConfirmDialog(
  BuildContext context, {
  String title = 'Are you sure?',
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(title),
      content: message != null ? Text(message!) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actions: [
        UkButton(
          label: cancelLabel,
          variant: UkButtonVariant.outline,
          size: UkButtonSize.small,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? cs.error : cs.primary,
            foregroundColor: destructive ? cs.onError : cs.onPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
