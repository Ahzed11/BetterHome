import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// The emoji of one category of the picker.
class _Category {
  const _Category(this.icon, this.emojis);

  final IconData icon;
  final List<String> emojis;
}

const _categories = [
  _Category(Icons.cleaning_services_outlined, [
    '🧹',
    '🧽',
    '🧼',
    '🪣',
    '🧴',
    '🪥',
    '🚿',
    '🛁',
    '🚽',
    '🪠',
    '🧻',
    '🪟',
    '🧯',
    '🗑️',
    '♻️',
    '🪒',
    '🧺',
    '🫧',
    '✨',
    '🪞',
  ]),
  _Category(Icons.restaurant_outlined, [
    '🍽️',
    '🥘',
    '🍳',
    '🥄',
    '🍴',
    '🔪',
    '🫖',
    '☕',
    '🥣',
    '🍞',
    '🥕',
    '🥗',
    '🍝',
    '🍕',
    '🥪',
    '🧃',
    '🥛',
    '🍎',
    '🧊',
    '🫙',
  ]),
  _Category(Icons.home_outlined, [
    '🏠',
    '🛏️',
    '🛋️',
    '🚪',
    '🔑',
    '💡',
    '🔌',
    '🔧',
    '🔨',
    '🪛',
    '📦',
    '📬',
    '🧰',
    '🪜',
    '📚',
    '🖼️',
    '🕯️',
    '🧸',
    '🪑',
    '🔔',
  ]),
  _Category(Icons.local_laundry_service_outlined, [
    '🧦',
    '👕',
    '👖',
    '🧥',
    '👗',
    '🧣',
    '🧤',
    '👚',
    '🩳',
    '🩲',
    '🧵',
    '🪡',
    '🛏️',
    '🧺',
    '🧼',
    '🌬️',
    '☀️',
    '🪝',
    '👔',
    '🥾',
  ]),
  _Category(Icons.yard_outlined, [
    '🪴',
    '🌱',
    '🌿',
    '🌷',
    '🌻',
    '🌳',
    '🍂',
    '💧',
    '🚰',
    '🐕',
    '🐈',
    '🐟',
    '🐦',
    '🐇',
    '🐢',
    '🦴',
    '🐾',
    '🧑‍🌾',
    '🚲',
    '☂️',
  ]),
  _Category(Icons.shopping_cart_outlined, [
    '🛒',
    '🛍️',
    '🧾',
    '💳',
    '💶',
    '📝',
    '📮',
    '🚗',
    '⛽',
    '🚌',
    '📞',
    '💊',
    '🩺',
    '📅',
    '⏰',
    '🎁',
    '🎉',
    '🍼',
    '🧳',
    '✉️',
  ]),
];

/// Opens the picker and returns the chosen emoji, the empty string for "no icon", or null when
/// closed without a choice.
Future<String?> showEmojiPicker(BuildContext context, {String current = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => EmojiPickerSheet(current: current),
  );
}

/// A sheet of household emoji in categories, with a way to choose none.
class EmojiPickerSheet extends StatefulWidget {
  const EmojiPickerSheet({super.key, this.current = ''});

  final String current;

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  int _category = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = [
      l10n.emojiCleaning,
      l10n.emojiKitchen,
      l10n.emojiHome,
      l10n.emojiLaundry,
      l10n.emojiOutdoors,
      l10n.emojiErrands,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          0,
          AppTokens.spaceMd,
          AppTokens.spaceMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                l10n.pickEmojiTitle,
                style: AppTypography.display.copyWith(fontSize: 22),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm + 4),
            Row(
              children: [
                for (var i = 0; i < _categories.length; i++)
                  Expanded(
                    child: Semantics(
                      container: true,
                      button: true,
                      selected: i == _category,
                      label: names[i],
                      onTap: () => setState(() => _category = i),
                      child: ExcludeSemantics(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _category = i),
                          child: Container(
                            height: AppTokens.minTapTarget,
                            decoration: BoxDecoration(
                              color: i == _category
                                  ? AppTokens.brandTint
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _categories[i].icon,
                              color: i == _category
                                  ? AppTokens.brand
                                  : AppTokens.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
              child: Text(names[_category], style: AppTypography.sectionLabel),
            ),
            Wrap(
              children: [
                for (final emoji in _categories[_category].emojis)
                  _EmojiButton(
                    emoji: emoji,
                    selected: emoji == widget.current,
                    onTap: () => Navigator.pop(context, emoji),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ''),
              icon: const Icon(Icons.block, size: 18),
              label: Text(l10n.noIcon),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: emoji,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: AppTokens.minTapTarget + 4,
            height: AppTokens.minTapTarget + 4,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTokens.brandTint : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}
