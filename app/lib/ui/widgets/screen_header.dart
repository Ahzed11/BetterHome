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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) Text(eyebrow!, style: AppTypography.eyebrow),
              Semantics(
                container: true,
                header: true,
                child: Text(title, style: AppTypography.display),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Flexible(
            flex: 3,
            // The Wrap is as wide as its content; the Align sends it to the far right.
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppTokens.spaceSm,
                children: actions,
              ),
            ),
          ),
      ],
    );
  }
}
