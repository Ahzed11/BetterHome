import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/segmented_tabs.dart';
import 'package:betterhome/ui/widgets/stepper_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _Freq { daily, weekly, monthly }

const _emojis = ['🗑️', '🧹', '🍽️', '🧦', '🪴', '🛁', '🧽', '🛒'];
const _byDay = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// The admin-only screen of the design's "New recurring chore" board: it creates a chore template
/// and its recurrence in one go. Pops with `true` once both are saved.
class NewRecurringScreen extends StatefulWidget {
  const NewRecurringScreen({
    super.key,
    required this.session,
    required this.householdId,
  });

  final AppSession session;
  final String householdId;

  @override
  State<NewRecurringScreen> createState() => _NewRecurringScreenState();
}

class _NewRecurringScreenState extends State<NewRecurringScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  int _emoji = 0;
  int _points = 10;
  int _late = 5;
  _Freq _freq = _Freq.weekly;
  int _interval = 1;
  final Set<int> _days = {DateTime.now().weekday - 1};
  bool _rotation = true;
  String? _fixed;
  late final Future<List<Membership>> _members = widget.session.repository
      .listMembers(widget.householdId);
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _rrule {
    final interval = _interval == 1 ? '' : ';INTERVAL=$_interval';
    switch (_freq) {
      case _Freq.daily:
        return 'FREQ=DAILY$interval';
      case _Freq.weekly:
        final days = ([..._days]..sort()).map((d) => _byDay[d]).join(',');
        return 'FREQ=WEEKLY$interval;BYDAY=$days';
      case _Freq.monthly:
        return 'FREQ=MONTHLY$interval;BYMONTHDAY=1';
    }
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && (_rotation || _fixed != null);

  Future<void> _save() async {
    final tasks = widget.session.tasksRepository;
    setState(() => _busy = true);
    final saved = await runGuarded(context, () async {
      final template = await tasks.createTemplate(
        householdId: widget.householdId,
        title: _title.text.trim(),
        emoji: _emojis[_emoji],
        description: _notes.text.trim(),
        points: _points,
        latePoints: _late,
      );
      await tasks.upsertRecurrence(
        householdId: widget.householdId,
        templateId: template.id,
        rrule: _rrule,
        assignmentMode: _rotation
            ? AssignmentMode.roundRobin
            : AssignmentMode.fixed,
        fixedAssigneeId: _rotation ? null : _fixed,
        startsAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
    });
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (saved) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final symbols = DateFormat.EEEE(locale).dateSymbols;
    // Monday first; the symbols start on Sunday.
    final dayIndexes = [1, 2, 3, 4, 5, 6, 0];
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
              l10n.newRecurringTitle,
              style: AppTypography.display.copyWith(fontSize: 30),
            ),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(l10n.newRecurringSubtitle, style: AppTypography.bodyMuted),
          const SizedBox(height: AppTokens.spaceMd),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.choreIcon, style: AppTypography.label),
                          const SizedBox(height: AppTokens.spaceXs),
                          Semantics(
                            container: true,
                            button: true,
                            label: l10n.chooseEmoji(_emojis[_emoji]),
                            onTap: () => setState(
                              () => _emoji = (_emoji + 1) % _emojis.length,
                            ),
                            child: ExcludeSemantics(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusMd,
                                ),
                                onTap: () => setState(
                                  () => _emoji = (_emoji + 1) % _emojis.length,
                                ),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTokens.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppTokens.radiusMd,
                                    ),
                                  ),
                                  child: Text(
                                    _emojis[_emoji],
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppTokens.spaceSm + 4),
                      Expanded(
                        child: TextField(
                          controller: _title,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: l10n.choreName,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceSm + 4),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: l10n.choreNotes),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SectionLabel(l10n.pointsSection),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppTokens.spaceLg,
                    runSpacing: AppTokens.spaceSm,
                    children: [
                      StepperField(
                        caption: l10n.onTimePoints,
                        value: '$_points',
                        decreaseLabel: l10n.fewerPoints(l10n.onTimePoints),
                        increaseLabel: l10n.morePoints(l10n.onTimePoints),
                        onDecrease: _points > 1
                            ? () => setState(() {
                                _points--;
                                if (_late > _points) {
                                  _late = _points;
                                }
                              })
                            : null,
                        onIncrease: _points < 99
                            ? () => setState(() => _points++)
                            : null,
                      ),
                      StepperField(
                        caption: l10n.latePointsLabel,
                        value: '$_late',
                        decreaseLabel: l10n.fewerPoints(l10n.latePointsLabel),
                        increaseLabel: l10n.morePoints(l10n.latePointsLabel),
                        onDecrease: _late > 0
                            ? () => setState(() => _late--)
                            : null,
                        onIncrease: _late < _points
                            ? () => setState(() => _late++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Text(
                    l10n.pointsRule,
                    style: AppTypography.eyebrow.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SectionLabel(l10n.whenSection),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedTabs<_Freq>(
                    labels: {
                      _Freq.daily: l10n.recurrenceDaily,
                      _Freq.weekly: l10n.recurrenceWeekly,
                      _Freq.monthly: l10n.recurrenceMonthly,
                    },
                    selected: _freq,
                    onSelected: (value) => setState(() {
                      _freq = value;
                      _interval = 1;
                    }),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StepperField(
                      caption: l10n.every,
                      value: switch (_freq) {
                        _Freq.daily => l10n.intervalDays(_interval),
                        _Freq.weekly => l10n.intervalWeeks(_interval),
                        _Freq.monthly => l10n.intervalMonths(_interval),
                      },
                      decreaseLabel: l10n.decreaseInterval,
                      increaseLabel: l10n.increaseInterval,
                      onDecrease: _interval > 1
                          ? () => setState(() => _interval--)
                          : null,
                      onIncrease: _interval < 12
                          ? () => setState(() => _interval++)
                          : null,
                    ),
                  ),
                  if (_freq == _Freq.weekly) ...[
                    const SizedBox(height: AppTokens.spaceSm),
                    Text(
                      l10n.onDays,
                      style: AppTypography.label.copyWith(
                        color: AppTokens.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXs),
                    Row(
                      spacing: AppTokens.spaceXs,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _DayButton(
                              short: symbols.NARROWWEEKDAYS[dayIndexes[i]],
                              full: symbols.WEEKDAYS[dayIndexes[i]],
                              on: _days.contains(i),
                              onTap: () => setState(() {
                                if (!_days.remove(i)) {
                                  _days.add(i);
                                } else if (_days.isEmpty) {
                                  _days.add(i);
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_freq == _Freq.monthly) ...[
                    const SizedBox(height: AppTokens.spaceSm),
                    Text(l10n.monthlyHint, style: AppTypography.bodyMuted),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SectionLabel(l10n.whoSection),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            spacing: AppTokens.spaceSm + 2,
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.sync,
                  title: l10n.takeTurns,
                  hint: l10n.takeTurnsHint,
                  selected: _rotation,
                  onTap: () => setState(() => _rotation = true),
                ),
              ),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.person_outline,
                  title: l10n.onePerson,
                  hint: l10n.onePersonHint,
                  selected: !_rotation,
                  onTap: () => setState(() => _rotation = false),
                ),
              ),
            ],
          ),
          if (!_rotation) ...[
            const SizedBox(height: AppTokens.spaceSm),
            FutureBuilder<List<Membership>>(
              future: _members,
              builder: (context, snapshot) {
                final members = [...?snapshot.data]
                  ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
                if (snapshot.hasError) {
                  return Text(l10n.errorGeneric);
                }
                return AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < members.length; i++)
                        _MemberPick(
                          label: members[i].userId == widget.session.profile?.id
                              ? l10n.you
                              : members[i].userId,
                          color: memberColor(i),
                          selected: _fixed == members[i].userId,
                          onTap: () =>
                              setState(() => _fixed = members[i].userId),
                        ),
                    ],
                  ),
                );
              },
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
                  onPressed: _valid && !_busy ? _save : null,
                  child: Text(_busy ? l10n.loading : l10n.saveChore),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.short,
    required this.full,
    required this.on,
    required this.onTap,
  });

  final String short;
  final String full;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: full,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: AppTokens.minTapTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppTokens.brand : AppTokens.card,
              borderRadius: BorderRadius.circular(14),
              border: on ? null : Border.all(color: AppTokens.outline),
            ),
            child: Text(
              short,
              style: AppTypography.label.copyWith(
                color: on ? AppTokens.onBrand : AppTokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$title. $hint',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppTokens.brandTint : AppTokens.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            side: BorderSide(
              color: selected ? AppTokens.brand : AppTokens.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppTokens.brand),
                    const SizedBox(height: AppTokens.spaceSm),
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hint,
                      style: AppTypography.eyebrow.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberPick extends StatelessWidget {
  const _MemberPick({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm + 2,
                vertical: AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  MemberAvatar(label: label, color: color),
                  const SizedBox(width: AppTokens.spaceSm + 4),
                  Expanded(child: Text(label, style: AppTypography.body)),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppTokens.brand),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
