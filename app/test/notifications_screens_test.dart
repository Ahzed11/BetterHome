import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/screens/notification_preferences_screen.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

AppNotification _notification(
  int n, {
  bool read = false,
  NotificationType type = NotificationType.taskAssigned,
}) => AppNotification(
  id: 'n$n',
  type: type,
  title: 'Title $n',
  body: 'Body $n',
  createdAt: DateTime.utc(2026, 10, 14, 10, n % 60),
  readAt: read ? DateTime.utc(2026, 10, 14, 11) : null,
);

AppSession _session(FakeNotificationsRepository notifications) => AppSession(
  repository: FakeHouseholdsRepository(),
  notificationsRepository: notifications,
);

Future<void> _inbox(
  WidgetTester tester,
  AppSession session, {
  Locale locale = const Locale('en'),
}) async {
  await pumpScreen(
    tester,
    home: NotificationsScreen(session: session),
    locale: locale,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('inbox', () {
    testWidgets('an empty inbox says so', (tester) async {
      await _inbox(tester, _session(FakeNotificationsRepository()));

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text("You're all caught up."), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('shows the server-rendered text, newest first', (tester) async {
      final repo = FakeNotificationsRepository()
        ..add(_notification(1, read: true))
        ..add(_notification(2));
      await _inbox(tester, _session(repo));

      expect(find.text('Title 2'), findsOneWidget);
      expect(find.text('Body 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Title 2')).dy,
        lessThan(tester.getTopLeft(find.text('Title 1')).dy),
      );
    });

    testWidgets('opening an unread notification marks it read', (tester) async {
      final repo = FakeNotificationsRepository()..add(_notification(1));
      await _inbox(tester, _session(repo));
      expect(find.text('Mark all read'), findsOneWidget);

      await tester.tap(find.text('Title 1'));
      await tester.pumpAndSettle();

      expect((await repo.list()).single.isRead, isTrue);
      expect(
        find.text('Mark all read'),
        findsNothing,
        reason: 'nothing unread is left',
      );
    });

    testWidgets('mark all read reloads the inbox', (tester) async {
      final repo = FakeNotificationsRepository()
        ..add(_notification(1))
        ..add(_notification(2));
      await _inbox(tester, _session(repo));

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(await repo.list(unreadOnly: true), isEmpty);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('a full page offers more, and loading it appends the rest', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository();
      for (var i = 1; i <= 23; i++) {
        repo.add(_notification(i, read: true));
      }
      await _inbox(tester, _session(repo));
      expect(find.text('Title 23'), findsOneWidget);
      expect(find.text('Title 1'), findsNothing);

      await tester.dragUntilVisible(
        find.text('Load more'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Title 1'),
        find.byType(ListView),
        const Offset(0, -300),
      );

      expect(find.text('Title 1'), findsOneWidget);
      expect(
        find.text('Load more'),
        findsNothing,
        reason: 'the last page was short',
      );
    });

    testWidgets('shows the error state and retries', (tester) async {
      final repo = _FlakyNotifications();
      await _inbox(tester, _session(repo));
      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Title 1'), findsOneWidget);
    });

    testWidgets(
      'a failed mark-as-read is shown and the notification stays unread',
      (tester) async {
        final repo = _RejectingRead()..add(_notification(1));
        await _inbox(tester, _session(repo));

        await tester.tap(find.text('Title 1'));
        await tester.pumpAndSettle();

        expect(find.text('Something went wrong'), findsOneWidget);
        expect((await repo.list()).single.isRead, isFalse);
      },
    );

    testWidgets('is available in French', (tester) async {
      final repo = FakeNotificationsRepository()..add(_notification(1));
      await _inbox(tester, _session(repo), locale: const Locale('fr'));

      expect(find.text('Tout marquer comme lu'), findsOneWidget);
      expect(find.byTooltip('Réglages des notifications'), findsOneWidget);
    });
  });

  group('preferences', () {
    Future<FakeNotificationsRepository> open(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final repo = FakeNotificationsRepository();
      await pumpScreen(
        tester,
        home: NotificationPreferencesScreen(session: _session(repo)),
        locale: locale,
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows every type with a push and an in-app switch, all on', (
      tester,
    ) async {
      await open(tester);
      // Tall enough to build all nine cards at once.
      tester.view.physicalSize = const Size(400, 4000);
      await tester.pumpAndSettle();

      expect(find.text('Notification settings'), findsOneWidget);
      expect(find.text('Invitations'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(18));
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).every((s) => s.value),
        isTrue,
      );
    });

    testWidgets('switching one off saves it', (tester) async {
      final repo = await open(tester);

      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final saved = (await repo.preferences())
          .where((p) => !p.enabled)
          .toList();
      expect(saved.single.type, NotificationType.taskAssigned);
      expect(saved.single.channel, NotificationChannel.push);
      expect(
        tester.widgetList<Switch>(find.byType(Switch)).first.value,
        isFalse,
      );
    });

    testWidgets('is available in French', (tester) async {
      await open(tester, locale: const Locale('fr'));

      expect(find.text('Réglages des notifications'), findsOneWidget);
      expect(find.text('Rappels'), findsOneWidget);
    });
  });

  group('bell', () {
    Future<void> home(WidgetTester tester, AppSession session) async {
      await pumpScreen(
        tester,
        home: HomeShell(session: session),
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows no dot when everything is read', (tester) async {
      final repo = FakeNotificationsRepository()
        ..add(_notification(1, read: true));
      await home(tester, _session(repo));

      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('Notifications, unread'), findsNothing);
    });

    testWidgets('shows a dot while something is unread and opens the inbox', (
      tester,
    ) async {
      final repo = FakeNotificationsRepository()..add(_notification(1));
      await home(tester, _session(repo));
      expect(find.byTooltip('Notifications, unread'), findsOneWidget);

      await tester.tap(find.byTooltip('Notifications, unread'));
      await tester.pumpAndSettle();
      expect(find.text('Title 1'), findsOneWidget);
      await tester.tap(find.text('Title 1'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Notifications'),
        findsOneWidget,
        reason: 'the dot is gone',
      );
    });

    testWidgets('shows no dot when the inbox cannot be read', (tester) async {
      await home(tester, _session(_FlakyNotifications()));

      expect(find.byTooltip('Notifications'), findsOneWidget);
    });
  });
}

/// Fails the first read, then has one notification.
class _FlakyNotifications extends FakeNotificationsRepository {
  bool _failed = false;

  @override
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    if (!_failed) {
      _failed = true;
      throw ApiException('boom', statusCode: 500);
    }
    return [_notification(1, read: true)];
  }
}

/// Refuses to mark anything read.
class _RejectingRead extends FakeNotificationsRepository {
  @override
  Future<AppNotification> markRead(String id) async =>
      throw ApiException('boom', statusCode: 500);
}
