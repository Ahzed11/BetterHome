import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/ui/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// Shows [message] in a toast with an Undo button for [window] and runs [action] only when the
/// window passes without the person undoing. Nothing has happened yet while the toast is up, so
/// undoing leaves no trace. [action] still runs when the screen is left within the window.
///
/// Returns whether [action] ran and finished without failing; a failure shows a toast.
Future<bool> runUnlessUndone(
  BuildContext context, {
  required String message,
  required Future<void> Function() action,
  Duration window = const Duration(seconds: 5),
}) async {
  final l10n = AppLocalizations.of(context);
  final undone = await showAppToast(
    context,
    message: message,
    actionLabel: l10n.undo,
    duration: window,
  );
  if (undone) {
    return false;
  }
  try {
    await action();
    return true;
  } on ApiException catch (_) {
    if (context.mounted) {
      showAppToast(context, message: l10n.errorGeneric, error: true);
    }
    return false;
  }
}
