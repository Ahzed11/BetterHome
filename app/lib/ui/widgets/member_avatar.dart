import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The color of the member who joined in position [joinedIndex] (0 is the first).
Color memberColor(int joinedIndex) =>
    AppTokens.memberColors[joinedIndex % AppTokens.memberColors.length];

/// A round avatar with the initials of [label] on the member's [color]. [ring] draws the white
/// border and the outer ring of the podium.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.label,
    required this.color,
    this.size = AppTokens.checkCircleSize,
    this.ring,
  });

  final String label;
  final Color color;
  final double size;
  final Color? ring;

  String get _initials {
    final trimmed = label.trim();
    return trimmed.isEmpty
        ? ''
        : trimmed.substring(0, trimmed.length < 2 ? 1 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: ring == null
              ? null
              : Border.all(color: AppTokens.card, width: 3),
          boxShadow: ring == null
              ? null
              : [BoxShadow(color: ring!, spreadRadius: 2)],
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Text(
              _initials,
              style: AppTypography.label.copyWith(
                color: AppTokens.onBrand,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
