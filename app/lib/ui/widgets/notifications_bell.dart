import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:flutter/material.dart';

/// The bell of the home screen: opens the inbox and shows a coral dot while something is unread.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, required this.session});

  final AppSession session;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  bool _unread = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final unread = await widget.session.notificationsRepository.list(
        limit: 1,
        unreadOnly: true,
      );
      if (mounted) {
        setState(() => _unread = unread.isNotEmpty);
      }
    } on ApiException catch (_) {
      // Without an answer there is nothing to point at: no dot.
      if (mounted) {
        setState(() => _unread = false);
      }
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(session: widget.session),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: _unread ? l10n.notificationsBellUnread : l10n.notificationsTitle,
      onPressed: _open,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (_unread)
            const Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: AppTokens.spaceSm + 2,
                height: AppTokens.spaceSm + 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTokens.overdue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
