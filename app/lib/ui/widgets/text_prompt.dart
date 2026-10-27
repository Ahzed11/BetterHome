import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Asks for one line of text. Returns the trimmed text, or null when cancelled or left blank.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTokens.card,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  return text == null || text.isEmpty ? null : text;
}
