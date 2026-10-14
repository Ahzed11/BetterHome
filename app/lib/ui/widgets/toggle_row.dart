import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A label with a switch on the right. The whole row is the tap target (48 px high at least) and
/// [semanticLabel] names the switch for screen readers.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final String semanticLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: value,
      label: semanticLabel,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: AppTypography.body)),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
