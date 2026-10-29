import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/state/reads.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:betterhome/ui/widgets/week_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_harness.dart';

DateTime _now() => DateTime.utc(2026, 10, 14, 10);

/// The requests that were started, in order, by name.
class _Net {
  final List<String> started = [];

  int count(String name) => started.where((n) => n == name).length;
}

class _Households extends FakeHouseholdsRepository {
  _Households(this.net);

  final _Net net;

  @override
  Future<List<Membership>> listMembers(String householdId) {
    net.started.add('members');
    return super.listMembers(householdId);
  }

  @override
  Future<Household> getHousehold(String householdId) {
    net.started.add('household');
    return super.getHousehold(householdId);
  }
}

class _Tasks extends FakeTasksRepository {
  _Tasks(this.net) : super(now: _now);

  final _Net net;

  /// The questions held back until the test releases them, as `<household>/all` or `/mine`.
  final Set<String> hold = {};
  final Map<String, Completer<List<ChoreTask>>> held = {};
  bool failMine = false;

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) {
    net.started.add(mine ? 'tasks-mine' : 'tasks');
    if (mine && failMine) {
      return Future.error(ApiException('down', statusCode: 503));
    }
    final key = '$householdId/${mine ? 'mine' : 'all'}';
    if (hold.contains(key)) {
      final question = Completer<List<ChoreTask>>();
      held[key] = question;
      return question.future;
    }
    return super.listTasks(householdId, mine: mine);
  }

  Future<void> release(String householdId, {bool mine = false}) async {
    final key = '$householdId/${mine ? 'mine' : 'all'}';
    final question = held[key];
    if (question == null) {
      throw StateError('nothing held for $key');
    }
    question.complete(await super.listTasks(householdId, mine: mine));
  }
}

class _Scoring extends FakeScoringRepository {
  _Scoring(this.net);

  final _Net net;

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) {
    net.started.add('board-${period.name}');
    return super.getScoreboard(householdId, period: period);
  }

  @override
  Future<List<MonthlyWinner>> listWinners(String householdId) {
    net.started.add('winners');
    return super.listWinners(householdId);
  }
}

class _Lists extends FakeListsRepository {
  _Lists(this.net);

  final _Net net;

  @override
  Future<List<Checklist>> listLists(String householdId) {
    net.started.add('lists');
    return super.listLists(householdId);
  }

  @override
  Future<List<ChecklistItem>> listItems(String householdId, String listId) {
    net.started.add('items');
    return super.listItems(householdId, listId);
  }
}

class _Notifications extends FakeNotificationsRepository {
  _Notifications(this.net);

  final _Net net;

  @override
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  }) {
    net.started.add(unreadOnly ? 'unread' : 'inbox');
    return super.list(before: before, limit: limit, unreadOnly: unreadOnly);
  }
}

class _World {
  _World(this.session, this.net, this.tasks, this.flat);

  final AppSession session;
  final _Net net;
  final _Tasks tasks;
  final Household flat;
}

Future<_World> _world() async {
  SharedPreferences.setMockInitialValues({});
  final net = _Net();
  final session = AppSession(
    repository: _Households(net),
    preferences: await SharedPreferences.getInstance(),
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  final flat = await session.repository.createHousehold(
    name: 'Flat',
    timezone: 'UTC',
  );
  final tasks = _Tasks(net);
  session.useTasksRepository(tasks);
  session.useScoringRepository(_Scoring(net));
  final lists = _Lists(net);
  session.useListsRepository(lists);
  session.useNotificationsRepository(_Notifications(net));
  final shop = await lists.createList(flat.id, 'Weekly shop');
  await lists.addItem(flat.id, shop.id, 'Milk');
  final template = await tasks.createTemplate(
    householdId: flat.id,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  await tasks.createOpen(
    householdId: flat.id,
    templateId: template.id,
    dueAt: DateTime.utc(2026, 10, 14, 9),
  );
  net.started.clear();
  return _World(session, net, tasks, flat);
}

Future<void> _show(WidgetTester tester, _World w) => pumpScreen(
  tester,
  home: HomeShell(session: w.session, now: _now),
  locale: const Locale('en'),
);

Future<void> _leave(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  const firstTab = ['tasks', 'members', 'unread'];
  const otherTabs = [
    'tasks-mine',
    'board-week',
    'household',
    'board-month',
    'winners',
    'lists',
    'items',
  ];

  testWidgets(
    'nothing of the other tabs is asked for before the first tab has loaded',
    (tester) async {
      final w = await _world();
      w.tasks.hold.add('${w.flat.id}/all');

      await _show(tester, w);

      expect(w.net.started, unorderedEquals(firstTab));
    },
  );

  testWidgets(
    'the other tabs are asked for once the first tab has loaded, one tab after the other',
    (tester) async {
      final w = await _world();
      w.tasks.hold.add('${w.flat.id}/all');
      await _show(tester, w);

      await w.tasks.release(w.flat.id);
      await tester.pumpAndSettle();

      // The first tab's own requests come first, then one tab after the other.
      expect(w.net.started.take(3), unorderedEquals(firstTab));
      expect(
        w.net.started.skip(3),
        containsAllInOrder(['tasks-mine', 'board-month', 'lists', 'items']),
      );
      expect(w.net.started.toSet(), containsAll(otherTabs));
    },
  );

  testWidgets(
    'each thing is asked for once, the shared members and household too',
    (tester) async {
      final w = await _world();

      await _show(tester, w);
      await tester.pumpAndSettle();

      expect(w.net.count('tasks'), 1);
      expect(w.net.count('tasks-mine'), 1);
      expect(w.net.count('members'), 1);
      expect(w.net.count('household'), 1);
      expect(w.net.count('board-week'), 1);
      expect(w.net.count('board-month'), 1);
      expect(w.net.count('winners'), 1);
      expect(w.net.count('lists'), 1);
      expect(w.net.count('items'), 1);
      expect(w.net.count('unread'), 1);
      expect(w.net.started, hasLength(10));
    },
  );

  testWidgets('coming back to the first tab does not prefetch again', (
    tester,
  ) async {
    final w = await _world();
    await _show(tester, w);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'All chores'));
    await tester.pumpAndSettle();

    // Opening the tabs refreshes what they show; nothing is filled a second time.
    expect(w.net.count('tasks-mine'), 1);
    expect(w.net.count('board-week'), 1);
    expect(w.net.count('board-month'), 1);
    expect(w.net.count('winners'), 1);
  });

  testWidgets('the first visit to each tab has its data in the first frame', (
    tester,
  ) async {
    final w = await _world();
    await _show(tester, w);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'My chores'));
    await tester.pump();
    expect(find.byType(ChoreListSkeleton), findsNothing);
    expect(find.byType(WeekSummaryCard), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Lists'));
    await tester.pump();
    expect(find.byType(ListsScreenSkeleton), findsNothing);
    expect(find.byType(ChecklistSkeleton), findsNothing);
    expect(find.text('Milk'), findsOneWidget);

    // Last, as its month recap opens a dialog over the screen.
    await tester.tap(find.widgetWithText(NavigationDestination, 'Leaderboard'));
    await tester.pump();
    expect(find.byType(LeaderboardSkeleton), findsNothing);
  });

  testWidgets('a prefetch that fails changes nothing on screen', (
    tester,
  ) async {
    final w = await _world();
    w.tasks.failMine = true;

    await _show(tester, w);
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsNothing);
    expect(find.textContaining('Vacuum'), findsOneWidget);
    // What failed is asked again when its tab is opened, and then shown.
    w.tasks.failMine = false;
    await tester.tap(find.widgetWithText(NavigationDestination, 'My chores'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vacuum'), findsOneWidget);
  });

  testWidgets(
    'switching household during a prefetch fills the old household only',
    (tester) async {
      final w = await _world();
      final cabin = await w.session.repository.createHousehold(
        name: 'Cabin',
        timezone: 'UTC',
      );
      final template = await w.tasks.createTemplate(
        householdId: cabin.id,
        title: 'Chop wood',
        points: 5,
        latePoints: 2,
      );
      await w.tasks.createOpen(
        householdId: cabin.id,
        templateId: template.id,
        dueAt: DateTime.utc(2026, 10, 14, 9),
      );
      await w.session.selectHousehold(w.flat.id);
      w.net.started.clear();
      // The prefetch of Flat is held on its very first request.
      w.tasks.hold.add('${w.flat.id}/mine');
      await _show(tester, w);
      await tester.pumpAndSettle();
      expect(w.net.started, contains('tasks-mine'));
      expect(w.net.started, isNot(contains('board-month')));

      // The user switches to the Cabin while it is held.
      await tester.tap(
        find.bySemanticsLabel('Household Flat, switch household'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cabin').last);
      await tester.pumpAndSettle();
      final startedBeforeLateAnswer = w.net.started.length;
      await w.tasks.release(w.flat.id, mine: true);
      await tester.pumpAndSettle();

      // The late answer is kept for Flat, and what had not started for Flat never does.
      final cache = w.session.readCache;
      final flatMine = cache.entry<List<ChoreTask>>(
        w.session.tasksRead(w.flat.id, mine: true).key,
      );
      expect(flatMine.value, isA<ReadLoaded<List<ChoreTask>>>());
      expect(
        (flatMine.value as ReadLoaded<List<ChoreTask>>).data.map(
          (t) => t.title,
        ),
        ['Vacuum'],
      );
      final cabinMine = cache.entry<List<ChoreTask>>(
        w.session.tasksRead(cabin.id, mine: true).key,
      );
      // The Cabin's own prefetch kept to the Cabin: none of Flat's chores in its entry.
      expect(
        (cabinMine.value as ReadLoaded<List<ChoreTask>>).data.map(
          (t) => t.title,
        ),
        ['Chop wood'],
      );
      final leaderboardOfFlat = cache.entry<Scores>(
        w.session.leaderboardRead(w.flat.id, defaultScorePeriod).key,
      );
      expect(leaderboardOfFlat.value, isA<ReadLoading<Scores>>());
      expect(
        w.net.started.length,
        greaterThanOrEqualTo(startedBeforeLateAnswer),
      );
    },
  );

  testWidgets('leaving the app (a sign-out) stops what has not started', (
    tester,
  ) async {
    final w = await _world();
    w.tasks.hold.add('${w.flat.id}/mine');
    await _show(tester, w);
    await tester.pumpAndSettle();
    expect(w.net.started, contains('tasks-mine'));

    await _leave(tester);
    await w.tasks.release(w.flat.id, mine: true);
    await tester.pumpAndSettle();

    expect(w.net.started, isNot(contains('board-month')));
    expect(w.net.started, isNot(contains('lists')));
  });
}
