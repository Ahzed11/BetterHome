import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:betterhome/ui/widgets/month_recap_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

const _household = 'hh-1';

DateTime _now() => DateTime.utc(2026, 10, 14, 10);

/// Questions that are held back, once [holding], until the test answers or fails them.
class _Gate {
  bool holding = false;
  final List<Completer<Object?>> asked = [];

  /// The real answer, or a held one while [holding].
  Future<T> pass<T>(Future<T> Function() real) {
    if (!holding) {
      return real();
    }
    final held = Completer<Object?>();
    asked.add(held);
    return held.future.then((value) => value as T);
  }

  void fail(int index) =>
      asked[index].completeError(ApiException('down', statusCode: 503));
}

class _Tasks extends FakeTasksRepository {
  _Tasks(this.gate) : super(now: _now);

  final _Gate gate;

  @override
  Future<List<ChoreTask>> listTasks(
    String householdId, {
    TaskStatus? status,
    bool mine = false,
  }) => gate.pass(() => super.listTasks(householdId, mine: mine));

  @override
  Future<List<TaskTemplate>> listTemplates(String householdId) =>
      gate.pass(() => super.listTemplates(householdId));

  Future<void> answerTasks(int index, {bool mine = false}) async =>
      gate.asked[index].complete(await super.listTasks(_household, mine: mine));

  Future<void> answerTemplates(int index) async =>
      gate.asked[index].complete(await super.listTemplates(_household));
}

class _Scoring extends FakeScoringRepository {
  _Scoring(this.gate);

  final _Gate gate;

  @override
  Future<Scoreboard> getScoreboard(
    String householdId, {
    ScorePeriod period = ScorePeriod.month,
    String? yearMonth,
  }) => gate.pass(() => super.getScoreboard(householdId, period: period));

  Future<void> answer(int index) async => gate.asked[index].complete(
    await super.getScoreboard(_household, period: ScorePeriod.month),
  );
}

class _Lists extends FakeListsRepository {
  _Lists(this.gate);

  final _Gate gate;

  @override
  Future<List<ChecklistItem>> listItems(String householdId, String listId) =>
      gate.pass(() => super.listItems(householdId, listId));

  /// The lists are asked at once unless a test holds them too.
  bool holdLists = false;

  @override
  Future<List<Checklist>> listLists(String householdId) => holdLists
      ? gate.pass(() => super.listLists(householdId))
      : super.listLists(householdId);

  Future<void> answerItems(int index) async =>
      gate.asked[index].complete(await super.listItems(_household, 'list-1'));

  Future<void> answerLists(int index) async =>
      gate.asked[index].complete(await super.listLists(_household));
}

class _Inbox extends FakeNotificationsRepository {
  _Inbox(this.gate);

  final _Gate gate;

  @override
  Future<List<AppNotification>> list({
    String? before,
    int limit = 20,
    bool unreadOnly = false,
  }) => gate.pass(
    () => super.list(before: before, limit: limit, unreadOnly: unreadOnly),
  );

  Future<void> answer(int index) async =>
      gate.asked[index].complete(await super.list(limit: 20));
}

AppNotification _notification(int n) => AppNotification(
  id: 'n$n',
  type: NotificationType.taskAssigned,
  title: 'Title $n',
  body: 'Body $n',
  createdAt: DateTime.utc(2026, 10, 14, 10, n),
  readAt: null,
);

/// One screen, loaded, with what the pull tests need to know about it.
class _Run {
  _Run({
    required this.gate,
    required this.shown,
    required this.change,
    required this.fresh,
    required this.answer,
  });

  final _Gate gate;

  /// Something the screen shows before the pull.
  final Finder shown;

  /// Changes what the server has, after the screen was loaded.
  final Future<void> Function() change;

  /// Something the screen shows only once the changed data has arrived.
  final Finder fresh;

  /// Answers the [index]th held question.
  final Future<void> Function(int index) answer;
}

Future<AppSession> _session({
  TasksRepository? tasks,
  ScoringRepository? scoring,
  ListsRepository? lists,
  NotificationsRepository? notifications,
}) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
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

Future<void> _show(WidgetTester tester, Widget home, Locale locale) =>
    pumpScreen(tester, home: home, locale: locale);

Future<_Run> _chores(
  WidgetTester tester,
  Locale locale, {
  bool mine = false,
}) async {
  final gate = _Gate();
  final tasks = _Tasks(gate);
  final session = await _session(tasks: tasks);
  final template = await tasks.createTemplate(
    householdId: _household,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  final task = await tasks.createOpen(
    householdId: _household,
    templateId: template.id,
    dueAt: DateTime.utc(2026, 10, 14, 9),
  );
  await _show(
    tester,
    ChoresScreen(
      session: session,
      householdId: _household,
      mine: mine,
      now: _now,
    ),
    locale,
  );
  return _Run(
    gate: gate,
    shown: find.textContaining('Vacuum'),
    change: () => tasks.complete(_household, task.id),
    fresh: find.textContaining('5 pts'),
    answer: (i) => tasks.answerTasks(i, mine: mine),
  );
}

Future<_Run> _leaderboard(WidgetTester tester, Locale locale) async {
  final gate = _Gate();
  final scoring = _Scoring(gate);
  final session = await _session(scoring: scoring);
  await _show(
    tester,
    LeaderboardScreen(session: session, householdId: _household),
    locale,
  );
  // The month recap opens a dialog over the screen; it is not what is tested here.
  if (find.byType(MonthRecapDialog).evaluate().isNotEmpty) {
    await tester.tap(
      find.descendant(
        of: find.byType(MonthRecapDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
  }
  final before = tester
      .widgetList<Text>(find.textContaining('pts'))
      .map((t) => t.data)
      .toSet();
  return _Run(
    gate: gate,
    shown: find.byType(LeaderboardScreen),
    change: () => scoring.award(
      householdId: _household,
      userId: session.profile?.id ?? 'user-1',
      taskId: 't1',
      points: 40,
      late: false,
    ),
    // The total of the effort bar is a text that the 40 more points change.
    fresh: find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data?.contains('pts together') ?? false) &&
          !before.contains(w.data),
    ),
    answer: scoring.answer,
  );
}

Future<_Run> _lists(WidgetTester tester, Locale locale) async {
  final gate = _Gate();
  final lists = _Lists(gate);
  final session = await _session(lists: lists);
  final shop = await lists.createList(_household, 'Weekly shop');
  await lists.addItem(_household, shop.id, 'Milk');
  await _show(
    tester,
    ListsScreen(session: session, householdId: _household),
    locale,
  );
  return _Run(
    gate: gate,
    shown: find.text('Milk'),
    change: () => lists.addItem(_household, shop.id, 'Bread'),
    fresh: find.text('Bread'),
    answer: lists.answerItems,
  );
}

Future<_Run> _inbox(WidgetTester tester, Locale locale) async {
  final gate = _Gate();
  final inbox = _Inbox(gate)..add(_notification(1));
  final session = await _session(notifications: inbox);
  await _show(tester, NotificationsScreen(session: session), locale);
  return _Run(
    gate: gate,
    shown: find.text('Title 1'),
    change: () async => inbox.add(_notification(2)),
    fresh: find.text('Title 2'),
    answer: inbox.answer,
  );
}

Future<_Run> _householdScreen(WidgetTester tester, Locale locale) async {
  final gate = _Gate();
  final tasks = _Tasks(gate);
  final session = await _session(tasks: tasks);
  await tasks.createTemplate(
    householdId: _household,
    title: 'Vacuum',
    points: 5,
    latePoints: 2,
  );
  await _show(
    tester,
    HouseholdDetailScreen(session: session, householdId: _household),
    locale,
  );
  return _Run(
    gate: gate,
    shown: find.textContaining('Vacuum'),
    change: () => tasks.createTemplate(
      householdId: _household,
      title: 'Chop wood',
      points: 5,
      latePoints: 2,
    ),
    fresh: find.textContaining('Chop wood'),
    answer: tasks.answerTemplates,
  );
}

/// Pulls the first scrollable of the screen down, as a finger does, and lets the indicator start
/// the refresh.
Future<void> _pull(WidgetTester tester) async {
  // The first scrollable that goes up and down: the pills of the lists scroll sideways.
  await tester.fling(
    find
        .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
        .first,
    const Offset(0, 300),
    1000,
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

typedef _Open = Future<_Run> Function(WidgetTester tester, Locale locale);

final Map<String, _Open> _screens = {
  'all chores': (t, l) => _chores(t, l),
  'my chores': (t, l) => _chores(t, l, mine: true),
  'the leaderboard': _leaderboard,
  'the lists': _lists,
  'the inbox': _inbox,
  'the household screen': _householdScreen,
};

void main() {
  for (final entry in _screens.entries) {
    final name = entry.key;
    group('pull to refresh on $name', () {
      testWidgets(
        'asks again, keeps the data on screen and shows the indicator',
        (tester) async {
          final run = await entry.value(tester, const Locale('en'));
          expect(run.shown, findsWidgets);
          run.gate.holding = true;

          await _pull(tester);

          expect(run.gate.asked, isNotEmpty);
          expect(run.shown, findsWidgets); // never replaced by a skeleton
          expect(find.text('Loading…'), findsNothing);
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        },
      );

      testWidgets('the fresh data replaces the old and the indicator ends', (
        tester,
      ) async {
        final run = await entry.value(tester, const Locale('en'));
        run.gate.holding = true;
        await _pull(tester);
        await run.change();

        await run.answer(0);
        await tester.pumpAndSettle();

        expect(run.fresh, findsWidgets);
        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(find.text("Couldn’t refresh. Try again."), findsNothing);
      });

      testWidgets('a refresh that fails keeps the data and says so', (
        tester,
      ) async {
        final run = await entry.value(tester, const Locale('en'));
        run.gate.holding = true;
        await _pull(tester);

        run.gate.fail(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Couldn’t refresh. Try again.'), findsOneWidget);
        expect(run.shown, findsWidgets);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('says so in French', (tester) async {
        final run = await entry.value(tester, const Locale('fr'));
        run.gate.holding = true;
        await _pull(tester);

        run.gate.fail(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('Actualisation impossible. Réessayez.'),
          findsOneWidget,
        );
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('pulling again while it runs does not ask a second time', (
        tester,
      ) async {
        final run = await entry.value(tester, const Locale('en'));
        run.gate.holding = true;
        await _pull(tester);
        final asked = run.gate.asked.length;

        await _pull(tester);

        expect(run.gate.asked.length, asked);
      });

      testWidgets('screen readers get a "Refresh" action', (tester) async {
        final handle = tester.ensureSemantics();
        await entry.value(tester, const Locale('en'));

        final labels = <String?>{};
        for (final widget in tester.widgetList<Semantics>(
          find.byType(Semantics),
        )) {
          for (final action
              in widget.properties.customSemanticsActions?.keys ??
                  const <CustomSemanticsAction>[]) {
            labels.add(action.label);
          }
        }

        expect(labels, contains('Refresh'));
        handle.dispose();
      });
    });
  }

  group('a screen without a list to scroll still accepts the pull', () {
    testWidgets('the lists, when there is none yet', (tester) async {
      final gate = _Gate();
      final lists = _Lists(gate);
      final session = await _session(lists: lists);
      await _show(
        tester,
        ListsScreen(session: session, householdId: _household),
        const Locale('en'),
      );
      expect(
        find.text('No lists yet. An admin can create one.'),
        findsOneWidget,
      );
      lists.holdLists = true;
      gate.holding = true;

      await _pull(tester);

      expect(gate.asked, isNotEmpty);
      await lists.createList(_household, 'Weekly shop');
      await lists.answerLists(0);
      await tester.pumpAndSettle();
      expect(find.text('Weekly shop'), findsOneWidget);
    });

    testWidgets('a list with no item', (tester) async {
      final gate = _Gate();
      final lists = _Lists(gate);
      final session = await _session(lists: lists);
      await lists.createList(_household, 'Weekly shop');
      await _show(
        tester,
        ListsScreen(session: session, householdId: _household),
        const Locale('en'),
      );
      expect(find.text('All stocked up'), findsOneWidget);
      gate.holding = true;

      await _pull(tester);

      expect(gate.asked, isNotEmpty);
      await lists.addItem(_household, 'list-1', 'Milk');
      await lists.answerItems(0);
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
    });

    testWidgets('chores whose first load failed', (tester) async {
      final gate = _Gate()..holding = true;
      final tasks = _Tasks(gate);
      final session = await _session(tasks: tasks);
      await _show(
        tester,
        ChoresScreen(session: session, householdId: _household, now: _now),
        const Locale('en'),
      );
      gate.fail(0);
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);

      await _pull(tester);
      expect(gate.asked, hasLength(2));
      await tasks.createTemplate(
        householdId: _household,
        title: 'Vacuum',
        points: 5,
        latePoints: 2,
      );
      await tasks.answerTasks(1);
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsNothing);
    });
  });
}
