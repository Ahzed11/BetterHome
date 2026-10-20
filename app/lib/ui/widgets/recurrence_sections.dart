import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/member_labels.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/segmented_tabs.dart';
import 'package:betterhome/ui/widgets/stepper_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum RecurrenceFreq { daily, weekly, monthly }

const _byDay = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// The schedule and the assignment of a recurring chore, edited by [RecurrenceSections].
class RecurrenceController extends ChangeNotifier {
  RecurrenceFreq freq = RecurrenceFreq.weekly;
  int interval = 1;
  final Set<int> days = {DateTime.now().weekday - 1};
  bool rotation = true;
  String? fixed;

  /// The start of an existing recurrence, kept when it is saved again.
  DateTime? startsAt;

  /// Reads the schedule and assignment of [recurrence], as this form writes them.
  void load(TaskRecurrence recurrence) {
    final parts = {
      for (final part in recurrence.rrule.split(';'))
        if (part.contains('=')) part.split('=').first: part.split('=').last,
    };
    freq = switch (parts['FREQ']) {
      'DAILY' => RecurrenceFreq.daily,
      'MONTHLY' => RecurrenceFreq.monthly,
      _ => RecurrenceFreq.weekly,
    };
    interval = (int.tryParse(parts['INTERVAL'] ?? '') ?? 1).clamp(1, 12);
    final byDay = (parts['BYDAY'] ?? '').split(',');
    final parsed = {
      for (var i = 0; i < _byDay.length; i++)
        if (byDay.contains(_byDay[i])) i,
    };
    if (parsed.isNotEmpty) {
      days
        ..clear()
        ..addAll(parsed);
    }
    rotation = recurrence.assignmentMode == AssignmentMode.roundRobin;
    fixed = recurrence.fixedAssigneeId;
    startsAt = recurrence.startsAt;
    notifyListeners();
  }

  String get rrule {
    final every = interval == 1 ? '' : ';INTERVAL=$interval';
    switch (freq) {
      case RecurrenceFreq.daily:
        return 'FREQ=DAILY$every';
      case RecurrenceFreq.weekly:
        final picked = ([...days]..sort()).map((d) => _byDay[d]).join(',');
        return 'FREQ=WEEKLY$every;BYDAY=$picked';
      case RecurrenceFreq.monthly:
        return 'FREQ=MONTHLY$every;BYMONTHDAY=1';
    }
  }

  bool get valid => rotation || fixed != null;

  void update(void Function() change) {
    change();
    notifyListeners();
  }
}

/// A short name for how often [recurrence] comes back: "Weekly", or "Every 2 weeks".
String recurrenceLabel(AppLocalizations l10n, TaskRecurrence recurrence) {
  final c = RecurrenceController()..load(recurrence);
  if (c.interval == 1) {
    return switch (c.freq) {
      RecurrenceFreq.daily => l10n.recurrenceDaily,
      RecurrenceFreq.weekly => l10n.recurrenceWeekly,
      RecurrenceFreq.monthly => l10n.recurrenceMonthly,
    };
  }
  final every = switch (c.freq) {
    RecurrenceFreq.daily => l10n.intervalDays(c.interval),
    RecurrenceFreq.weekly => l10n.intervalWeeks(c.interval),
    RecurrenceFreq.monthly => l10n.intervalMonths(c.interval),
  };
  return '${l10n.every} $every';
}

/// The small green pill that marks a chore as recurring, with how often.
class RecurringPill extends StatelessWidget {
  const RecurringPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: AppTokens.brandTint,
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm + AppTokens.spaceXs,
          vertical: AppTokens.spaceXs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, size: 14, color: AppTokens.deepBrand),
            const SizedBox(width: AppTokens.spaceXs + 2),
            Flexible(
              child: Text(
                label,
                style: AppTypography.label.copyWith(
                  fontSize: 13,
                  color: AppTokens.deepBrand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "When" and "Who does it" sections of the design's "New recurring chore" board.
class RecurrenceSections extends StatelessWidget {
  const RecurrenceSections({
    super.key,
    required this.controller,
    required this.members,
    required this.meId,
  });

  final RecurrenceController controller;
  final Future<List<Membership>> members;
  final String? meId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final symbols = DateFormat.EEEE(locale).dateSymbols;
    // Monday first; the symbols start on Sunday.
    const dayIndexes = [1, 2, 3, 4, 5, 6, 0];
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(l10n.whenSection),
            const SizedBox(height: AppTokens.spaceSm),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedTabs<RecurrenceFreq>(
                      labels: {
                        RecurrenceFreq.daily: l10n.recurrenceDaily,
                        RecurrenceFreq.weekly: l10n.recurrenceWeekly,
                        RecurrenceFreq.monthly: l10n.recurrenceMonthly,
                      },
                      selected: c.freq,
                      onSelected: (value) => c.update(() {
                        c.freq = value;
                        c.interval = 1;
                      }),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StepperField(
                        caption: l10n.every,
                        value: switch (c.freq) {
                          RecurrenceFreq.daily => l10n.intervalDays(c.interval),
                          RecurrenceFreq.weekly => l10n.intervalWeeks(
                            c.interval,
                          ),
                          RecurrenceFreq.monthly => l10n.intervalMonths(
                            c.interval,
                          ),
                        },
                        decreaseLabel: l10n.decreaseInterval,
                        increaseLabel: l10n.increaseInterval,
                        onDecrease: c.interval > 1
                            ? () => c.update(() => c.interval--)
                            : null,
                        onIncrease: c.interval < 12
                            ? () => c.update(() => c.interval++)
                            : null,
                      ),
                    ),
                    if (c.freq == RecurrenceFreq.weekly) ...[
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
                                on: c.days.contains(i),
                                onTap: () => c.update(() {
                                  if (!c.days.remove(i) || c.days.isEmpty) {
                                    c.days.add(i);
                                  }
                                }),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (c.freq == RecurrenceFreq.monthly) ...[
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
                    selected: c.rotation,
                    onTap: () => c.update(() => c.rotation = true),
                  ),
                ),
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.person_outline,
                    title: l10n.onePerson,
                    hint: l10n.onePersonHint,
                    selected: !c.rotation,
                    onTap: () => c.update(() => c.rotation = false),
                  ),
                ),
              ],
            ),
            if (!c.rotation) ...[
              const SizedBox(height: AppTokens.spaceSm),
              FutureBuilder<List<Membership>>(
                future: members,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(l10n.errorGeneric);
                  }
                  final all = [...?snapshot.data]
                    ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
                  return AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < all.length; i++)
                          _MemberPick(
                            label: memberLabel(l10n, all[i], meId),
                            color: memberColor(i),
                            selected: c.fixed == all[i].userId,
                            onTap: () =>
                                c.update(() => c.fixed = all[i].userId),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
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
