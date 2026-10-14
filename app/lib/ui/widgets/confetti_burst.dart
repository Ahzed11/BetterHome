import 'dart:math' as math;

import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A short burst of confetti that falls over its parent once. It ignores touches, is invisible to
/// screen readers and does not play when the user asked for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.pieces = 40,
    this.duration = const Duration(milliseconds: 2800),
  });

  final int pieces;
  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();
  late final List<_Piece> _pieces = _makePieces(widget.pieces);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The same pieces every time: the burst looks alike on every run and in tests.
  static List<_Piece> _makePieces(int count) {
    final random = math.Random(7);
    const colors = [AppTokens.brand, AppTokens.overdue, AppTokens.inkMuted];
    return [
      for (var i = 0; i < count; i++)
        _Piece(
          x: random.nextDouble(),
          fall: 0.55 + random.nextDouble() * 0.45,
          sway: 6 + random.nextDouble() * 18,
          swayRate: 2 + random.nextDouble() * 4,
          size: 6 + random.nextDouble() * 6,
          turn: random.nextDouble() * math.pi * 2,
          delay: random.nextDouble() * 0.25,
          color: colors[i % colors.length],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _ConfettiPainter(_pieces, _controller.value),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.fall,
    required this.sway,
    required this.swayRate,
    required this.size,
    required this.turn,
    required this.delay,
    required this.color,
  });

  final double x;
  final double fall;
  final double sway;
  final double swayRate;
  final double size;
  final double turn;
  final double delay;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);

  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t == 0) {
        continue;
      }
      final x =
          piece.x * size.width + math.sin(t * piece.swayRate) * piece.sway;
      final y = -piece.size + t * piece.fall * (size.height + piece.size * 2);
      final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(piece.turn + t * piece.swayRate);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: piece.size,
          height: piece.size * 0.55,
        ),
        Paint()..color = piece.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
