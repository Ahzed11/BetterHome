import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/state/reads.dart';
import 'package:betterhome/ui/screens/template_form_screen.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/chore_card.dart';
import 'package:betterhome/ui/widgets/overdue_badge.dart';
import 'package:betterhome/ui/widgets/quick_log_sheet.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/undoable_action.dart';
import 'package:betterhome/ui/widgets/week_strip.dart';
import 'package:betterhome/ui/widgets/week_summary_card.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _Filter { all, mine, done }

class ChoresScreen extends StatefulWidget {
  const ChoresScreen({
    super.key,
    required this.session,
    required this.householdId,
    this.mine = false,
    this.now = DateTime.now,
    this.onLoaded,
  });

  final AppSession session;
  final String householdId;

  /// Only the chores assigned to the signed-in member (the "My chores" tab).
  final bool mine;

  /// The current time, used to tell which open chores are overdue.
  final DateTime Function() now;

  /// Called once, when the chores of this screen have been loaded, fresh from the server: the
  /// first tab says so, and the app starts loading the other tabs behind it.
  final VoidCallback? onLoaded;

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  late final CachedRead<List<ChoreTask>> _tasks;
  late final CachedRead<List<Membership>> _members;
  CachedRead<WeekStanding>? _week;
  CachedRead<Household>? _household;
  _Filter _filter = _Filter.all;
  DateTime? _selectedDay;
  bool _signalledLoaded = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final householdId = widget.householdId;
    _tasks = CachedRead.of(
      session.readCache,
      session.tasksRead(householdId, mine: widget.mine),
      onChange: _changed,
    );
    _members = CachedRead.of(
      session.readCache,
      session.membersRead(householdId),
      onChange: _changed,
    );
    if (widget.mine) {
      // The week summary and the household's name do not depend on each other: asked together
      // with the tasks and the members.
      _week = CachedRead.of(
        session.readCache,
        session.weekRead(householdId),
        onChange: _changed,
      );
      _household = CachedRead.of(
        session.readCache,
        session.householdRead(householdId),
        onChange: _changed,
      );
    }
  }

  @override
  void dispose() {
    _tasks.dispose();
    _members.dispose();
    _week?.dispose();
    _household?.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    setState(() {});
    if (_signalledLoaded) {
      return;
    }
    if (_tasks.state case ReadLoaded<List<ChoreTask>>(refreshing: false)) {
      _signalledLoaded = true;
      widget.onLoaded?.call();
    }
  }

  /// Asks for fresh data after the user's own action. What is on screen stays until it arrives.
  void _refresh() {
    _tasks.refreshAfterChange();
    _week?.refreshAfterChange();
  }

  bool get _isAdmin {
    final me = widget.session.profile?.id;
    return switch (_members.state) {
      ReadLoaded<List<Membership>>(:final data) => data.any(
        (m) => m.userId == me && m.role == MembershipRole.admin,
      ),
      _ => false,
    };
  }

  String _statusLabel(TaskStatus status, AppLocalizations l10n) =>
      switch (status) {
        TaskStatus.open => l10n.taskStatusOpen,
        TaskStatus.done => l10n.taskStatusDone,
        TaskStatus.dismissed => l10n.taskStatusDismissed,
        TaskStatus.reverted => l10n.taskStatusReverted,
      };

  Widget _meta(ChoreTask task, AppLocalizations l10n) {
    final due = task.dueAt;
    final Widget status;
    if (_isOverdue(task)) {
      status = OverdueBadge(label: l10n.overdueStill(task.latePoints));
    } else if (task.status == TaskStatus.open && due != null) {
      final days = _dayOf(
        due.toLocal(),
      ).difference(_dayOf(widget.now())).inDays;
      status = Text(
        l10n.dueInDays(days < 0 ? 0 : days),
        style: AppTypography.eyebrow,
      );
    } else if (task.status == TaskStatus.open) {
      status = Text(l10n.noDueDate, style: AppTypography.eyebrow);
    } else {
      status = Text(
        l10n.taskStatusWithPoints(
          _statusLabel(task.status, l10n),
          l10n.pointsLabel(task.pointsAwarded ?? task.points),
        ),
        style: AppTypography.eyebrow,
      );
    }
    final reason = task.reversionReason;
    if (reason == null || task.status == TaskStatus.done) {
      return status;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        status,
        Text(l10n.revertedBecause(reason), style: AppTypography.eyebrow),
      ],
    );
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// The day a chore sits on in the week strip: its due day, or the day it was done when it has
  /// no due date (a quick-logged chore).
  static DateTime? _stripDay(ChoreTask task) {
    final at = task.dueAt ?? task.completedAt;
    return at == null ? null : _dayOf(at.toLocal());
  }

  bool _isOverdue(ChoreTask task) {
    final due = task.dueAt;
    return task.status == TaskStatus.open &&
        due != null &&
        widget.now().isAfter(due);
  }

  Future<void> _quickLog() async {
    final l10n = AppLocalizations.of(context);
    final templates = await widget.session.tasksRepository.listTemplates(
      widget.householdId,
    );
    if (!mounted) {
      return;
    }
    if (templates.isEmpty) {
      final draft = await Navigator.of(context).push<TemplateDraft>(
        MaterialPageRoute(
          builder: (_) => TemplateFormScreen(
            session: widget.session,
            householdId: widget.householdId,
          ),
        ),
      );
      if (draft == null || !mounted) {
        return;
      }
      final saved = await saveTemplateDraft(
        context,
        widget.session,
        widget.householdId,
        draft,
      );
      if (!saved) {
        return;
      }
    }
    final latest = await widget.session.tasksRepository.listTemplates(
      widget.householdId,
    );
    if (!mounted || latest.isEmpty) {
      return;
    }
    final templateId = await showQuickLogSheet(context, latest);
    if (templateId == null || !mounted) {
      return;
    }
    final template = latest.firstWhere((t) => t.id == templateId);
    final tasks = widget.session.tasksRepository;
    final logged = await runUnlessUndone(
      context,
      message: l10n.quickLogPending(template.title),
      action: () => tasks.quickLog(
        householdId: widget.householdId,
        templateId: templateId,
      ),
    );
    if (logged && mounted) {
      _refresh();
    }
  }

  Future<void> _revert(ChoreTask task) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(l10n.revertConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.revertConfirmBody),
              const SizedBox(height: AppTokens.spaceMd),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(labelText: l10n.revertReason),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: Text(l10n.revertTask),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) {
      return;
    }
    await widget.session.tasksRepository.revert(
      widget.householdId,
      task.id,
      reason: reason,
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _complete(ChoreTask task) async {
    await widget.session.tasksRepository.complete(widget.householdId, task.id);
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _dismiss(ChoreTask task, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(l10n.dismissConfirmTitle),
        content: Text(l10n.dismissConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.dismissTask),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.session.tasksRepository.dismiss(widget.householdId, task.id);
      if (mounted) {
        _refresh();
      }
    }
  }

  Widget _card(ChoreTask task, AppLocalizations l10n) {
    final open = task.status == TaskStatus.open;
    final done = task.status == TaskStatus.done;
    return ChoreCard(
      title: '${task.emoji ?? ''} ${task.title}'.trim(),
      meta: _meta(task, l10n),
      circle: done
          ? ChoreCircle.done
          : _isOverdue(task)
          ? ChoreCircle.overdue
          : ChoreCircle.open,
      completeLabel: open ? l10n.completeTask : null,
      onComplete: open ? () => _complete(task) : null,
      trailing: open
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${task.points}',
                  style: AppTypography.body.copyWith(
                    color: AppTokens.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: l10n.dismissTask,
                  onPressed: () => _dismiss(task, l10n),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            )
          : done && _isAdmin
          ? IconButton(
              tooltip: l10n.revertTask,
              onPressed: () => _revert(task),
              icon: const Icon(Icons.undo),
            )
          : null,
    );
  }

  String? _eyebrow(AppLocalizations l10n) {
    final household = switch (_household?.state) {
      ReadLoaded<Household>(:final data) => data.name,
      _ => null,
    };
    return household == null
        ? null
        : l10n.heyHousehold(widget.session.profile?.givenName ?? '', household);
  }

  Widget _summary(List<ChoreTask> tasks, AppLocalizations l10n) {
    return switch (_week?.state) {
      ReadFailed<WeekStanding>() => Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Text(l10n.errorGeneric),
      ),
      ReadLoaded<WeekStanding>(:final data) => _weekCard(data, tasks, l10n),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _weekCard(
    WeekStanding week,
    List<ChoreTask> tasks,
    AppLocalizations l10n,
  ) {
    final open = tasks.where((t) => t.status == TaskStatus.open).toList();
    final reach = open.fold<int>(0, (sum, t) => sum + t.points);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      child: WeekSummaryCard(
        heading: l10n.thisWeek,
        points: l10n.pointsLabel(week.points),
        rank: week.rank == 1
            ? l10n.rankFirst
            : l10n.rankBehind(week.rank, week.behind),
        progress: week.points + reach == 0
            ? 0
            : week.points / (week.points + reach),
        reach: l10n.withinReach(reach, open.length),
      ),
    );
  }

  Widget _strip(List<ChoreTask> tasks, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toString();
    final today = _dayOf(widget.now());
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final range = DateFormat.MMMd(locale);
    return WeekStrip(
      title: '${range.format(days.first)} – ${range.format(days.last)}',
      days: [
        for (final day in days)
          () {
            final due = tasks.where((t) => _stripDay(t) == day);
            return StripDay(
              weekday: day == today
                  ? l10n.stripToday
                  : DateFormat.E(locale).format(day),
              number: '${day.day}',
              dots: [
                for (final t in due)
                  t.status == TaskStatus.done
                      ? StripDot.done
                      : _isOverdue(t)
                      ? StripDot.overdue
                      : StripDot.upcoming,
              ],
              selected:
                  _selectedDay == day || (_selectedDay == null && day == today),
              semanticLabel: l10n.stripDayLabel(
                DateFormat.MMMMEEEEd(locale).format(day),
                due.length,
              ),
              onTap: () => setState(
                () => _selectedDay = _selectedDay == day ? null : day,
              ),
            );
          }(),
      ],
    );
  }

  Widget _sectionHeader(String title, String? hint) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: AppTypography.display.copyWith(
                  fontSize: 18,
                  height: 1.2,
                ),
              ),
            ),
          ),
          if (hint != null) ...[
            Flexible(
              child: Text(
                hint,
                textAlign: TextAlign.end,
                style: AppTypography.eyebrow.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _sections(List<ChoreTask> tasks, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toString();
    final open = tasks.where((t) => t.status == TaskStatus.open).toList();
    final overdue = open.where(_isOverdue).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final upcoming = open.where((t) => !_isOverdue(t)).toList()
      ..sort(
        (a, b) =>
            (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)),
      );
    final finished = tasks.where((t) => t.status != TaskStatus.open).toList();
    final byDay = <DateTime?, List<ChoreTask>>{};
    for (final t in upcoming) {
      final due = t.dueAt;
      byDay
          .putIfAbsent(due == null ? null : _dayOf(due.toLocal()), () => [])
          .add(t);
    }
    final children = <Widget>[];
    void section(String title, String? hint, List<ChoreTask> items) {
      children.add(_sectionHeader(title, hint));
      for (final t in items) {
        children.add(_card(t, l10n));
      }
    }

    if (overdue.isNotEmpty) {
      section(l10n.catchUp, l10n.catchUpHint, overdue);
    }
    byDay.forEach((day, items) {
      if (day == null) {
        section(l10n.noDueDate, null, items);
      } else {
        final days = day.difference(_dayOf(widget.now())).inDays;
        section(
          DateFormat('EEEE d', locale).format(day),
          l10n.dueInDays(days < 0 ? 0 : days),
          items,
        );
      }
    });
    if (finished.isNotEmpty) {
      section(l10n.choresDone, null, finished);
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          boxShadow: [
            BoxShadow(
              color: AppTokens.brand.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _quickLog,
          icon: const Icon(Icons.add),
          label: Text(l10n.quickLog),
        ),
      ),
      body: Builder(
        builder: (context) {
          final state = _tasks.state;
          final tasks = switch (state) {
            ReadLoaded<List<ChoreTask>>(:final data) => data,
            _ => const <ChoreTask>[],
          };
          final me = widget.session.profile?.id;
          final mineTasks = tasks.where((t) => t.assigneeId == me).toList();
          final byFilter = switch (_filter) {
            _Filter.all => tasks,
            _Filter.mine => mineTasks,
            _Filter.done =>
              tasks.where((t) => t.status == TaskStatus.done).toList(),
          };
          final day = _selectedDay;
          final shown = day == null || widget.mine
              ? byFilter
              : byFilter.where((t) => _stripDay(t) == day).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (widget.mine)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceMd,
                    AppTokens.spaceSm,
                    AppTokens.spaceMd,
                    AppTokens.spaceSm,
                  ),
                  child: ScreenHeader(
                    eyebrow: _eyebrow(l10n),
                    title: l10n.yourChores,
                  ),
                ),
              if (widget.mine) _summary(tasks, l10n),
              if (!widget.mine)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceMd,
                    0,
                    AppTokens.spaceMd,
                    AppTokens.spaceSm + 2,
                  ),
                  child: _strip(tasks, l10n),
                ),
              if (!widget.mine)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceMd,
                  ),
                  child: Wrap(
                    spacing: AppTokens.spaceSm,
                    children: [
                      AppPill(
                        label: l10n.filterAll(tasks.length),
                        selected: _filter == _Filter.all,
                        onPressed: () => setState(() => _filter = _Filter.all),
                      ),
                      AppPill(
                        label: l10n.filterMine(mineTasks.length),
                        selected: _filter == _Filter.mine,
                        onPressed: () => setState(() => _filter = _Filter.mine),
                      ),
                      AppPill(
                        label: l10n.filterDone,
                        selected: _filter == _Filter.done,
                        onPressed: () => setState(() => _filter = _Filter.done),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  AppTokens.spaceSm,
                  AppTokens.spaceMd,
                  0,
                ),
                child: state is ReadLoading<List<ChoreTask>>
                    ? const ChoreListSkeleton()
                    : state is ReadFailed<List<ChoreTask>>
                    ? Center(child: Text(l10n.errorGeneric))
                    : shown.isEmpty
                    ? Center(
                        child: Text(
                          day == null || widget.mine
                              ? l10n.choresEmpty
                              : l10n.dayEmpty,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final w in _sections(shown, l10n)) ...[
                            w,
                            const SizedBox(height: AppTokens.spaceSm),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
