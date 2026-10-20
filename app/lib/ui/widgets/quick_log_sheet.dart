import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Opens the quick-log sheet and returns the id of the template the person tapped, or null.
Future<String?> showQuickLogSheet(
  BuildContext context,
  List<TaskTemplate> templates,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => QuickLogSheet(templates: templates),
  );
}

/// The "I just did…" sheet of the design: a search field and a two-column grid of the household's
/// templates, each with its emoji and points. One tap picks a template.
class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, required this.templates});

  final List<TaskTemplate> templates;

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = widget.templates
        .where((t) => t.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppTokens.spaceMd + 4,
          0,
          AppTokens.spaceMd + 4,
          AppTokens.spaceLg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        header: true,
                        child: Text(
                          l10n.quickLog,
                          style: AppTypography.display.copyWith(fontSize: 26),
                        ),
                      ),
                      const SizedBox(height: AppTokens.spaceXs),
                      Text(
                        l10n.quickLogSubtitle,
                        style: AppTypography.eyebrow.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l10n.close,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTokens.surface,
                    foregroundColor: AppTokens.ink,
                    minimumSize: const Size.square(AppTokens.minTapTarget),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd + 2),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.searchChores,
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: AppTokens.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd + 2),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppTokens.spaceSm + 2;
                final width = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in shown)
                      SizedBox(
                        width: width,
                        child: _Tile(
                          template: t,
                          onTap: () => Navigator.pop(context, t.id),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              l10n.quickLogFootnote,
              textAlign: TextAlign.center,
              style: AppTypography.eyebrow.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.template, required this.onTap});

  final TaskTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTokens.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 108),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (template.emoji != null)
                  Text(
                    template.emoji ?? '',
                    style: const TextStyle(fontSize: 26),
                  ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  template.title,
                  style: AppTypography.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  '+${template.points}',
                  style: AppTypography.label.copyWith(
                    color: AppTokens.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
