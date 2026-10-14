import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shows [message] with an Undo button for [window] and runs [action] only when the window passes
/// without the person undoing. Nothing has happened yet while the message is up, so undoing
/// leaves no trace. [action] still runs when the screen is left within the window.
///
/// Returns whether [action] ran and finished without failing; a failure shows a snackbar.
Future<bool> runUnlessUndone(
  BuildContext context, {
  required String message,
  required Future<void> Function() action,
  Duration window = const Duration(seconds: 5),
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final closed = await messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: window,
          persist: false,
          action: SnackBarAction(label: l10n.undo, onPressed: () {}),
        ),
      )
      .closed;
  if (closed == SnackBarClosedReason.action) {
    return false;
  }
  try {
    await action();
    return true;
  } on ApiException catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    return false;
  }
}
