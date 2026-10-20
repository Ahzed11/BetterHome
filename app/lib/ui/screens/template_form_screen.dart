import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/chore_form_sections.dart';
import 'package:flutter/material.dart';

/// The editable fields of a chore template, as entered in [TemplateFormScreen].
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

/// The admin screen that creates a chore template, or edits [template], in the look of the
/// design's "New recurring chore" board without its schedule and assignment. Pops with a
/// [TemplateDraft] when saved, with nothing when cancelled. The server stays the authority on
/// the rules; the steppers only keep obvious mistakes out.
class TemplateFormScreen extends StatefulWidget {
  const TemplateFormScreen({super.key, this.template});

  final TaskTemplate? template;

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  late final _title = TextEditingController(text: widget.template?.title);
  late final _notes = TextEditingController(text: widget.template?.description);
  late final List<String> _emojis = _choices();
  late int _emoji = _emojis.indexOf(widget.template?.emoji ?? _emojis.first);
  late int _points = (widget.template?.points ?? 10).clamp(1, maxChorePoints);
  late int _late = (widget.template?.latePoints ?? 5).clamp(0, _points);

  /// The shared icons, plus the template's own when it is not one of them.
  List<String> _choices() {
    final own = widget.template?.emoji;
    return [
      if (own != null && own.isNotEmpty && !choreEmojis.contains(own)) own,
      ...choreEmojis,
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      TemplateDraft(
        title: _title.text.trim(),
        emoji: _emojis[_emoji],
        description: _notes.text.trim(),
        points: _points,
        latePoints: _late,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.template != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminsOnly, style: AppTypography.label),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          0,
          AppTokens.spaceMd,
          AppTokens.spaceLg,
        ),
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              editing ? l10n.editTemplate : l10n.createTemplate,
              style: AppTypography.display.copyWith(fontSize: 30),
            ),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(l10n.templateFormSubtitle, style: AppTypography.bodyMuted),
          const SizedBox(height: AppTokens.spaceMd),
          ChoreDetailsCard(
            emoji: _emojis[_emoji],
            onNextEmoji: () =>
                setState(() => _emoji = (_emoji + 1) % _emojis.length),
            title: _title,
            notes: _notes,
            onTitleChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          PointsSection(
            points: _points,
            latePoints: _late,
            onChanged: (points, late) => setState(() {
              _points = points;
              _late = late;
            }),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Row(
            spacing: AppTokens.spaceSm + 2,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: _title.text.trim().isEmpty ? null : _save,
                  child: Text(l10n.saveTemplate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
