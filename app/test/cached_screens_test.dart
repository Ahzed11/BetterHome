import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:betterhome/ui/widgets/month_recap_dialog.dart';
import 'package:betterhome/ui/widgets/notifications_bell.dart';
import 'package:betterhome/ui/widgets/podium.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

const _household = 'hh-1';

DateTime _now() => DateTime.utc(2026, 10, 14, 10);

/// Questions whose answers arrive when the test says so, as a network's would.
class _Held<T> {
  final List<Completer<T>> asked = [];

  Future<T> hold() {
    final held = Completer<T>();
    asked.add(held);
    return held.future;
  }
}

class _HeldScoring extends FakeScoringRepository {
  final boards = _Held<Scoreboard>();

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) => boards.hold();

  /// Answers the [index]th question with what the fake holds for [period].
  Future<void> answer(int index, ScorePeriod period) async {
    boards.asked[index].complete(
      await super.getScoreboard(_household, period: period),
    );
  }
}

class _HeldLists extends FakeListsRepository {
  final lists = _Held<List<Checklist>>();
  final items = _Held<List<ChecklistItem>>();

  @override
  Future<List<Checklist>> listLists(String householdId) => lists.hold();

  @override
  Future<List<ChecklistItem>> listItems(String householdId, String listId) =>
      items.hold();

  Future<void> answerLists(int index) async =>
      lists.asked[index].complete(await super.listLists(_household));

  Future<void> answerItems(int index, String listId) async =>
      items.asked[index].complete(await super.listItems(_household, listId));
}

class _HeldNotifications extends FakeNotificationsRepository {
  final pages = _Held<List<AppNotification>>();

  @override
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  }) => pages.hold();

  Future<void> answer(int index, {bool unreadOnly = false}) async =>
      pages.asked[index].complete(
        await super.list(limit: unreadOnly ? 1 : 20, unreadOnly: unreadOnly),
      );
}

class _HeldHouseholds extends FakeHouseholdsRepository {
  final households = _Held<List<Household>>();
  final details = _Held<Household>();
  bool holdHouseholds = true;
  bool holdDetails = false;

  @override
  Future<List<Household>> listHouseholds() =>
      holdHouseholds ? households.hold() : super.listHouseholds();

  @override
  Future<Household> getHousehold(String householdId) =>
      holdDetails ? details.hold() : super.getHousehold(householdId);

  Future<void> answerHouseholds(int index) async =>
      households.asked[index].complete(await super.listHouseholds());

  Future<void> answerDetails(int index) async =>
      details.asked[index].complete(await super.getHousehold(_household));
}

class _HeldTasks extends FakeTasksRepository {
  _HeldTasks() : super(now: _now);

  /// The All chores tab's questions; the prefetch of My chores asks apart.
  final tasks = _Held<List<ChoreTask>>();
  final mine = _Held<List<ChoreTask>>();

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) => mine ? this.mine.hold() : tasks.hold();

  Future<void> answer(int index, String householdId) async =>
      tasks.asked[index].complete(await super.listTasks(householdId));
}

AppNotification _notification(int n, {bool read = false}) => AppNotification(
  id: 'n$n',
  type: NotificationType.taskAssigned,
  title: 'Title $n',
  body: 'Body $n',
  createdAt: DateTime.utc(2026, 10, 14, 10, n % 60),
  readAt: read ? DateTime.utc(2026, 10, 14, 11) : null,
);

Future<AppSession> _session({
  HouseholdsRepository? households,
  ScoringRepository? scoring,
  ListsRepository? lists,
  NotificationsRepository? notifications,
  TasksRepository? tasks,
}) async {
  SharedPreferences.setMockInitialValues({});
  final session = AppSession(
    repository: households ?? FakeHouseholdsRepository(),
    preferences: await SharedPreferences.getInstance(),
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
  if (tasks != null) {
    session.useTasksRepository(tasks);
  }
  if (scoring != null) {
    session.useScoringRepository(scoring);
  }
  if (lists != null) {
    session.useListsRepository(lists);
  }
  if (notifications != null) {
    session.useNotificationsRepository(notifications);
  }
  return session;
}

Future<void> _show(WidgetTester tester, Widget home) =>
    pumpScreen(tester, home: home, locale: const Locale('en'));

/// Takes the screen away, as leaving it does.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  group('the leaderboard', () {
    Widget screen(AppSession s) =>
        LeaderboardScreen(session: s, householdId: _household);

    Future<_HeldScoring> visited(WidgetTester tester, AppSession s) async {
      final scoring = s.scoringRepository as _HeldScoring;
      await _show(tester, screen(s));
      await scoring.answer(0, ScorePeriod.month);
      await tester.pumpAndSettle();
      return scoring;
    }

    testWidgets('shows the board in the first frame when it is opened again', (
      tester,
    ) async {
      final s = await _session(scoring: _HeldScoring());
      final scoring = await visited(tester, s);
      await _leave(tester);

      await _show(tester, screen(s));

      expect(find.byType(LeaderboardSkeleton), findsNothing);
      expect(find.byType(Podium), findsOneWidget);
      expect(scoring.boards.asked, hasLength(2)); // refreshing, held back
    });

    testWidgets('the recap shown once does not come back from an old answer', (
      tester,
    ) async {
      final s = await _session(scoring: _HeldScoring());
      final scoring = await visited(tester, s);
      expect(find.byType(MonthRecapDialog), findsOneWidget);
      await tester.tap(find.text('Nice!'));
      await tester.pumpAndSettle();
      await _leave(tester);

      // The cached answer still lists the month as unseen: it must not be acted on.
      await _show(tester, screen(s));
      expect(find.byType(MonthRecapDialog), findsNothing);
      await scoring.answer(1, ScorePeriod.month);
      await tester.pumpAndSettle();

      expect(find.byType(MonthRecapDialog), findsNothing);
    });

    testWidgets('a period seen before shows at once, another one a skeleton', (
      tester,
    ) async {
      final s = await _session(scoring: _HeldScoring());
      final scoring = await visited(tester, s);
      await tester.tap(find.text('Nice!'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Week'));
      await tester.pump();
      expect(find.byType(LeaderboardSkeleton), findsOneWidget);
      await scoring.answer(1, ScorePeriod.week);
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardSkeleton), findsNothing);

      await tester.tap(find.text('Month'));
      await tester.pump();

      expect(find.byType(LeaderboardSkeleton), findsNothing);
      expect(find.byType(Podium), findsOneWidget);
    });
  });

  group('the lists', () {
    Widget screen(AppSession s) =>
        ListsScreen(session: s, householdId: _household);

    Future<_HeldLists> world(AppSession? out) async => _HeldLists();

    Future<(AppSession, _HeldLists)> visited(WidgetTester tester) async {
      final lists = await world(null);
      final s = await _session(lists: lists);
      // The data the held answers will carry: one list with one item.
      final fake = lists as FakeListsRepository;
      final shop = await fake.createList(_household, 'Weekly shop');
      await fake.addItem(_household, shop.id, 'Milk');
      return (s, lists);
    }

    testWidgets('shows lists and items in the first frame when opened again', (
      tester,
    ) async {
      final (s, lists) = await visited(tester);
      await _show(tester, screen(s));
      await lists.answerLists(0);
      await tester.pumpAndSettle();
      await lists.answerItems(0, 'list-1');
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      await _leave(tester);

      await _show(tester, screen(s));

      expect(find.byType(ListsScreenSkeleton), findsNothing);
      expect(find.byType(ChecklistSkeleton), findsNothing);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Weekly shop · 1'), findsOneWidget);
    });

    testWidgets(
      'a list seen before shows its items at once, a new one a skeleton',
      (tester) async {
        final lists = _HeldLists();
        final s = await _session(lists: lists);
        final shop = await lists.createList(_household, 'Weekly shop');
        final packing = await lists.createList(_household, 'Packing');
        await lists.addItem(_household, shop.id, 'Milk');
        await lists.addItem(_household, packing.id, 'Socks');
        await _show(tester, screen(s));
        await lists.answerLists(0);
        await tester.pumpAndSettle();
        await lists.answerItems(0, shop.id);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Packing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Packing'));
        await tester.pump();
        expect(find.byType(ChecklistSkeleton), findsOneWidget);
        await lists.answerItems(1, packing.id);
        await tester.pumpAndSettle();
        expect(find.text('Socks'), findsOneWidget);

        await tester.ensureVisible(find.text('Weekly shop'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Weekly shop'));
        await tester.pump();

        expect(find.byType(ChecklistSkeleton), findsNothing);
        expect(find.text('Milk'), findsOneWidget);
      },
    );
  });

  group('the inbox', () {
    Widget screen(AppSession s) => NotificationsScreen(session: s);

    testWidgets(
      'shows the notifications in the first frame when opened again',
      (tester) async {
        final inbox = _HeldNotifications()..add(_notification(1));
        final s = await _session(notifications: inbox);
        await _show(tester, screen(s));
        await inbox.answer(0);
        await tester.pumpAndSettle();
        expect(find.text('Title 1'), findsOneWidget);
        await _leave(tester);

        await _show(tester, screen(s));

        expect(find.byType(NotificationsSkeleton), findsNothing);
        expect(find.text('Title 1'), findsOneWidget);
      },
    );

    testWidgets('a refresh that fails keeps the notifications', (tester) async {
      final inbox = _HeldNotifications()..add(_notification(1));
      final s = await _session(notifications: inbox);
      await _show(tester, screen(s));
      await inbox.answer(0);
      await tester.pumpAndSettle();
      await _leave(tester);
      await _show(tester, screen(s));

      inbox.pages.asked[1].completeError(ApiException('down', statusCode: 503));
      await tester.pumpAndSettle();

      expect(find.text('Title 1'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('opening one marks it read and keeps it on screen', (
      tester,
    ) async {
      final inbox = _HeldNotifications()..add(_notification(1));
      final s = await _session(notifications: inbox);
      await _show(tester, screen(s));
      await inbox.answer(0);
      await tester.pumpAndSettle();
      expect(find.text('Mark all read'), findsOneWidget);

      await tester.tap(find.text('Title 1'));
      await tester.pumpAndSettle();

      expect(find.text('Title 1'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });
  });

  group('the bell', () {
    Widget bar(AppSession s) => Scaffold(
      appBar: AppBar(actions: [NotificationsBell(session: s)]),
    );

    testWidgets('keeps its dot while a newer answer is on its way', (
      tester,
    ) async {
      final inbox = _HeldNotifications()..add(_notification(1));
      final s = await _session(notifications: inbox);
      await _show(tester, bar(s));
      expect(
        find.byTooltip('Notifications'),
        findsOneWidget,
      ); // no answer yet: no dot
      await inbox.answer(0, unreadOnly: true);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications, unread'), findsOneWidget);
      await _leave(tester);

      await _show(tester, bar(s));

      expect(find.byTooltip('Notifications, unread'), findsOneWidget);
    });

    testWidgets('keeps its dot when the refresh fails', (tester) async {
      final inbox = _HeldNotifications()..add(_notification(1));
      final s = await _session(notifications: inbox);
      await _show(tester, bar(s));
      await inbox.answer(0, unreadOnly: true);
      await tester.pumpAndSettle();
      await _leave(tester);
      await _show(tester, bar(s));

      inbox.pages.asked[1].completeError(ApiException('down', statusCode: 503));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Notifications, unread'), findsOneWidget);
    });

    testWidgets('drops its dot once the answer says nothing is unread', (
      tester,
    ) async {
      final inbox = _HeldNotifications()..add(_notification(1));
      final s = await _session(notifications: inbox);
      await _show(tester, bar(s));
      await inbox.answer(0, unreadOnly: true);
      await tester.pumpAndSettle();
      await _leave(tester);
      await inbox.markAllRead();
      await _show(tester, bar(s));

      await inbox.answer(1, unreadOnly: true);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.byTooltip('Notifications, unread'), findsNothing);
    });
  });

  group('the household screen', () {
    testWidgets('shows its data in the first frame when opened again', (
      tester,
    ) async {
      final households = _HeldHouseholds()..holdHouseholds = false;
      final s = await _session(households: households);
      households.holdDetails = true;
      await _show(
        tester,
        HouseholdDetailScreen(session: s, householdId: _household),
      );
      await households.answerDetails(0);
      await tester.pumpAndSettle();
      expect(find.text('Flat'), findsOneWidget);
      await _leave(tester);

      await _show(
        tester,
        HouseholdDetailScreen(session: s, householdId: _household),
      );

      expect(find.byType(HouseholdSkeleton), findsNothing);
      expect(find.text('Flat'), findsOneWidget);
    });
  });

  group('the shell', () {
    testWidgets(
      'a household just made is not "no households" while the list refreshes',
      (tester) async {
        final households = _HeldHouseholds();
        final s = await _session(households: households);
        await _show(tester, HomeShell(session: s, now: _now));
        await households.answerHouseholds(0);
        await tester.pumpAndSettle();
        households.holdHouseholds = true;

        await tester.tap(
          find.bySemanticsLabel('Household Flat, switch household'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create household').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Cabin');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        // The new household is not in the old list yet: a skeleton, never the empty screen.
        expect(find.text('No households yet'), findsNothing);
        expect(find.byType(ChoreListSkeleton), findsOneWidget);

        await households.answerHouseholds(1);
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Household Cabin, switch household'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the household list seen before is there in the first frame', (
      tester,
    ) async {
      final households = _HeldHouseholds();
      final s = await _session(households: households);
      await _show(tester, HomeShell(session: s, now: _now));
      await households.answerHouseholds(0);
      await tester.pumpAndSettle();
      await _leave(tester);

      await _show(tester, HomeShell(session: s, now: _now));

      expect(
        find.bySemanticsLabel('Household Flat, switch household'),
        findsOneWidget,
      );
      expect(
        households.households.asked,
        hasLength(2),
      ); // refreshing, held back
    });

    testWidgets('switching back to a household shows its chores at once', (
      tester,
    ) async {
      final households = _HeldHouseholds()..holdHouseholds = false;
      final tasks = _HeldTasks();
      final s = await _session(households: households, tasks: tasks);
      final flat = (await s.repository.listHouseholds()).single;
      final cabin = await s.repository.createHousehold(
        name: 'Cabin',
        timezone: 'UTC',
      );
      for (final id in [flat.id, cabin.id]) {
        final template = await tasks.createTemplate(
          householdId: id,
          title: id == flat.id ? 'Vacuum' : 'Chop wood',
          points: 5,
          latePoints: 2,
        );
        await tasks.createOpen(
          householdId: id,
          templateId: template.id,
          dueAt: DateTime.utc(2026, 10, 14, 9),
        );
      }
      await s.selectHousehold(flat.id);
      await _show(tester, HomeShell(session: s, now: _now));
      await tasks.answer(0, flat.id);
      await tester.pumpAndSettle();
      expect(find.textContaining('Vacuum'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel('Household Flat, switch household'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cabin').last);
      await tester.pumpAndSettle();
      await tasks.answer(1, cabin.id);
      await tester.pumpAndSettle();
      expect(find.textContaining('Chop wood'), findsOneWidget);
      expect(find.textContaining('Vacuum'), findsNothing);

      await tester.tap(
        find.bySemanticsLabel('Household Cabin, switch household'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flat').last);
      await tester.pump();

      expect(find.textContaining('Vacuum'), findsOneWidget);
      expect(find.byType(ChoreListSkeleton), findsNothing);
    });
  });
}
