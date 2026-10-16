import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/template_form_dialog.dart';
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
    final draft = await showTemplateForm(context, template: template);
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
          IconButton(
            tooltip: l10n.invite,
            onPressed: _invite,
            icon: const Icon(Icons.person_add_alt_1),
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
          return ListView(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            children: [
              Text(
                data.household.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(data.household.timezone),
              const SizedBox(height: AppTokens.spaceLg),
              Text(
                l10n.members,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceSm),
              ...data.members.map((member) {
                final roleLabel = member.role == MembershipRole.admin
                    ? l10n.roleAdmin
                    : l10n.roleMember;
                final action = isAdmin
                    ? TextButton(
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
                        child: Text(
                          member.isAway ? l10n.clearAway : l10n.setAway,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.spaceSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.userId,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              member.isAway
                                  ? '$roleLabel · ${l10n.away}'
                                  : roleLabel,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (action != null) Flexible(child: action),
                    ],
                  ),
                );
              }),
              const SizedBox(height: AppTokens.spaceLg),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.templatesSection,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: _saveTemplate,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addTemplate),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),
              if (data.templates.isEmpty)
                Text(l10n.templatesEmpty)
              else
                ...data.templates.map(
                  (template) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                    child: AppCard(
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          leading: template.emoji == null
                              ? null
                              : Text(
                                  template.emoji ?? '',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                          title: Text(template.title),
                          subtitle: Text(
                            l10n.templatePointsSummary(
                              template.points,
                              template.latePoints,
                            ),
                          ),
                          onTap: isAdmin
                              ? () => _saveTemplate(template: template)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppTokens.spaceLg),
              OutlinedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await widget.session.repository.leave(widget.householdId);
                  if (!mounted) {
                    return;
                  }
                  navigator.pop();
                },
                child: Text(l10n.leaveHousehold),
              ),
            ],
          );
        },
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
