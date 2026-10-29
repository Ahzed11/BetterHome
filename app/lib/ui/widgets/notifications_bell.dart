import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
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
  late final CachedRead<bool> _unread;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _unread = CachedRead(
      cache: session.readCache,
      key: session.readKey('unread'),
      fetch: () async => (await session.notificationsRepository.list(
        limit: 1,
        unreadOnly: true,
      )).isNotEmpty,
      onChange: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _unread.dispose();
    super.dispose();
  }

  /// The dot stays while a newer answer is on its way, and when it does not come; without any
  /// answer yet there is nothing to point at.
  bool get _hasUnread => switch (_unread.state) {
    ReadLoaded<bool>(:final data) => data,
    _ => false,
  };

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(session: widget.session),
      ),
    );
    await _unread.refreshAfterChange();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: _hasUnread
          ? l10n.notificationsBellUnread
          : l10n.notificationsTitle,
      onPressed: _open,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (_hasUnread)
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
