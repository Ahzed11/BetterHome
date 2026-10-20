import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A small "- value +" control with a caption. The two buttons keep a 48 px target and are named
/// by [decreaseLabel] and [increaseLabel]; a button is disabled when its callback is null.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.caption,
    required this.value,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String caption;
  final String value;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppTokens.spaceMd),
          child: Text(
            caption,
            style: AppTypography.label.copyWith(color: AppTokens.inkMuted),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: decreaseLabel,
              onPressed: onDecrease,
              icon: const Icon(Icons.remove, size: 20),
            ),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  value,
                  style: AppTypography.display.copyWith(fontSize: 22),
                ),
              ),
            ),
            IconButton(
              tooltip: increaseLabel,
              onPressed: onIncrease,
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}
