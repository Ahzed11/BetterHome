import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// One row of a checklist: a check box with a 48 px tap target, the [title] (struck through
/// when [checked]) and an optional [trailing] widget. [semanticLabel] names the check action
/// for screen readers, for example "Check Milk".
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.title,
    required this.checked,
    required this.semanticLabel,
    required this.onChanged,
    this.trailing,
  });

  final String title;
  final bool checked;
  final String semanticLabel;
  final VoidCallback onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppTokens.fieldHeight),
      child: Row(
        children: [
          Semantics(
            container: true,
            button: true,
            checked: checked,
            label: semanticLabel,
            onTap: onChanged,
            child: ExcludeSemantics(
              child: InkResponse(
                onTap: onChanged,
                radius: AppTokens.minTapTarget / 2,
                child: SizedBox(
                  width: AppTokens.minTapTarget,
                  height: AppTokens.minTapTarget,
                  child: Center(child: _Box(checked: checked)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: checked
                  ? AppTypography.bodyMuted.copyWith(
                      decoration: TextDecoration.lineThrough,
                    )
                  : AppTypography.body,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTokens.checkBoxSize,
      height: AppTokens.checkBoxSize,
      decoration: BoxDecoration(
        color: checked ? AppTokens.brand : null,
        borderRadius: BorderRadius.circular(AppTokens.spaceSm),
        border: checked
            ? null
            : Border.all(color: AppTokens.controlOutline, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: AppTokens.onBrand)
          : null,
    );
  }
}
