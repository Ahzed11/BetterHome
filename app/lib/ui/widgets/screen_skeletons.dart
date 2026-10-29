import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// What each screen draws while its data has not arrived for the first time: the shapes of what
/// it will show, so nothing jumps when the data comes (ADR 0031).

/// A white rounded card, as the chore cards are.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceSm + AppTokens.spaceXs,
          AppTokens.spaceSm + AppTokens.spaceXs,
          AppTokens.spaceMd,
          AppTokens.spaceSm + AppTokens.spaceXs,
        ),
        child: child,
      ),
    );
  }
}

/// One row of a card: a leading shape, two lines of text and an optional trailing shape.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.leading,
    this.lines = 2,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final Widget leading;
  final int lines;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppTokens.spaceSm + AppTokens.spaceXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(widthFactor: 0.6, height: 16),
                if (lines > 1) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  const SkeletonLine(widthFactor: 0.35, height: 12),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTokens.spaceSm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A section heading and [cards] chore cards (Chores and My chores).
class ChoreListSkeleton extends StatelessWidget {
  const ChoreListSkeleton({super.key, this.cards = 3});

  final int cards;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppTokens.spaceSm),
            child: SkeletonLine(widthFactor: 0.4, height: 18),
          ),
          for (var i = 0; i < cards; i++) ...[
            const SizedBox(height: AppTokens.spaceSm),
            const _SkeletonCard(
              child: _SkeletonRow(
                leading: SkeletonCircle(AppTokens.checkCircleSize),
                trailing: SkeletonBlock(width: 28, height: 16, radius: 6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A podium of three places and three ranking rows (Leaderboard).
class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget place(double avatar, double height) => Expanded(
      child: Column(
        children: [
          SkeletonCircle(avatar),
          const SizedBox(height: AppTokens.spaceSm),
          const SkeletonLine(widthFactor: 0.7),
          const SizedBox(height: AppTokens.spaceSm),
          SkeletonBlock(height: height),
        ],
      ),
    );
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              place(60, 72),
              const SizedBox(width: AppTokens.spaceSm),
              place(76, 104),
              const SizedBox(width: AppTokens.spaceSm),
              place(60, 52),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          for (var i = 0; i < 3; i++) ...[
            const _SkeletonCard(
              child: _SkeletonRow(
                leading: SkeletonCircle(AppTokens.pillHeight),
                lines: 1,
                trailing: SkeletonBlock(width: 40, height: 16, radius: 6),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
          ],
        ],
      ),
    );
  }
}

/// The rows of a checklist card (Lists).
class ChecklistSkeleton extends StatelessWidget {
  const ChecklistSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: AppCard(
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              const _SkeletonRow(
                lines: 1,
                leading: SkeletonBlock(
                  width: AppTokens.checkBoxSize,
                  height: AppTokens.checkBoxSize,
                  radius: AppTokens.spaceSm,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceMd - 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The whole Lists screen before the lists are known: the header, the pills and a checklist.
class ListsScreenSkeleton extends StatelessWidget {
  const ListsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonLine(widthFactor: 0.2, height: 14),
            const SizedBox(height: AppTokens.spaceSm),
            const SkeletonLine(widthFactor: 0.4, height: 32),
            const SizedBox(height: AppTokens.spaceMd),
            const Row(
              children: [
                SkeletonBlock(
                  width: 96,
                  height: AppTokens.pillHeight,
                  radius: AppTokens.radiusPill,
                ),
                SizedBox(width: AppTokens.spaceSm),
                SkeletonBlock(
                  width: 72,
                  height: AppTokens.pillHeight,
                  radius: AppTokens.radiusPill,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            const ChecklistSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// The rows of the inbox: a dot, a title and a line of text.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows; i++) ...[
            const _SkeletonCard(
              child: _SkeletonRow(
                leading: SkeletonCircle(AppTokens.spaceSm + 2),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
          ],
        ],
      ),
    );
  }
}

/// The household screen: its name, a line about it and a card of members.
class HouseholdSkeleton extends StatelessWidget {
  const HouseholdSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SkeletonLine(widthFactor: 0.5, height: 34),
          const SizedBox(height: AppTokens.spaceSm),
          const SkeletonLine(widthFactor: 0.45, height: 12),
          const SizedBox(height: AppTokens.spaceLg),
          const SkeletonLine(widthFactor: 0.25, height: 12),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++)
                  const _SkeletonRow(
                    leading: SkeletonCircle(AppTokens.pillHeight),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceMd,
                      vertical: AppTokens.spaceSm + 2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rows of the notification settings: a title, a line of text and a switch.
class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: AppCard(
          child: Column(
            children: [
              for (var i = 0; i < rows; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceMd,
                    vertical: AppTokens.spaceSm + 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(widthFactor: 0.6, height: 16),
                            SizedBox(height: AppTokens.spaceSm),
                            SkeletonLine(widthFactor: 0.8, height: 12),
                          ],
                        ),
                      ),
                      SizedBox(width: AppTokens.spaceMd),
                      SkeletonBlock(
                        width: 48,
                        height: 28,
                        radius: AppTokens.radiusPill,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
