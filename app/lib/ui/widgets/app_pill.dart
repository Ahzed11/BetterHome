import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A rounded pill button: filled when [selected] (the current choice of a group), outlined
/// otherwise. The pill is drawn 40 px high as in the design, inside a 48 px tap target.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTokens.onBrand : AppTokens.ink;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTapTarget,
              minWidth: AppTokens.minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              child: Container(
                height: AppTokens.pillHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                ),
                decoration: ShapeDecoration(
                  color: selected ? AppTokens.brand : AppTokens.card,
                  shape: StadiumBorder(
                    side: selected
                        ? BorderSide.none
                        : const BorderSide(color: AppTokens.outline),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: AppTokens.spaceXs + 2),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon-only "add" pill of a pill row (dashed-style outline), named by [tooltip].
class AppAddPill extends StatelessWidget {
  const AppAddPill({super.key, required this.tooltip, required this.onPressed});

  final String tooltip;
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
            child: SizedBox(
              width: AppTokens.minTapTarget,
              height: AppTokens.minTapTarget,
              child: Center(
                child: Container(
                  width: AppTokens.pillHeight,
                  height: AppTokens.pillHeight,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTokens.controlOutline),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: AppTokens.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
