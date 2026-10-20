import 'dart:async';

import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

OverlayEntry? _current;

/// Shows [message] in the design's toast: a dark rounded box at the top of the screen with a
/// round icon, the text and an optional action button, over a bar that runs down [duration].
///
/// Returns true when the person taps the action, false when the toast ends on its own, is
/// replaced by another toast or the screen goes away. One toast at a time. [error] swaps the
/// green check for a coral mark.
Future<bool> showAppToast(
  BuildContext context, {
  required String message,
  String? actionLabel,
  Duration duration = const Duration(seconds: 4),
  bool error = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _current?.remove();
  final result = Completer<bool>();
  late final OverlayEntry entry;
  void finish(bool acted) {
    if (entry.mounted) {
      entry.remove();
    }
    if (identical(_current, entry)) {
      _current = null;
    }
    if (!result.isCompleted) {
      result.complete(acted);
    }
  }

  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      actionLabel: actionLabel,
      duration: duration,
      error: error,
      onDone: finish,
    ),
  );
  _current = entry;
  overlay.insert(entry);
  return result.future;
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.actionLabel,
    required this.duration,
    required this.error,
    required this.onDone,
  });

  final String message;
  final String? actionLabel;
  final Duration duration;
  final bool error;
  final void Function(bool acted) onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _bar
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDone(false);
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.error ? AppTokens.overdueRing : AppTokens.toastAccent;
    return Positioned(
      left: AppTokens.spaceMd,
      right: AppTokens.spaceMd,
      top: MediaQuery.paddingOf(context).top + AppTokens.spaceMd,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTokens.ink,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTokens.ink.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.error
                                    ? AppTokens.overdueTint
                                    : AppTokens.brand,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(
                                dimension: 28,
                                child: Icon(
                                  widget.error
                                      ? Icons.priority_high
                                      : Icons.check,
                                  size: 16,
                                  color: widget.error
                                      ? AppTokens.overdueText
                                      : AppTokens.onBrand,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTokens.spaceSm + 4),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: AppTypography.body.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.onBrand,
                                ),
                              ),
                            ),
                            if (widget.actionLabel != null)
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                  backgroundColor: AppTokens.onBrand.withValues(
                                    alpha: 0.12,
                                  ),
                                  minimumSize: const Size(
                                    AppTokens.minTapTarget,
                                    AppTokens.minTapTarget,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: AppTypography.body.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () => widget.onDone(true),
                                child: Text(widget.actionLabel ?? ''),
                              ),
                          ],
                        ),
                      ),
                      ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _bar,
                          builder: (_, _) => Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: 1 - _bar.value,
                              child: ColoredBox(
                                color: accent,
                                child: const SizedBox(height: 3),
                              ),
                            ),
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
      ),
    );
  }
}
