import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A white round button with an outline and an icon, drawn 44 px inside a 48 px tap target, as
/// the design's header buttons. [tooltip] names it for screen readers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        container: true,
        button: true,
        label: tooltip,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: InkResponse(
            onTap: onPressed,
            radius: AppTokens.minTapTarget / 2,
            child: SizedBox.square(
              dimension: AppTokens.minTapTarget,
              child: Center(
                child: Container(
                  width: AppTokens.minTouchTarget,
                  height: AppTokens.minTouchTarget,
                  decoration: BoxDecoration(
                    color: AppTokens.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTokens.outline),
                  ),
                  child: Icon(icon, size: 20, color: AppTokens.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
