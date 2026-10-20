import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/stepper_field.dart';
import 'package:flutter/material.dart';

/// The icons a chore can take, cycled by the icon button; the empty string is "no icon".
const List<String> choreEmojis = [
  '🗑️',
  '🧹',
  '🍽️',
  '🧦',
  '🪴',
  '🛁',
  '🧽',
  '🛒',
  '',
];

const int maxChorePoints = 99;

/// The first card of the chore forms: the icon button, the name and the optional notes.
class ChoreDetailsCard extends StatelessWidget {
  const ChoreDetailsCard({
    super.key,
    required this.emoji,
    required this.onNextEmoji,
    required this.title,
    required this.notes,
    required this.onTitleChanged,
  });

  final String emoji;
  final VoidCallback onNextEmoji;
  final TextEditingController title;
  final TextEditingController notes;
  final ValueChanged<String> onTitleChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
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
                      label: l10n.chooseEmoji(
                        emoji.isEmpty ? l10n.noEmoji : emoji,
                      ),
                      onTap: onNextEmoji,
                      child: ExcludeSemantics(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                          onTap: onNextEmoji,
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
                            child: emoji.isEmpty
                                ? const Icon(
                                    Icons.sentiment_satisfied_alt_outlined,
                                    color: AppTokens.inkMuted,
                                  )
                                : Text(
                                    emoji,
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
                    controller: title,
                    onChanged: onTitleChanged,
                    decoration: InputDecoration(labelText: l10n.choreName),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm + 4),
            TextField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.choreNotes),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Points" section: on-time and late points, the late ones never above the on-time ones.
class PointsSection extends StatelessWidget {
  const PointsSection({
    super.key,
    required this.points,
    required this.latePoints,
    required this.onChanged,
  });

  final int points;
  final int latePoints;

  /// Called with the new on-time and late points.
  final void Function(int points, int latePoints) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                      value: '$points',
                      decreaseLabel: l10n.fewerPoints(l10n.onTimePoints),
                      increaseLabel: l10n.morePoints(l10n.onTimePoints),
                      onDecrease: points > 1
                          ? () => onChanged(
                              points - 1,
                              latePoints > points - 1 ? points - 1 : latePoints,
                            )
                          : null,
                      onIncrease: points < maxChorePoints
                          ? () => onChanged(points + 1, latePoints)
                          : null,
                    ),
                    StepperField(
                      caption: l10n.latePointsLabel,
                      value: '$latePoints',
                      decreaseLabel: l10n.fewerPoints(l10n.latePointsLabel),
                      increaseLabel: l10n.morePoints(l10n.latePointsLabel),
                      onDecrease: latePoints > 0
                          ? () => onChanged(points, latePoints - 1)
                          : null,
                      onIncrease: latePoints < points
                          ? () => onChanged(points, latePoints + 1)
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
      ],
    );
  }
}
