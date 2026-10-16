import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The editable fields of a chore template, as typed in [showTemplateForm].
class TemplateDraft {
  const TemplateDraft({
    required this.title,
    required this.emoji,
    required this.description,
    required this.points,
    required this.latePoints,
  });

  final String title;
  final String emoji;
  final String description;
  final int points;
  final int latePoints;
}

/// Asks for the fields of a template, prefilled from [template] when editing. Returns null when
/// cancelled. The server stays the authority on the rules; this only keeps obvious mistakes out.
Future<TemplateDraft?> showTemplateForm(
  BuildContext context, {
  TaskTemplate? template,
}) {
  return showDialog<TemplateDraft>(
    context: context,
    builder: (context) => _TemplateForm(template: template),
  );
}

class _TemplateForm extends StatefulWidget {
  const _TemplateForm({this.template});

  final TaskTemplate? template;

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<_TemplateForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.template?.title);
  late final _emoji = TextEditingController(text: widget.template?.emoji);
  late final _description = TextEditingController(
    text: widget.template?.description,
  );
  late final _points = TextEditingController(
    text: '${widget.template?.points ?? 5}',
  );
  late final _latePoints = TextEditingController(
    text: '${widget.template?.latePoints ?? 2}',
  );

  @override
  void dispose() {
    _title.dispose();
    _emoji.dispose();
    _description.dispose();
    _points.dispose();
    _latePoints.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    Navigator.pop(
      context,
      TemplateDraft(
        title: _title.text.trim(),
        emoji: _emoji.text.trim(),
        description: _description.text.trim(),
        points: int.parse(_points.text.trim()),
        latePoints: int.parse(_latePoints.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? number(String? value) {
      final parsed = int.tryParse(value?.trim() ?? '');
      return parsed == null || parsed < 0 ? l10n.templateNumberInvalid : null;
    }

    return AlertDialog(
      title: Text(
        widget.template == null ? l10n.addTemplate : l10n.editTemplate,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.templateTitle),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.templateTitleRequired
                    : null,
              ),
              const SizedBox(height: AppTokens.spaceSm),
              TextFormField(
                controller: _emoji,
                decoration: InputDecoration(labelText: l10n.templateEmoji),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: l10n.templateDescription,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              TextFormField(
                controller: _points,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.templatePoints),
                validator: number,
              ),
              const SizedBox(height: AppTokens.spaceSm),
              TextFormField(
                controller: _latePoints,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.templateLatePoints),
                validator: number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
