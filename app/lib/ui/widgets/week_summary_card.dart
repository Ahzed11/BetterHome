import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The green card on top of My chores: the points of the week, the rank, and how much is still
/// within reach.
class WeekSummaryCard extends StatelessWidget {
  const WeekSummaryCard({
    super.key,
    required this.heading,
    required this.points,
    required this.rank,
    required this.progress,
    required this.reach,
  });

  final String heading;
  final String points;
  final String rank;

  /// Share of the week's reachable points already earned, from 0 to 1.
  final double progress;
  final String reach;

  @override
  Widget build(BuildContext context) {
    final onBrand = AppTypography.label.copyWith(color: AppTokens.onBrand);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.brand,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              runSpacing: AppTokens.spaceSm,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(heading, style: onBrand.copyWith(fontSize: 13)),
                    Text(
                      points,
                      style: AppTypography.display.copyWith(
                        fontSize: 40,
                        height: 1,
                        color: AppTokens.onBrand,
                      ),
                    ),
                  ],
                ),
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppTokens.onBrand.withValues(alpha: 0.16),
                    shape: const StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceSm + AppTokens.spaceXs,
                      vertical: AppTokens.spaceSm,
                    ),
                    child: Text(
                      rank,
                      style: onBrand.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 10,
                backgroundColor: AppTokens.onBrand.withValues(alpha: 0.18),
                valueColor: const AlwaysStoppedAnimation(AppTokens.onBrand),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(reach, style: onBrand.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
