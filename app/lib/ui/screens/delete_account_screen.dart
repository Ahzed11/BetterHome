import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Explains what deleting the account does and, after a confirmation, deletes it.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.session,
    required this.onDeleted,
  });

  final AppSession session;

  /// Called once the account is deleted, after this screen has closed.
  final VoidCallback onDeleted;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _busy = false;
  String? _error;

  Future<bool> _confirm(AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(AppLocalizations l10n) async {
    if (!await _confirm(l10n)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.repository.deleteMyAccount();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.statusCode == 409
              ? l10n.deleteAccountSoleAdmin
              : l10n.errorGeneric;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccount)),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        children: [
          Text(l10n.deleteAccountIntro),
          const SizedBox(height: AppTokens.spaceMd),
          Text(l10n.deleteAccountHistory),
          const SizedBox(height: AppTokens.spaceLg),
          if (_error != null) ...[
            Text(
              _error!,
              style: AppTypography.label.copyWith(color: AppTokens.overdueText),
            ),
            const SizedBox(height: AppTokens.spaceMd),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.overdueText,
              minimumSize: const Size(0, AppTokens.minTapTarget),
            ),
            onPressed: _busy ? null : () => _delete(l10n),
            child: Text(_busy ? l10n.loading : l10n.deleteAccount),
          ),
        ],
      ),
    );
  }
}
