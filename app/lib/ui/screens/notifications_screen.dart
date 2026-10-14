import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/notification_preferences_screen.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/notification_row.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _Status { loading, ready, error }

/// The caller's inbox, newest first. Opening an unread notification marks it read; the settings
/// icon leads to the per-type switches.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;

  List<AppNotification> _items = const [];
  _Status _status = _Status.loading;
  bool _hasMore = false;

  NotificationsRepository get _repository =>
      widget.session.notificationsRepository;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final page = await _repository.list(limit: _pageSize);
      if (mounted) {
        setState(() {
          _items = page;
          _hasMore = page.length == _pageSize;
          _status = _Status.ready;
        });
      }
    } on ApiException catch (_) {
      if (mounted) {
        setState(() => _status = _Status.error);
      }
    }
  }

  Future<void> _loadMore() async {
    await runGuarded(context, () async {
      final page = await _repository.list(
        before: _items.last.id,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _items = [..._items, ...page];
          _hasMore = page.length == _pageSize;
        });
      }
    });
  }

  Future<void> _open(AppNotification notification) async {
    await runGuarded(context, () async {
      final read = await _repository.markRead(notification.id);
      if (mounted) {
        setState(() {
          _items = [for (final n in _items) n.id == read.id ? read : n];
        });
      }
    });
  }

  Future<void> _markAllRead() async {
    final ok = await runGuarded(context, _repository.markAllRead);
    if (ok && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUnread = _items.any((n) => !n.isRead);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg - AppTokens.spaceXs,
          0,
          AppTokens.spaceLg - AppTokens.spaceXs,
          AppTokens.spaceLg,
        ),
        children: [
          ScreenHeader(
            title: l10n.notificationsTitle,
            actions: [
              if (hasUnread)
                AppPill(
                  icon: Icons.done_all,
                  label: l10n.markAllRead,
                  onPressed: _markAllRead,
                ),
              IconButton(
                tooltip: l10n.notificationSettings,
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationPreferencesScreen(session: widget.session),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          ..._body(l10n),
        ],
      ),
    );
  }

  List<Widget> _body(AppLocalizations l10n) {
    switch (_status) {
      case _Status.loading:
        return [Center(child: Text(l10n.loading))];
      case _Status.error:
        return [
          Center(
            child: Column(
              children: [
                Text(l10n.errorGeneric),
                TextButton(onPressed: _load, child: Text(l10n.retry)),
              ],
            ),
          ),
        ];
      case _Status.ready:
        if (_items.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: Text(
                l10n.notificationsEmpty,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted,
              ),
            ),
          ];
        }
        final format = DateFormat.yMMMd(
          Localizations.localeOf(context).toString(),
        ).add_Hm();
        return [
          AppCard(
            child: Column(
              children: [
                for (final n in _items)
                  NotificationRow(
                    title: n.title,
                    body: n.body,
                    time: format.format(n.createdAt.toLocal()),
                    unread: !n.isRead,
                    unreadLabel: l10n.unreadLabel,
                    onOpen: () => _open(n),
                  ),
              ],
            ),
          ),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceMd),
              child: Center(
                child: AppPill(label: l10n.loadMore, onPressed: _loadMore),
              ),
            ),
        ];
    }
  }
}
