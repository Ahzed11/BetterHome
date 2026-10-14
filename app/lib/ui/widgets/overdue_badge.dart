import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// "Overdue · still +4": a soft coral label for a task past its due date. The coral is the dot and
/// the background tint; the text stays dark so it keeps its contrast. Never red, never alarming.
class OverdueBadge extends StatelessWidget {
  const OverdueBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: AppTokens.overdueTint,
          shape: StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm + AppTokens.spaceXs,
            vertical: AppTokens.spaceXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppTokens.overdue,
                  shape: CircleBorder(),
                ),
                child: SizedBox.square(dimension: AppTokens.spaceSm),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Flexible(child: Text(label, style: AppTypography.label)),
            ],
          ),
        ),
      ),
    );
  }
}
