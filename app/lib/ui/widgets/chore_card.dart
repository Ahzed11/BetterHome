import 'dart:math' as math;

import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// How the check circle of a [ChoreCard] is drawn.
enum ChoreCircle { open, overdue, done }

/// One chore of the design: a 44 px check circle, the [title], a [meta] line and a [trailing]
/// widget (the points). [onComplete] makes the circle a button named [completeLabel].
class ChoreCard extends StatelessWidget {
  const ChoreCard({
    super.key,
    required this.title,
    required this.meta,
    required this.circle,
    this.completeLabel,
    this.onComplete,
    this.trailing,
  });

  final String title;
  final Widget meta;
  final ChoreCircle circle;
  final String? completeLabel;
  final VoidCallback? onComplete;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final done = circle == ChoreCircle.done;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: done ? AppTokens.card.withValues(alpha: 0.6) : AppTokens.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceSm + AppTokens.spaceXs,
          AppTokens.spaceSm + AppTokens.spaceXs,
          AppTokens.spaceMd,
          AppTokens.spaceSm + AppTokens.spaceXs,
        ),
        child: Row(
          children: [
            _Circle(
              circle: circle,
              label: completeLabel,
              onPressed: onComplete,
            ),
            const SizedBox(width: AppTokens.spaceSm + AppTokens.spaceXs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  meta,
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.circle, this.label, this.onPressed});

  final ChoreCircle circle;
  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final drawn = SizedBox.square(
      dimension: AppTokens.checkCircleSize,
      child: CustomPaint(painter: _CirclePainter(circle)),
    );
    final child = circle == ChoreCircle.done
        ? Stack(
            alignment: Alignment.center,
            children: [
              drawn,
              const Icon(Icons.check, color: AppTokens.onBrand, size: 22),
            ],
          )
        : drawn;
    if (onPressed == null) {
      return ExcludeSemantics(child: child);
    }
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onPressed,
          radius: AppTokens.minTapTarget / 2,
          child: SizedBox.square(
            dimension: AppTokens.minTapTarget,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.circle);

  final ChoreCircle circle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;
    switch (circle) {
      case ChoreCircle.done:
        canvas.drawCircle(
          center,
          size.width / 2,
          Paint()..color = AppTokens.brand,
        );
      case ChoreCircle.open:
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppTokens.controlOutline,
        );
      case ChoreCircle.overdue:
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = AppTokens.overdueTint,
        );
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppTokens.overdueRing;
        const dashes = 14;
        const sweep = 2 * math.pi / dashes;
        final rect = Rect.fromCircle(center: center, radius: radius);
        for (var i = 0; i < dashes; i++) {
          canvas.drawArc(rect, i * sweep, sweep * 0.6, false, ring);
        }
    }
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) =>
      oldDelegate.circle != circle;
}
