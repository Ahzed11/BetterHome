import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// One notification of the inbox: a dot while unread, the title (bold while unread), the body and
/// when it arrived. Tapping an unread row calls [onOpen]; a read row does nothing.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
    required this.unreadLabel,
    this.onOpen,
  });

  final String title;
  final String body;
  final String time;
  final bool unread;

  /// Spoken after the text of an unread notification, for example "unread".
  final String unreadLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tap = unread ? onOpen : null;
    return Semantics(
      container: true,
      button: tap != null,
      label: '$title. $body. $time${unread ? '. $unreadLabel' : ''}',
      onTap: tap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: tap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppTokens.fieldHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceXs + 2),
                    child: Container(
                      width: AppTokens.spaceSm + 2,
                      height: AppTokens.spaceSm + 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unread ? AppTokens.brand : Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXs),
                        Text(body, style: AppTypography.bodyMuted),
                        const SizedBox(height: AppTokens.spaceXs),
                        Text(time, style: AppTypography.eyebrow),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
