import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Runs [action] and shows a snackbar when a request fails, so a failure is never silent.
/// Returns whether the action finished without failing.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).errorGeneric;
  try {
    await action();
    return true;
  } on ApiException catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}
