import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A white rounded surface that groups rows. [subdued] is the translucent variant used for
/// finished items.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.subdued = false});

  final Widget child;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: subdued ? AppTokens.card.withValues(alpha: 0.6) : AppTokens.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXs),
        child: child,
      ),
    );
  }
}
