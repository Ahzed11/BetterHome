import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/confetti_burst.dart';
import 'package:flutter/material.dart';

/// The recap of a finished month with confetti falling over it. [detail] is an optional second line.
class MonthRecapDialog extends StatelessWidget {
  const MonthRecapDialog({
    super.key,
    required this.title,
    required this.message,
    required this.closeLabel,
    this.detail,
  });

  final String title;
  final String message;
  final String? detail;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The text scrolls, so large text sizes never push the button off the screen.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: AppTypography.body.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceMd),
                        Text(message, style: AppTypography.body),
                        if (detail != null) ...[
                          const SizedBox(height: AppTokens.spaceSm),
                          Text(detail!, style: AppTypography.bodyMuted),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(closeLabel),
                  ),
                ),
              ],
            ),
          ),
          const Positioned.fill(child: ConfettiBurst()),
        ],
      ),
    );
  }
}
