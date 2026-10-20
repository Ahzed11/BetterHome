import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// What a dot under a day of the [WeekStrip] stands for.
enum StripDot { done, overdue, upcoming }

/// One day of the [WeekStrip].
class StripDay {
  const StripDay({
    required this.weekday,
    required this.number,
    required this.dots,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final String weekday;
  final String number;

  /// At most three dots are drawn.
  final List<StripDot> dots;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;
}

/// The week card of the Chores board: the week's [title] and one button per day with its date and
/// a dot per chore. The selected day is filled green.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.title, required this.days});

  final String title;
  final List<StripDay> days;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm + 2),
            Row(children: [for (final day in days) Expanded(child: _Day(day))]),
          ],
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day(this.day);

  final StripDay day;

  @override
  Widget build(BuildContext context) {
    final selected = day.selected;
    final ink = selected ? AppTokens.onBrand : AppTokens.ink;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: day.semanticLabel,
      onTap: day.onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: day.onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTokens.brand : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.weekday,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    color: selected ? AppTokens.onBrand : AppTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                Text(
                  day.number,
                  style: AppTypography.body.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceXs),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 3,
                    children: [
                      for (final dot in day.dots.take(3))
                        _DotMark(dot: dot, onBrand: selected),
                    ],
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

class _DotMark extends StatelessWidget {
  const _DotMark({required this.dot, required this.onBrand});

  final StripDot dot;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final color = switch (dot) {
      StripDot.done => onBrand ? AppTokens.onBrand : AppTokens.brand,
      StripDot.overdue => AppTokens.overdueRing,
      StripDot.upcoming => onBrand ? AppTokens.onBrand : AppTokens.brand,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dot == StripDot.upcoming ? null : color,
        border: dot == StripDot.upcoming
            ? Border.all(color: color, width: 1.5)
            : null,
      ),
      child: const SizedBox.square(dimension: 6),
    );
  }
}
