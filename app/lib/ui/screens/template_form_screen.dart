import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/chore_form_sections.dart';
import 'package:betterhome/ui/widgets/emoji_picker_sheet.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/recurrence_sections.dart';
import 'package:flutter/material.dart';

/// How a chore comes back: the schedule and who does it.
class RecurrenceDraft {
  const RecurrenceDraft({
    required this.rrule,
    required this.assignmentMode,
    this.fixedAssigneeId,
    this.startsAt,
  });

  final String rrule;
  final AssignmentMode assignmentMode;
  final String? fixedAssigneeId;

  /// The start of the recurrence being edited; null for a new one (it starts now).
  final DateTime? startsAt;
}

/// The fields of a chore template, as entered in [TemplateFormScreen], and its recurrence when
/// the chore repeats.
class TemplateDraft {
  const TemplateDraft({
    required this.title,
    required this.emoji,
    required this.description,
    required this.points,
    required this.latePoints,
    this.recurrence,
  });

  final String title;
  final String emoji;
  final String description;
  final int points;
  final int latePoints;
  final RecurrenceDraft? recurrence;
}

/// Saves [draft] as a new template, or as the changes to [template], and its recurrence when it
/// has one. Returns whether everything was saved; a failure shows a toast.
Future<bool> saveTemplateDraft(
  BuildContext context,
  AppSession session,
  String householdId,
  TemplateDraft draft, {
  TaskTemplate? template,
}) {
  final tasks = session.tasksRepository;
  return runGuarded(context, () async {
    final saved = template == null
        ? await tasks.createTemplate(
            householdId: householdId,
            title: draft.title,
            emoji: draft.emoji.isEmpty ? null : draft.emoji,
            description: draft.description,
            points: draft.points,
            latePoints: draft.latePoints,
          )
        : await tasks.updateTemplate(
            householdId: householdId,
            templateId: template.id,
            title: draft.title,
            emoji: draft.emoji,
            description: draft.description,
            points: draft.points,
            latePoints: draft.latePoints,
          );
    final recurrence = draft.recurrence;
    if (recurrence != null) {
      await tasks.upsertRecurrence(
        householdId: householdId,
        templateId: saved.id,
        rrule: recurrence.rrule,
        assignmentMode: recurrence.assignmentMode,
        fixedAssigneeId: recurrence.fixedAssigneeId,
        startsAt:
            recurrence.startsAt ??
            DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
    }
  });
}

/// The admin screen of the design's "New recurring chore" board: it creates a chore template, or
/// edits [template], and says whether the chore repeats and how often. Pops with a
/// [TemplateDraft] when saved, with nothing when cancelled. [startRecurring] opens it with the
/// repeat switch on. The server stays the authority on the rules; the controls only keep
/// obvious mistakes out.
class TemplateFormScreen extends StatefulWidget {
  const TemplateFormScreen({
    super.key,
    required this.session,
    required this.householdId,
    this.template,
    this.startRecurring = false,
  });

  final AppSession session;
  final String householdId;
  final TaskTemplate? template;
  final bool startRecurring;

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  static const _defaultEmoji = '🧹';

  late final _title = TextEditingController(text: widget.template?.title);
  late final _notes = TextEditingController(text: widget.template?.description);
  late String _emoji = widget.template == null
      ? _defaultEmoji
      : widget.template?.emoji ?? '';
  late int _points = (widget.template?.points ?? 10).clamp(1, maxChorePoints);
  late int _late = (widget.template?.latePoints ?? 5).clamp(0, _points);
  final _recurrence = RecurrenceController();
  late bool _repeats = widget.startRecurring;

  /// Whether the template already has a recurrence: it can then be changed but not turned off.
  bool _hasRecurrence = false;
  late final Future<List<Membership>> _members = widget.session.repository
      .listMembers(widget.householdId);

  @override
  void initState() {
    super.initState();
    _recurrence.addListener(() => setState(() {}));
    final template = widget.template;
    if (template != null) {
      _loadRecurrence(template);
    }
  }

  Future<void> _loadRecurrence(TaskTemplate template) async {
    final existing = await widget.session.tasksRepository.getRecurrence(
      widget.householdId,
      template.id,
    );
    if (existing == null || !mounted) {
      return;
    }
    _recurrence.load(existing);
    setState(() {
      _repeats = true;
      _hasRecurrence = true;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _recurrence.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && (!_repeats || _recurrence.valid);

  Future<void> _pickEmoji() async {
    final picked = await showEmojiPicker(context, current: _emoji);
    if (picked != null) {
      setState(() => _emoji = picked);
    }
  }

  void _save() {
    Navigator.of(context).pop(
      TemplateDraft(
        title: _title.text.trim(),
        emoji: _emoji,
        description: _notes.text.trim(),
        points: _points,
        latePoints: _late,
        recurrence: _repeats
            ? RecurrenceDraft(
                rrule: _recurrence.rrule,
                assignmentMode: _recurrence.rotation
                    ? AssignmentMode.roundRobin
                    : AssignmentMode.fixed,
                fixedAssigneeId: _recurrence.rotation
                    ? null
                    : _recurrence.fixed,
                startsAt: _recurrence.startsAt,
              )
            : null,
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
            emoji: _emoji,
            onPickEmoji: _pickEmoji,
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
          const SizedBox(height: AppTokens.spaceMd),
          AppCard(
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                ),
                title: Text(
                  l10n.recurringToggleTitle,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n.recurringToggleHint,
                  style: AppTypography.eyebrow.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                value: _repeats,
                onChanged: _hasRecurrence
                    ? null
                    : (value) => setState(() => _repeats = value),
              ),
            ),
          ),
          if (_repeats) ...[
            const SizedBox(height: AppTokens.spaceMd),
            RecurrenceSections(
              controller: _recurrence,
              members: _members,
              meId: widget.session.profile?.id,
            ),
          ],
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
                  onPressed: _valid ? _save : null,
                  child: Text(l10n.saveChore),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
