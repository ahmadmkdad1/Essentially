import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? AppColors.danger : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

void showErrorSnack(BuildContext context, Object error) => showSnack(context, describeError(error), error: true);

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style:
                  destructive
                      ? FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: const Color(0xFF2B0A0A),
                        minimumSize: const Size(0, 44),
                      )
                      : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
  );
  return result ?? false;
}

/// Asks for a short text (e.g. a rejection reason). Returns null on cancel.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String? message,
  String confirmLabel = 'Submit',
  bool required = true,
  int minLength = 3,
  bool destructive = false,
}) {
  return showDialog<String>(
    context: context,
    builder:
        (context) => _PromptDialog(
          title: title,
          label: label,
          message: message,
          confirmLabel: confirmLabel,
          required: required,
          minLength: minLength,
          destructive: destructive,
        ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.required,
    required this.minLength,
    required this.destructive,
    this.message,
  });

  final String title;
  final String label;
  final String? message;
  final String confirmLabel;
  final bool required;
  final int minLength;
  final bool destructive;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: 16)],
              TextFormField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                maxLength: 1000,
                decoration: InputDecoration(labelText: widget.label, alignLabelWithHint: true),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (!widget.required && text.isEmpty) return null;
                  if (text.length < widget.minLength) {
                    return 'Please write at least ${widget.minLength} characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style:
              widget.destructive
                  ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: const Color(0xFF2B0A0A),
                    minimumSize: const Size(0, 44),
                  )
                  : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
