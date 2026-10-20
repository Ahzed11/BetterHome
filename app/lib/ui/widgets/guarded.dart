import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/ui/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// Runs [action] and shows a toast when a request fails, so a failure is never silent.
/// Returns whether the action finished without failing.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  final message = AppLocalizations.of(context).errorGeneric;
  try {
    await action();
    return true;
  } on ApiException catch (_) {
    if (context.mounted) {
      showAppToast(context, message: message, error: true);
    }
    return false;
  }
}
