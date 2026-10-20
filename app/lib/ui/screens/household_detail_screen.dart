import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/member_avatar.dart';
import 'package:betterhome/ui/screens/template_form_screen.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/guarded.dart';

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
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = () async {
      final household = await widget.session.repository.getHousehold(
        widget.householdId,
      );
      final members = await widget.session.repository.listMembers(
        widget.householdId,
      );
      final templates = await widget.session.tasksRepository.listTemplates(
        widget.householdId,
      );
      return _DetailData(
        household: household,
        members: members,
        templates: templates,
      );
    }();
  }

  Future<void> _saveTemplate({TaskTemplate? template}) async {
    final draft = await Navigator.of(context).push<TemplateDraft>(
      MaterialPageRoute(builder: (_) => TemplateFormScreen(template: template)),
    );
    if (draft == null || !mounted) {
      return;
    }
    final tasks = widget.session.tasksRepository;
    await runGuarded(context, () async {
      if (template == null) {
        await tasks.createTemplate(
          householdId: widget.householdId,
          title: draft.title,
          emoji: draft.emoji.isEmpty ? null : draft.emoji,
          description: draft.description,
          points: draft.points,
          latePoints: draft.latePoints,
        );
      } else {
        await tasks.updateTemplate(
          householdId: widget.householdId,
          templateId: template.id,
          title: draft.title,
          emoji: draft.emoji,
          description: draft.description,
          points: draft.points,
          latePoints: draft.latePoints,
        );
      }
    });
    if (mounted) {
      setState(_reload);
    }
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
      setState(_reload);
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
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: Text(l10n.loading));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(l10n.errorGeneric));
          }
          final data = snapshot.data!;
          final isAdmin = data.members.any(
            (m) => m.userId == me?.id && m.role == MembershipRole.admin,
          );
          final ordered = [...data.members]
            ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
          return ListView(
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
                        title: Text(template.title, style: AppTypography.body),
                        subtitle: Text(
                          l10n.templatePointsSummary(
                            template.points,
                            template.latePoints,
                          ),
                          style: AppTypography.eyebrow.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
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
          );
        },
      ),
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
    final label = member.userId == meId ? l10n.you : member.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceSm + AppTokens.spaceXs,
        vertical: AppTokens.spaceSm,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberAvatar(
                label: label,
                color: memberColor(ordered.indexOf(member)),
              ),
              const SizedBox(width: AppTokens.spaceSm + AppTokens.spaceXs),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
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
          ),
          if (isAdmin)
            AppPill(
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
                  setState(_reload);
                }
              },
            ),
        ],
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

class _DetailData {
  const _DetailData({
    required this.household,
    required this.members,
    required this.templates,
  });

  final Household household;
  final List<Membership> members;
  final List<TaskTemplate> templates;
}
