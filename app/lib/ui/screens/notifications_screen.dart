import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/notification_preferences_screen.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/notification_row.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:betterhome/ui/widgets/pull_to_refresh.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  /// The newest page, which is what is cached.
  late final CachedRead<List<AppNotification>> _first;

  /// The older pages asked for during this visit, and whether there are more after them.
  List<AppNotification> _more = const [];
  bool? _moreHasMore;

  /// What was opened during this visit, as the server now has it.
  final Map<String, AppNotification> _opened = {};

  NotificationsRepository get _repository =>
      widget.session.notificationsRepository;

  @override
  void initState() {
    super.initState();
    _first = CachedRead(
      cache: widget.session.readCache,
      key: widget.session.readKey('inbox'),
      fetch: () => _repository.list(limit: _pageSize),
      onChange: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _first.dispose();
    super.dispose();
  }

  List<AppNotification> get _firstPage => switch (_first.state) {
    ReadLoaded<List<AppNotification>>(:final data) => data,
    _ => const [],
  };

  List<AppNotification> get _items => [
    for (final n in [..._firstPage, ..._more]) _opened[n.id] ?? n,
  ];

  bool get _hasMore => _moreHasMore ?? _firstPage.length == _pageSize;

  Future<void> _loadMore() async {
    await runGuarded(context, () async {
      final page = await _repository.list(
        before: _items.last.id,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _more = [..._more, ...page];
          _moreHasMore = page.length == _pageSize;
        });
      }
    });
  }

  Future<void> _open(AppNotification notification) async {
    await runGuarded(context, () async {
      final read = await _repository.markRead(notification.id);
      if (mounted) {
        setState(() => _opened[read.id] = read);
      }
    });
  }

  /// Pull to refresh: the newest page again; the older pages asked for are dropped with it.
  Future<bool> _pull() async {
    final arrived = await _first.refresh();
    if (arrived && mounted) {
      setState(() {
        _more = const [];
        _moreHasMore = null;
        _opened.clear();
      });
    }
    return arrived;
  }

  Future<void> _markAllRead() async {
    final ok = await runGuarded(context, _repository.markAllRead);
    if (ok && mounted) {
      setState(() {
        _more = const [];
        _moreHasMore = null;
        _opened.clear();
      });
      await _first.refreshAfterChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUnread = _items.any((n) => !n.isRead);
    return Scaffold(
      appBar: AppBar(),
      body: PullToRefresh(
        onRefresh: _pull,
        child: ListView(
          physics: pullablePhysics,
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
                      builder: (_) => NotificationPreferencesScreen(
                        session: widget.session,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceMd),
            ..._body(l10n),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(AppLocalizations l10n) {
    switch (_first.state) {
      case ReadLoading<List<AppNotification>>():
        return [const NotificationsSkeleton()];
      case ReadFailed<List<AppNotification>>():
        return [
          Center(
            child: Column(
              children: [
                Text(l10n.errorGeneric),
                TextButton(onPressed: _first.refresh, child: Text(l10n.retry)),
              ],
            ),
          ),
        ];
      case ReadLoaded<List<AppNotification>>():
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
