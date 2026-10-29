import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/timezones.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/timezone_picker_sheet.dart';
import 'package:flutter/material.dart';

class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  final _name = TextEditingController();
  String _timezone = defaultTimezone;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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
        timezone: _timezone,
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

  Future<void> _pickTimezone() async {
    final picked = await showTimezonePicker(context, current: _timezone);
    if (picked != null && mounted) {
      setState(() => _timezone = picked);
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
          Semantics(
            container: true,
            button: true,
            label: l10n.timezone,
            value: _timezone,
            onTap: _pickTimezone,
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                onTap: _pickTimezone,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.timezone,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(_timezone, style: AppTypography.body),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          if (_error != null)
            Text(
              _error!,
              style: AppTypography.label.copyWith(color: AppTokens.overdueText),
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
