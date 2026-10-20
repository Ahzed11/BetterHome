import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A text field with a square submit button beside it. Calls [onSubmitted] with the trimmed
/// text, from the button or the keyboard, and clears itself; blank text is ignored.
class AddField extends StatefulWidget {
  const AddField({
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
  State<AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<AddField> {
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
    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTokens.fieldHeight),
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: AppTokens.card,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppTokens.outline),
            ),
            alignment: Alignment.center,
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
                  // The box around the field already has the padding and the fill.
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
                color: AppTokens.ink,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  onTap: _submit,
                  child: const SizedBox(
                    width: AppTokens.fieldHeight,
                    height: AppTokens.fieldHeight,
                    child: ExcludeSemantics(
                      child: Icon(Icons.add, color: AppTokens.onBrand),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
