import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The bar docked at the bottom of a list: a pill-shaped text field and a round button. Calls
/// [onSubmitted] with the trimmed text, from the button or the keyboard, and clears itself;
/// blank text is ignored.
class AddBar extends StatefulWidget {
  const AddBar({
    super.key,
    required this.label,
    required this.hint,
    required this.buttonLabel,
    required this.onSubmitted,
  });

  /// Accessible name of the field.
  final String label;
  final String hint;

  /// Accessible name of the submit button.
  final String buttonLabel;
  final ValueChanged<String> onSubmitted;

  @override
  State<AddBar> createState() => _AddBarState();
}

class _AddBarState extends State<AddBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    _controller.clear();
    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        // A soft fade so the rows scrolling under the bar do not end on a hard edge.
        boxShadow: [
          BoxShadow(
            color: AppTokens.surface.withValues(alpha: 0.9),
            blurRadius: AppTokens.spaceMd,
            offset: const Offset(0, -AppTokens.spaceSm),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppTokens.card,
                  shape: const StadiumBorder(
                    side: BorderSide(color: AppTokens.outline),
                  ),
                  shadows: [
                    BoxShadow(
                      color: AppTokens.ink.withValues(alpha: 0.06),
                      blurRadius: AppTokens.spaceSm,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.fieldHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceMd,
                    ),
                    // heightFactor: the field is as tall as its text, never as tall as the room
                    // the bottom slot of a Scaffold offers.
                    child: Align(
                      heightFactor: 1,
                      child: Semantics(
                        container: true,
                        label: widget.label,
                        textField: true,
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            // The pill around the field already has the padding and the fill.
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: widget.hint,
                            hintStyle: AppTypography.bodyMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Tooltip(
              message: widget.buttonLabel,
              child: Semantics(
                container: true,
                button: true,
                label: widget.buttonLabel,
                onTap: _submit,
                child: ExcludeSemantics(
                  child: Material(
                    color: AppTokens.brand,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _submit,
                      child: const SizedBox(
                        width: AppTokens.fieldHeight,
                        height: AppTokens.fieldHeight,
                        child: Icon(Icons.add, color: AppTokens.onBrand),
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
