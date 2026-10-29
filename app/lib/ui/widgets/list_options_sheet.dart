import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// What the options sheet of a list can ask for.
enum ListAction { reset, removeChecked, rename, archive }

/// Opens the options of the list called [title] and returns the chosen action, or null when
/// closed without one. Renaming and archiving are shown only to admins ([isAdmin]).
Future<ListAction?> showListOptions(
  BuildContext context, {
  required String title,
  required bool isAdmin,
}) {
  return showModalBottomSheet<ListAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTokens.card,
    barrierColor: AppTokens.ink.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ListOptionsSheet(title: title, isAdmin: isAdmin),
  );
}

class _ListOptionsSheet extends StatelessWidget {
  const _ListOptionsSheet({required this.title, required this.isAdmin});

  final String title;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          0,
          AppTokens.spaceMd,
          AppTokens.spaceMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceSm,
                  0,
                  AppTokens.spaceSm,
                  AppTokens.spaceSm,
                ),
                child: Text(
                  title,
                  style: AppTypography.display.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _OptionRow(
              icon: Icons.restart_alt,
              title: l10n.resetList,
              subtitle: l10n.resetListHint,
              action: ListAction.reset,
            ),
            _OptionRow(
              icon: Icons.delete_outline,
              title: l10n.removeChecked,
              subtitle: l10n.removeCheckedHint,
              action: ListAction.removeChecked,
            ),
            if (isAdmin) ...[
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceXs,
                ),
                child: Divider(height: 1, color: AppTokens.divider),
              ),
              _OptionRow(
                icon: Icons.edit_outlined,
                title: l10n.renameList,
                subtitle: l10n.renameListHint,
                action: ListAction.rename,
                adminOnly: true,
              ),
              _OptionRow(
                icon: Icons.archive_outlined,
                title: l10n.archiveList,
                subtitle: l10n.archiveListHint,
                action: ListAction.archive,
                adminOnly: true,
                destructive: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One action of the sheet: an icon tile, a title with a one-line explanation, and an "Admin"
/// badge on the actions only admins have. [destructive] draws the title in the overdue coral.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    this.adminOnly = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ListAction action;
  final bool adminOnly;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void choose() => Navigator.pop(context, action);
    return Semantics(
      container: true,
      button: true,
      label: title,
      hint: subtitle,
      onTap: choose,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: choose,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: AppTokens.pillHeight,
                    height: AppTokens.pillHeight,
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: destructive
                          ? AppTokens.overdueText
                          : AppTokens.ink,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceMd - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: destructive
                                ? AppTokens.overdueText
                                : AppTokens.ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTypography.bodyMuted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (adminOnly) ...[
                    const SizedBox(width: AppTokens.spaceSm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                        vertical: 2,
                      ),
                      decoration: const ShapeDecoration(
                        color: AppTokens.podiumGold,
                        shape: StadiumBorder(),
                      ),
                      child: Text(
                        l10n.roleAdmin,
                        style: AppTypography.label.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.podiumGoldInk,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
