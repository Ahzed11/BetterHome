import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/state/reads.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/member_labels.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:betterhome/ui/widgets/recurrence_sections.dart';
import 'package:betterhome/ui/screens/template_form_screen.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/app_toast.dart';

import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:betterhome/ui/widgets/pull_to_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HouseholdDetailScreen extends StatefulWidget {
  const HouseholdDetailScreen({
    super.key,
    required this.session,
    required this.householdId,
  });

  final AppSession session;
  final String householdId;

  @override
  State<HouseholdDetailScreen> createState() => _HouseholdDetailScreenState();
}

class _HouseholdDetailScreenState extends State<HouseholdDetailScreen> {
  late final CachedRead<_Rules> _rules;
  late final CachedRead<List<Membership>> _members;
  late final CachedRead<Household> _household;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final householdId = widget.householdId;
    // Three reads that do not depend on each other, asked together. The members and the
    // household are shared with the other screens: one request each, whoever asks first.
    _rules = CachedRead(
      cache: session.readCache,
      key: session.readKey('household-rules', householdId: householdId),
      fetch: _loadRules,
      onChange: _changed,
    );
    _members = CachedRead.of(
      session.readCache,
      session.membersRead(householdId),
      onChange: _changed,
    );
    _household = CachedRead.of(
      session.readCache,
      session.householdRead(householdId),
      onChange: _changed,
    );
  }

  @override
  void dispose() {
    _rules.dispose();
    _members.dispose();
    _household.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Pull to refresh: every read this screen shows. A request already running is joined.
  Future<bool> _pull() async {
    final answers = await Future.wait([
      _rules.refresh(),
      _members.refresh(),
      _household.refresh(),
    ]);
    return answers.every((arrived) => arrived);
  }

  /// Asks for fresh data after something was changed on this screen.
  void _reload() {
    _rules.refreshAfterChange();
    _members.refreshAfterChange();
    _household.refreshAfterChange();
  }

  /// The templates, then the recurrence of each, all asked together once the templates are known.
  Future<_Rules> _loadRules() async {
    final tasks = widget.session.tasksRepository;
    final templates = await tasks.listTemplates(widget.householdId);
    final found = await Future.wait([
      for (final template in templates)
        tasks.getRecurrence(widget.householdId, template.id),
    ]);
    return _Rules(
      templates: templates,
      recurrences: {
        for (var i = 0; i < templates.length; i++) templates[i].id: ?found[i],
      },
    );
  }

  /// Opens the chore form (for a new chore, or to edit [template]) and saves what it returns.
  Future<void> _saveTemplate({
    TaskTemplate? template,
    bool startRecurring = false,
  }) async {
    final draft = await Navigator.of(context).push<TemplateDraft>(
      MaterialPageRoute(
        builder: (_) => TemplateFormScreen(
          session: widget.session,
          householdId: widget.householdId,
          template: template,
          startRecurring: startRecurring,
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
      template: template,
    );
    if (!mounted) {
      return;
    }
    if (saved && draft.recurrence != null) {
      showAppToast(
        context,
        message: AppLocalizations.of(context).recurrenceSet,
      );
    }
    _reload();
  }

  Future<void> _runDueNow() async {
    final count = await widget.session.tasksRepository.runDueRecurrences(
      widget.householdId,
    );
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: AppLocalizations.of(context).spawnedCount(count),
    );
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(l10n.invite),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(labelText: l10n.inviteEmail),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, emailController.text.trim()),
            child: Text(l10n.sendInvite),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) {
      return;
    }
    final invitation = await widget.session.repository.createInvitation(
      householdId: widget.householdId,
      email: email,
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(l10n.inviteCreated),
        content: Text(l10n.copyToken(invitation.token)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invitation.token));
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvite() async {
    final l10n = AppLocalizations.of(context);
    final tokenController = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(l10n.acceptInvite),
        content: TextField(
          controller: tokenController,
          decoration: InputDecoration(labelText: l10n.inviteToken),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, tokenController.text.trim()),
            child: Text(l10n.acceptInvite),
          ),
        ],
      ),
    );
    if (token == null || token.isEmpty || !mounted) {
      return;
    }
    await widget.session.repository.acceptInvitation(token);
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = widget.session.profile;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.acceptInvite,
            onPressed: _acceptInvite,
            icon: const Icon(Icons.mail_outline),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final states = [_rules.state, _members.state, _household.state];
          if (states.any((state) => state is ReadFailed)) {
            return PullToRefresh(
              onRefresh: _pull,
              child: PullableCenter(child: Text(l10n.errorGeneric)),
            );
          }
          final data = switch ((
            _rules.state,
            _members.state,
            _household.state,
          )) {
            (
              ReadLoaded<_Rules>(data: final rules),
              ReadLoaded<List<Membership>>(data: final members),
              ReadLoaded<Household>(data: final household),
            ) =>
              _DetailData(
                household: household,
                members: members,
                templates: rules.templates,
                recurrences: rules.recurrences,
              ),
            _ => null,
          };
          if (data == null) {
            return ListView(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              children: const [HouseholdSkeleton()],
            );
          }
          final isAdmin = data.members.any(
            (m) => m.userId == me?.id && m.role == MembershipRole.admin,
          );
          final ordered = [...data.members]
            ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
          return PullToRefresh(
            onRefresh: _pull,
            child: ListView(
              physics: pullablePhysics,
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    data.household.name,
                    style: AppTypography.display.copyWith(fontSize: 34),
                  ),
                ),
                Text(
                  l10n.householdSummary(
                    data.members.length,
                    data.household.timezone,
                  ),
                  style: AppTypography.eyebrow.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
                SectionLabel(l10n.members),
                const SizedBox(height: AppTokens.spaceSm),
                AppCard(
                  child: Column(
                    children: [
                      for (final member in data.members)
                        _memberRow(member, ordered, isAdmin, me?.id, l10n),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _InviteRow(
                  label: l10n.inviteHousemate,
                  tooltip: l10n.invite,
                  onTap: _invite,
                ),
                if (isAdmin) ...[
                  const SizedBox(height: AppTokens.spaceLg),
                  SectionLabel(l10n.houseRules),
                  const SizedBox(height: AppTokens.spaceSm),
                  AppCard(
                    child: Column(
                      children: [
                        _RuleRow(
                          icon: Icons.sync,
                          title: l10n.choresAndRotations,
                          hint: l10n.choresAndRotationsHint,
                          onTap: () => _saveTemplate(startRecurring: true),
                        ),
                        const Divider(height: 1, color: AppTokens.divider),
                        _RuleRow(
                          icon: Icons.play_circle_outline,
                          title: l10n.runDueNow,
                          onTap: _runDueNow,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.spaceLg),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SectionLabel(l10n.templatesSection),
                    if (isAdmin)
                      AppPill(
                        label: l10n.addTemplate,
                        icon: Icons.add,
                        onPressed: _saveTemplate,
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceSm),
                if (data.templates.isEmpty)
                  Text(l10n.templatesEmpty, style: AppTypography.bodyMuted)
                else
                  for (final template in data.templates) ...[
                    AppCard(
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          leading: template.emoji == null
                              ? null
                              : Text(
                                  template.emoji ?? '',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                          title: Text(
                            template.title,
                            style: AppTypography.body,
                          ),
                          subtitle: _templateSubtitle(
                            l10n,
                            template,
                            data.recurrences[template.id],
                          ),
                          trailing: _stackPill(context)
                              ? null
                              : _pillFor(l10n, data.recurrences[template.id]),
                          onTap: isAdmin
                              ? () => _saveTemplate(template: template)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                  ],
                const SizedBox(height: AppTokens.spaceMd),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.overdueText,
                      minimumSize: const Size(0, AppTokens.minTapTarget),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await widget.session.repository.leave(widget.householdId);
                      if (!mounted) {
                        return;
                      }
                      navigator.pop();
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(l10n.leaveHousehold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// At large text sizes the pill goes under the points instead of squeezing the title.
  bool _stackPill(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) > 22;

  Widget? _pillFor(AppLocalizations l10n, TaskRecurrence? recurrence) =>
      switch (recurrence) {
        final r? => RecurringPill(label: recurrenceLabel(l10n, r)),
        null => null,
      };

  Widget _templateSubtitle(
    AppLocalizations l10n,
    TaskTemplate template,
    TaskRecurrence? recurrence,
  ) {
    final points = Text(
      l10n.templatePointsSummary(template.points, template.latePoints),
      style: AppTypography.eyebrow.copyWith(fontWeight: FontWeight.w400),
    );
    final pill = _stackPill(context) ? _pillFor(l10n, recurrence) : null;
    if (pill == null) {
      return points;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        points,
        const SizedBox(height: AppTokens.spaceXs),
        pill,
      ],
    );
  }

  Widget _memberRow(
    Membership member,
    List<Membership> ordered,
    bool isAdmin,
    String? meId,
    AppLocalizations l10n,
  ) {
    final roleLabel = member.role == MembershipRole.admin
        ? l10n.roleAdmin
        : l10n.roleMember;
    final label = memberLabel(l10n, member, meId);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceSm + AppTokens.spaceXs,
        vertical: AppTokens.spaceSm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // At large text sizes the pill goes under the name instead of squeezing it.
          final stacked = MediaQuery.textScalerOf(context).scale(16) > 22;
          final who = Row(
            children: [
              MemberAvatar(
                label: label,
                color: memberColor(ordered.indexOf(member)),
              ),
              const SizedBox(width: AppTokens.spaceSm + AppTokens.spaceXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      member.isAway ? '$roleLabel · ${l10n.away}' : roleLabel,
                      style: AppTypography.eyebrow.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final pill = AppPill(
            label: member.isAway ? l10n.clearAway : l10n.setAway,
            icon: Icons.dark_mode_outlined,
            onPressed: () async {
              if (member.isAway) {
                await widget.session.repository.clearAway(
                  widget.householdId,
                  member.userId,
                );
              } else {
                await widget.session.repository.setAway(
                  widget.householdId,
                  member.userId,
                );
              }
              if (mounted) {
                _reload();
              }
            },
          );
          if (!isAdmin) {
            return who;
          }
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [who, pill],
                )
              : Row(
                  children: [
                    Expanded(child: who),
                    const SizedBox(width: AppTokens.spaceSm),
                    pill,
                  ],
                );
        },
      ),
    );
  }
}

/// One tappable row of the "House rules" card: an icon, a title, an optional hint and a chevron.
class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd - 2,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppTokens.brand),
              const SizedBox(width: AppTokens.spaceSm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint ?? '',
                        style: AppTypography.eyebrow.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppTokens.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The soft green "invite" row under the members.
class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTokens.brandTint,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 20,
                    color: AppTokens.deepBrand,
                  ),
                  const SizedBox(width: AppTokens.spaceSm + 2),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: AppTokens.deepBrand,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What is cached for the chore rules of a household: its templates and their recurrences.
class _Rules {
  const _Rules({required this.templates, required this.recurrences});

  final List<TaskTemplate> templates;
  final Map<String, TaskRecurrence> recurrences;
}

class _DetailData {
  const _DetailData({
    required this.household,
    required this.members,
    required this.templates,
    required this.recurrences,
  });

  final Household household;
  final List<Membership> members;
  final List<TaskTemplate> templates;

  /// The recurrence of each template that has one, by template id.
  final Map<String, TaskRecurrence> recurrences;
}
