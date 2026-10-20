import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A row of equal tabs on a grey track; the selected one is a white tile. Each tab keeps a 48 px
/// tap target.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.track,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXs),
        child: Row(
          children: [
            for (final entry in labels.entries)
              Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  selected: entry.key == selected,
                  label: entry.value,
                  onTap: () => onSelected(entry.key),
                  child: ExcludeSemantics(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelected(entry.key),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.minTapTarget,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color: entry.key == selected ? AppTokens.card : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: entry.key == selected
                                ? AppTokens.brand
                                : AppTokens.inkMuted,
                            fontWeight: entry.key == selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
