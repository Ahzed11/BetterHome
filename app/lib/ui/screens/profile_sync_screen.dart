import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

class ProfileSyncScreen extends StatefulWidget {
  const ProfileSyncScreen({
    super.key,
    required this.session,
    required this.onSynced,
    this.onUseDemo,
  });

  final AppSession session;
  final VoidCallback onSynced;
  final VoidCallback? onUseDemo;

  @override
  State<ProfileSyncScreen> createState() => _ProfileSyncScreenState();
}

class _ProfileSyncScreenState extends State<ProfileSyncScreen> {
  final _email = TextEditingController(text: 'demo@betterhome.local');
  final _given = TextEditingController(text: 'Demo');
  final _family = TextEditingController(text: 'User');
  String _language = 'en';

  @override
  void dispose() {
    _email.dispose();
    _given.dispose();
    _family.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.session.syncProfile(
      email: _email.text.trim(),
      givenName: _given.text.trim(),
      familyName: _family.text.trim(),
      language: _language,
      timezone: 'Europe/Paris',
    );
    if (widget.session.profile != null && mounted) {
      widget.onSynced();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncProfileTitle)),
      body: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            children: [
              Text(l10n.syncProfileSubtitle),
              const SizedBox(height: AppTokens.spaceLg),
              TextField(
                controller: _email,
                decoration: InputDecoration(labelText: l10n.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: _given,
                decoration: InputDecoration(labelText: l10n.givenName),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: _family,
                decoration: InputDecoration(labelText: l10n.familyName),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: InputDecoration(labelText: l10n.language),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _language = value);
                  }
                },
              ),
              const SizedBox(height: AppTokens.spaceLg),
              if (widget.session.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
                  child: Text(
                    l10n.errorGeneric,
                    style: AppTypography.label.copyWith(
                      color: AppTokens.overdueText,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: widget.session.busy ? null : _submit,
                child: Text(
                  widget.session.busy ? l10n.loading : l10n.continueLabel,
                ),
              ),
              if (widget.onUseDemo != null) ...[
                const SizedBox(height: AppTokens.spaceMd),
                TextButton(
                  onPressed: widget.onUseDemo,
                  child: Text(l10n.useDemoData),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
