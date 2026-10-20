import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The top of a screen: a small [eyebrow] (for example the household name), the [title] and
/// optional [actions] on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(eyebrow!, style: AppTypography.eyebrow),
                Semantics(
                  container: true,
                  header: true,
                  child: Text(title, style: AppTypography.display),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            // The actions take the room they need at the far right, up to two thirds of the
            // header; they wrap beyond that and the title takes the rest.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 2 / 3,
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppTokens.spaceSm,
                children: actions,
              ),
            ),
        ],
      ),
    );
  }
}
