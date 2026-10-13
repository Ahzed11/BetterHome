import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  final _name = TextEditingController();
  final _timezone = TextEditingController(text: 'Europe/Paris');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _timezone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final household = await widget.session.repository.createHousehold(
        name: _name.text.trim(),
        timezone: _timezone.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(household);
      }
    } on ApiException {
      setState(() => _error = AppLocalizations.of(context).errorGeneric);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createHousehold)),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.householdName),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          TextField(
            controller: _timezone,
            decoration: InputDecoration(labelText: l10n.timezone),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? l10n.loading : l10n.save),
          ),
        ],
      ),
    );
  }
}
